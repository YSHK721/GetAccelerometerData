import Foundation
import CoreMotion
import WatchConnectivity
import SwiftUI
import SensorDataKit

// MARK: - VBTRecordingController
// 仕様書: .docs/VBT_GroundTruth_Tool_Spec.md Phase A
//
// Clean Architecture:
//   - Presentation 層: SwiftUI から observe する MainActor ObservableObject
//   - 内部で Infrastructure（CoreMotionIMURecorder / WCSessionVBTGateway）を組み立て、
//     Use Case（VBTRecordingUseCase）に注入する Composition Root の watchOS 側拡張
//
// Phase A スコープ:
//   - 「記録開始」「記録停止」UI 操作の Use Case 委譲
//   - 前提検証（接続/IMU/容量）
//   - エラー通知（VBTRecordingFailure → @Published）
//   - reachability の 1Hz ポーリング

@MainActor
final class VBTRecordingController: ObservableObject {

    enum UIState: Equatable {
        case idle
        case starting
        case recording
        case stopping
        case completed
        case failed(message: String)
    }

    @Published private(set) var uiState: UIState = .idle
    @Published private(set) var lastFailure: VBTRecordingFailure?
    @Published private(set) var prerequisitesMissing: [String] = []

    private let imuRecorder: CoreMotionIMURecorder
    private let gateway: WCSessionVBTGateway
    private let useCase: VBTRecordingUseCase
    private let notifier: NotifierAdapter

    private var reachabilityTimer: Timer?

    init() {
        let imu = CoreMotionIMURecorder()
        let gw = WCSessionVBTGateway()
        let nt = NotifierAdapter()
        self.imuRecorder = imu
        self.gateway = gw
        self.notifier = nt
        self.useCase = VBTRecordingUseCase(
            imu: imu,
            connectivity: gw,
            notifier: nt
        )
        nt.handler = { [weak self] failure in
            Task { @MainActor [weak self] in
                self?.lastFailure = failure
                self?.uiState = .failed(message: failure.userMessage)
                self?.stopReachabilityTimer()
            }
        }
    }

    // MARK: - Public API

    func tapStartRecording() async {
        guard case .idle = uiState else { return }

        // Item3 前提検証
        let probe = captureLiveProbe()
        let missing = VBTPrerequisiteValidator().validate(probe: probe)
        if !missing.isEmpty {
            prerequisitesMissing = missing
            uiState = .failed(message: VBTRecordingFailure.startBlockedByPrerequisite(missing: missing).userMessage)
            return
        }
        prerequisitesMissing = []

        uiState = .starting
        let result = await useCase.start()
        switch result {
        case .started:
            uiState = .recording
            startReachabilityTimer()
        case .failed(let failure):
            lastFailure = failure
            uiState = .failed(message: failure.userMessage)
        }
    }

    func tapStopRecording() async {
        guard case .recording = uiState else { return }
        uiState = .stopping
        stopReachabilityTimer()
        // 仕様書 §7 meta.json 用に IMU 開始時刻を gateway 経由で iPhone へ運ぶ。
        if let imuStart = useCase.imuStartTimestamp {
            gateway.setImuStartTimestamp(imuStart)
        }
        let result = await useCase.stop()
        switch result {
        case .completed:
            uiState = .completed
        case .failed(let failure):
            lastFailure = failure
            uiState = .failed(message: failure.userMessage)
        }
    }

    func reset() {
        uiState = .idle
        lastFailure = nil
        prerequisitesMissing = []
    }

    // MARK: - Reachability monitor (仕様書 §9: 3s 以上連続 isReachable=false)

    private func startReachabilityTimer() {
        reachabilityTimer?.invalidate()
        let timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                let reachable = self.gateway.isReachable
                self.useCase.reportReachability(
                    isReachable: reachable,
                    at: ProcessInfo.processInfo.systemUptime
                )
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        reachabilityTimer = timer
    }

    private func stopReachabilityTimer() {
        reachabilityTimer?.invalidate()
        reachabilityTimer = nil
    }

    // MARK: - Live Probe (Item3 確認のための実機状態)

    /// 前提検証用プローブ値（呼び出し時点でスナップショット）。
    /// CMMotionManager / WCSession を直接保持しないことで Sendable 条項を満たす。
    private struct LiveProbe: VBTPrerequisiteProbe {
        let isWatchConnectivityReachable: Bool
        let isDeviceMotionAvailable: Bool
        let freeStorageBytes: Int64
    }

    private func captureLiveProbe() -> LiveProbe {
        let motion = CMMotionManager()
        let storage = Self.freeStorageBytes()
        return LiveProbe(
            isWatchConnectivityReachable: gateway.isReachable,
            isDeviceMotionAvailable: motion.isDeviceMotionAvailable,
            freeStorageBytes: storage
        )
    }

    private static func freeStorageBytes() -> Int64 {
        guard let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return 0 }
        do {
            // volumeAvailableCapacityForImportantUsage は watchOS で未対応のため、
            // volumeAvailableCapacityKey にフォールバック。
            let values = try url.resourceValues(forKeys: [.volumeAvailableCapacityKey])
            if let bytes = values.volumeAvailableCapacity {
                return Int64(bytes)
            }
        } catch {
            print("[VBTRecordingController] storage probe failed: \(error.localizedDescription)")
        }
        return 0
    }

    // MARK: - Notifier adapter

    private final class NotifierAdapter: RecordingFailureNotifierPort, @unchecked Sendable {
        var handler: ((VBTRecordingFailure) -> Void)?
        func notify(_ failure: VBTRecordingFailure) {
            handler?(failure)
        }
    }
}
