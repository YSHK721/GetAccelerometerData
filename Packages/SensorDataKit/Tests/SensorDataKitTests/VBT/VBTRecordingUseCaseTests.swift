import XCTest
@testable import SensorDataKit

// MARK: - VBTRecordingUseCaseTests
// 仕様書: .docs/VBT_GroundTruth_Tool_Spec.md §6 / §9
// Phase A: Watch 側 IMU 記録 + WatchConnectivity 録画開始 ACK / IMU 転送 ACK / 接続喪失検出
//
// Use Case の責務:
//   1. start(): 前提検証 → IMU 開始 → 録画開始信号送信 → ACK 待機（3s）→ 失敗時 IMU 即停止＋破棄
//   2. IMU サンプル監視: 0.5s 以上の途絶で停止＋破棄
//   3. 接続監視: 3s 以上連続 isReachable=false で停止＋破棄
//   4. stop(): IMU 停止 → CSV 書き出し → ファイル転送 → ACK 待機（60s）→ 失敗時無効化
//
// テスト戦略: 全ポートを Fake 実装で注入し時間制御は仮想クロックで決定論的に検証する。

@MainActor
final class VBTRecordingUseCaseTests: XCTestCase {

    // MARK: - Fakes

    final class FakeIMURecorder: IMURecorderPort, @unchecked Sendable {
        var startCalls = 0
        var stopCalls = 0
        var discardCalls = 0
        var exportCalls = 0
        var exportReturnURL: URL? = URL(fileURLWithPath: "/tmp/imu.csv")
        var onSample: (@Sendable (TimeInterval) -> Void)?

        func startRecording(onSample: @escaping @Sendable (TimeInterval) -> Void) {
            startCalls += 1
            self.onSample = onSample
        }

        func stopRecording() {
            stopCalls += 1
        }

        func exportCSV() -> URL? {
            exportCalls += 1
            return exportReturnURL
        }

        func discardRecording() {
            discardCalls += 1
        }
    }

    final class FakeWatchConnectivity: WatchConnectivityVBTPort, @unchecked Sendable {
        var startAck: StartRecordingAck = .acknowledged
        var transferAck: TransferAck = .acknowledged
        var startSignalCalls = 0
        var stopSignalCalls = 0
        var transferCalls = 0
        var lastTransferURL: URL?
        var isReachable: Bool = true

        func sendStartRecordingSignal(timeout: TimeInterval) async -> StartRecordingAck {
            startSignalCalls += 1
            return startAck
        }

        func sendStopRecordingSignal() {
            stopSignalCalls += 1
        }

        func transferIMUFile(at url: URL, timeout: TimeInterval) async -> TransferAck {
            transferCalls += 1
            lastTransferURL = url
            return transferAck
        }
    }

    final class FakeNotifier: RecordingFailureNotifierPort, @unchecked Sendable {
        var notifications: [VBTRecordingFailure] = []
        func notify(_ failure: VBTRecordingFailure) {
            notifications.append(failure)
        }
    }

    // MARK: - 正常系: start → ACK 受信 → 記録中 → stop → 転送 ACK

    func test_start_acknowledged_keepsRecording() async {
        // Arrange
        let imu = FakeIMURecorder()
        let conn = FakeWatchConnectivity()
        let notifier = FakeNotifier()
        let sut = VBTRecordingUseCase(imu: imu, connectivity: conn, notifier: notifier)

        // Act
        let result = await sut.start()

        // Assert
        XCTAssertEqual(result, .started)
        XCTAssertEqual(imu.startCalls, 1)
        XCTAssertEqual(conn.startSignalCalls, 1)
        XCTAssertEqual(imu.stopCalls, 0)
        XCTAssertEqual(imu.discardCalls, 0)
        XCTAssertEqual(sut.state, .recording)
    }

    func test_stop_afterValidRecording_transfersAndCompletes() async {
        // Arrange
        let imu = FakeIMURecorder()
        let conn = FakeWatchConnectivity()
        let notifier = FakeNotifier()
        let sut = VBTRecordingUseCase(imu: imu, connectivity: conn, notifier: notifier)
        _ = await sut.start()

        // Act
        let result = await sut.stop()

        // Assert
        XCTAssertEqual(result, .completed)
        XCTAssertEqual(imu.stopCalls, 1)
        XCTAssertEqual(imu.exportCalls, 1)
        XCTAssertEqual(conn.transferCalls, 1)
        XCTAssertEqual(conn.stopSignalCalls, 1)
        XCTAssertEqual(sut.state, .completed)
    }

    // MARK: - 異常系: 録画開始 ACK タイムアウト → IMU 停止＋破棄＋通知

    func test_start_ackTimeout_stopsAndDiscards() async {
        // Arrange
        let imu = FakeIMURecorder()
        let conn = FakeWatchConnectivity()
        conn.startAck = .timedOut
        let notifier = FakeNotifier()
        let sut = VBTRecordingUseCase(imu: imu, connectivity: conn, notifier: notifier)

        // Act
        let result = await sut.start()

        // Assert
        XCTAssertEqual(result, .failed(.startRecordingAckTimeout))
        XCTAssertEqual(imu.startCalls, 1, "IMU はまず開始されてから停止される")
        XCTAssertEqual(imu.stopCalls, 1)
        XCTAssertEqual(imu.discardCalls, 1)
        XCTAssertEqual(notifier.notifications, [.startRecordingAckTimeout])
        XCTAssertEqual(sut.state, .failed)
    }

    // MARK: - 異常系: IMU 途絶

