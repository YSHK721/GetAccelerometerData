import Foundation

// MARK: - VBTRecordingUseCase
// 仕様書: .docs/VBT_GroundTruth_Tool_Spec.md §6 / §9
//
// Phase A 範囲:
//   1. start: IMU 開始 → 録画開始信号 → 3s ACK 待機（失敗時 IMU 即停止＋破棄）
//   2. IMU 監視: 0.5s 以上の途絶を検出 → 即停止＋破棄＋通知
//   3. 接続監視: 3s 以上連続 isReachable=false → 即停止＋破棄＋通知
//   4. stop: IMU 停止 → CSV 書き出し → ファイル転送 → 60s ACK 待機（失敗時無効化）
//
// SRP: VBT Phase A セッションのライフサイクル統制とエラー伝播のみを担う。
//      CoreMotion / WatchConnectivity 実装の詳細には依存しない。
// DIP: 全外部依存は Port（プロトコル）越し。
// LSP: 状態遷移は idle → recording → (failed | completed)。逆遷移はない。

@MainActor
public final class VBTRecordingUseCase {

    // MARK: - 状態

    public enum State: Sendable, Equatable {
        case idle
        case recording
        case failed
        case completed
    }

    public enum StartResult: Sendable, Equatable {
        case started
        case failed(VBTRecordingFailure)
    }

    public enum StopResult: Sendable, Equatable {
        case completed
        case failed(VBTRecordingFailure)
    }

    // MARK: - 設定（仕様書の確定値）

    public struct Timeouts: Sendable {
        public let startAckSeconds: TimeInterval
        public let transferAckSeconds: TimeInterval
        public let imuGapThresholdSeconds: TimeInterval
        public let reachabilityLossThresholdSeconds: TimeInterval

        public static let specDefault = Timeouts(
            startAckSeconds: 3.0,
            transferAckSeconds: 60.0,
            imuGapThresholdSeconds: 0.5,
            reachabilityLossThresholdSeconds: 3.0
        )

        public init(
            startAckSeconds: TimeInterval,
            transferAckSeconds: TimeInterval,
            imuGapThresholdSeconds: TimeInterval,
            reachabilityLossThresholdSeconds: TimeInterval
        ) {
            self.startAckSeconds = startAckSeconds
            self.transferAckSeconds = transferAckSeconds
            self.imuGapThresholdSeconds = imuGapThresholdSeconds
            self.reachabilityLossThresholdSeconds = reachabilityLossThresholdSeconds
        }
    }

    // MARK: - 依存

    private let imu: IMURecorderPort
    private let connectivity: WatchConnectivityVBTPort
    private let notifier: RecordingFailureNotifierPort
    private let timeouts: Timeouts

    // MARK: - 状態（@MainActor で保護）

    public private(set) var state: State = .idle
    public private(set) var imuStartTimestamp: TimeInterval?

    private var gapDetector: IMUSampleGapDetector
    private var reachabilityLossStartedAt: TimeInterval?

    // MARK: - Init

    public init(
        imu: IMURecorderPort,
        connectivity: WatchConnectivityVBTPort,
        notifier: RecordingFailureNotifierPort,
        timeouts: Timeouts = .specDefault
    ) {
        self.imu = imu
        self.connectivity = connectivity
        self.notifier = notifier
        self.timeouts = timeouts
        self.gapDetector = IMUSampleGapDetector(maxIntervalSeconds: timeouts.imuGapThresholdSeconds)
    }

    // MARK: - Lifecycle

    /// 記録開始（仕様書 §6 step 4〜6）
    public func start() async -> StartResult {
        guard state == .idle else { return .failed(.startRecordingAckTimeout) }

        // 1. IMU 開始（自身を MainActor からサンプル取り込みへ橋渡し）
        // Infrastructure 側で背景キューから呼ばれる場合に備え、明示的に MainActor へホップしてから state を触る。
        // テスト環境（既に MainActor）では DispatchQueue.main.async は通常通り次イベントで実行されるため、
        // テストでは Use Case の `ingestSample` を直接呼び出す方が決定論的だが、まず本番経路を担保する。
        imu.startRecording { [weak self] timestamp in
            DispatchQueue.main.async {
                self?.ingestSample(timestamp: timestamp)
            }
        }
        state = .recording
        gapDetector.reset()
        imuStartTimestamp = nil
        reachabilityLossStartedAt = nil

        // 2. 録画開始信号送信 + ACK 待機（仕様書 §6 step 5）
        let ack = await connectivity.sendStartRecordingSignal(timeout: timeouts.startAckSeconds)
        switch ack {
        case .acknowledged:
            return .started
        case .timedOut, .failed:
            // 仕様書 §9 「録画開始 ACK タイムアウト」: IMU 即停止 + 破棄 + 通知
            abort(with: .startRecordingAckTimeout)
            return .failed(.startRecordingAckTimeout)
        }
    }

    /// 記録停止（仕様書 §6 step 10〜13）
    public func stop() async -> StopResult {
        guard state == .recording else {
            return .failed(.transferTimeout) // 既に failed 状態なら停止操作は無効
        }

        // 1. IMU 停止
        imu.stopRecording()
        // 2. 停止信号を iPhone へ
        connectivity.sendStopRecordingSignal()

        // 3. CSV 書き出し
        guard let csvURL = imu.exportCSV() else {
            // データなしは無効セッション（Item6 アトミック型）
            state = .failed
            notifier.notify(.transferTimeout) // PENDING 無効化と同じ扱い
            return .failed(.transferTimeout)
        }

        // 4. 転送 + ACK 待機（仕様書 §6 step 12, 60s）
        let ack = await connectivity.transferIMUFile(at: csvURL, timeout: timeouts.transferAckSeconds)
        switch ack {
        case .acknowledged:
            state = .completed
            return .completed
        case .timedOut, .failed:
            state = .failed
            notifier.notify(.transferTimeout)
            return .failed(.transferTimeout)
        }
    }

    // MARK: - Inbound from Infrastructure

    /// 接続喪失の判定（仕様書 §9 「接続喪失」: 3s 以上連続 isReachable=false）
    /// Infrastructure 側で `WCSession.reachabilityDidChange` および定期チェックから呼び出す。
    /// - Parameters:
    ///   - isReachable: 現在の接続状態
    ///   - at: 仮想時刻（秒、systemUptime 相当）
    public func reportReachability(isReachable: Bool, at now: TimeInterval) {
        guard state == .recording else { return }
        if isReachable {
            reachabilityLossStartedAt = nil
            return
        }
        if let startedAt = reachabilityLossStartedAt {
            if now - startedAt >= timeouts.reachabilityLossThresholdSeconds {
                abort(with: .reachabilityLost)
            }
        } else {
            reachabilityLossStartedAt = now
        }
    }

    // MARK: - Private

    /// IMU サンプルの直接取り込み（テスト用 / MainActor 同期経路）。
    /// 本番経路では `start()` 内の `imu.startRecording` クロージャから DispatchQueue.main 経由で呼ばれる。
    public func ingestSample(timestamp: TimeInterval) {
        handleIMUSample(timestamp: timestamp)
    }

    private func handleIMUSample(timestamp: TimeInterval) {
        guard state == .recording else { return }
        if imuStartTimestamp == nil {
            imuStartTimestamp = timestamp
        }
        if let gap = gapDetector.observe(timestamp: timestamp) {
            abort(with: .imuGap(intervalSeconds: gap.interval))
        }
    }

    private func abort(with failure: VBTRecordingFailure) {
        imu.stopRecording()
        imu.discardRecording()
        state = .failed
        notifier.notify(failure)
    }
}