    func test_imuGap_stopsRecordingAndNotifies() async {
        // Arrange
        let imu = FakeIMURecorder()
        let conn = FakeWatchConnectivity()
        let notifier = FakeNotifier()
        let sut = VBTRecordingUseCase(imu: imu, connectivity: conn, notifier: notifier)
        _ = await sut.start()

        // Act: 0.6s ギャップを発生させる
        sut.ingestSample(timestamp:100.0)
        sut.ingestSample(timestamp:100.6)

        // Assert
        XCTAssertEqual(imu.stopCalls, 1)
        XCTAssertEqual(imu.discardCalls, 1)
        XCTAssertEqual(notifier.notifications.count, 1)
        if case .imuGap(let interval) = notifier.notifications.first {
            XCTAssertEqual(interval, 0.6, accuracy: 1e-9)
        } else {
            XCTFail("Expected imuGap notification, got \(notifier.notifications)")
        }
        XCTAssertEqual(sut.state, .failed)
    }

    func test_imuGap_belowThreshold_continuesRecording() async {
        // Arrange
        let imu = FakeIMURecorder()
        let conn = FakeWatchConnectivity()
        let notifier = FakeNotifier()
        let sut = VBTRecordingUseCase(imu: imu, connectivity: conn, notifier: notifier)
        _ = await sut.start()

        // Act: 0.4s ギャップ（しきい値未満）
        sut.ingestSample(timestamp:100.0)
        sut.ingestSample(timestamp:100.4)

        // Assert
        XCTAssertEqual(imu.stopCalls, 0)
        XCTAssertEqual(notifier.notifications, [])
        XCTAssertEqual(sut.state, .recording)
    }

    // MARK: - 異常系: 転送 ACK タイムアウト

    func test_stop_transferTimeout_invalidatesSession() async {
        // Arrange
        let imu = FakeIMURecorder()
        let conn = FakeWatchConnectivity()
        conn.transferAck = .timedOut
        let notifier = FakeNotifier()
        let sut = VBTRecordingUseCase(imu: imu, connectivity: conn, notifier: notifier)
        _ = await sut.start()

        // Act
        let result = await sut.stop()

        // Assert
        XCTAssertEqual(result, .failed(.transferTimeout))
        XCTAssertEqual(conn.transferCalls, 1)
        XCTAssertEqual(notifier.notifications, [.transferTimeout])
        XCTAssertEqual(sut.state, .failed)
    }

    // MARK: - 異常系: stop 時に CSV エクスポート不可

    func test_stop_emptyData_invalidatesSession() async {
        // Arrange
        let imu = FakeIMURecorder()
        imu.exportReturnURL = nil
        let conn = FakeWatchConnectivity()
        let notifier = FakeNotifier()
        let sut = VBTRecordingUseCase(imu: imu, connectivity: conn, notifier: notifier)
        _ = await sut.start()

        // Act
        let result = await sut.stop()

        // Assert
        if case .failed = result { /* ok */ } else { XCTFail("Expected failed") }
        XCTAssertEqual(conn.transferCalls, 0, "CSV がなければ転送は試みない")
        XCTAssertEqual(sut.state, .failed)
    }

    // MARK: - imu_start_timestamp 保持（Item7 / meta.json 候補値）

    func test_imuStartTimestamp_capturesFirstSampleTimestamp() async {
        // Arrange
        let imu = FakeIMURecorder()
        let conn = FakeWatchConnectivity()
        let notifier = FakeNotifier()
        let sut = VBTRecordingUseCase(imu: imu, connectivity: conn, notifier: notifier)
        _ = await sut.start()

        // Act
        sut.ingestSample(timestamp:1234.56)
        sut.ingestSample(timestamp:1234.57)

        // Assert
        XCTAssertEqual(sut.imuStartTimestamp ?? 0, 1234.56, accuracy: 1e-9)
    }

    func test_imuStartTimestamp_isNilBeforeFirstSample() async {
        // Arrange
        let imu = FakeIMURecorder()
        let conn = FakeWatchConnectivity()
        let notifier = FakeNotifier()
        let sut = VBTRecordingUseCase(imu: imu, connectivity: conn, notifier: notifier)
        _ = await sut.start()

        // Assert
        XCTAssertNil(sut.imuStartTimestamp)
    }

    // MARK: - 接続喪失検出（3秒以上連続 isReachable=false）

    func test_reachabilityLost_for3Seconds_stopsAndNotifies() async {
        // Arrange
        let imu = FakeIMURecorder()
        let conn = FakeWatchConnectivity()
        let notifier = FakeNotifier()
        let sut = VBTRecordingUseCase(imu: imu, connectivity: conn, notifier: notifier)
        _ = await sut.start()

        // Act: 仮想時刻ベースで 3 秒以上未到達を通知
        conn.isReachable = false
        sut.reportReachability(isReachable: false, at: 100.0)
        sut.reportReachability(isReachable: false, at: 103.1)

        // Assert
        XCTAssertEqual(imu.stopCalls, 1)
        XCTAssertEqual(notifier.notifications, [.reachabilityLost])
        XCTAssertEqual(sut.state, .failed)
    }

    func test_reachability_recoveredBeforeThreshold_doesNotFail() async {
        // Arrange
        let imu = FakeIMURecorder()
        let conn = FakeWatchConnectivity()
        let notifier = FakeNotifier()
        let sut = VBTRecordingUseCase(imu: imu, connectivity: conn, notifier: notifier)
        _ = await sut.start()

        // Act
        sut.reportReachability(isReachable: false, at: 100.0)
        sut.reportReachability(isReachable: true, at: 102.0)
        sut.reportReachability(isReachable: false, at: 200.0)
        sut.reportReachability(isReachable: true, at: 201.0)

        // Assert
        XCTAssertEqual(imu.stopCalls, 0)
        XCTAssertEqual(notifier.notifications, [])
        XCTAssertEqual(sut.state, .recording)
    }
}
