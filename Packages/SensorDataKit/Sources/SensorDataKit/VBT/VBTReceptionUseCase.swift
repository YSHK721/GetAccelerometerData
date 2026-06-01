import Foundation

// MARK: - VBTReceptionUseCase
// 仕様書: .docs/VBT_GroundTruth_Tool_Spec.md §6 step 5〜13 / §7
//
// Phase B iPhone 側受信フロー:
//   1. ユーザーが iOS でメタ入力（setPendingMetadata）→ waitingForStart
//   2. Watch から vbt.startRecording 受信 → handleStartRecordingRequest
//      → AVFoundation 録画開始（1080p/60fps）
//      → 成功時: PENDING フォルダ作成 + ACK
//      → 失敗時（60fps 未対応等）: error 返却 + failed 遷移
//   3. Watch から vbt.imuCSV 受信 → handleIMUFileReceived
//      → 録画停止 → IMU/動画ファイル配置 → meta.json 書き出し
//      → 成功時: VALID 遷移 + ACK
//      → 失敗時: フォルダ削除 + failed 遷移
//
// SRP: 状態遷移とエラーハンドリングのみ。AVFoundation / FileManager 詳細は Port 委譲。
// DIP: VideoRecorderPort / SessionStorePort / ClockPort 経由でのみ外側を参照。
public final class VBTReceptionUseCase: @unchecked Sendable {

    // MARK: - State

    public enum State: Equatable, Sendable {
        case idle
        case waitingForStart
        case recording
        case completed
        case failed
    }

    public enum HandleResult: Equatable, Sendable {
        case acknowledged
        case error(reason: String)
    }

    // MARK: - Dependencies

    private let video: VideoRecorderPort
    private let store: SessionStorePort
    private let clock: ClockPort

    // MARK: - Internal state (NSLock guarded for cross-actor access)
    //
    // NOTE: Swift 6 では `NSLock.lock/unlock` を async コンテキストから直接呼べないため、
    // すべての lock 操作を同期ヘルパー（withLock）に閉じ込め、async 関数は
    // ヘルパー越しに状態を読み書きする。

    private let lock = NSLock()
    private var _state: State = .idle
    private var _pendingInput: VBTSessionInput?
    private var _activeFolder: URL?
    private var _videoStartContext: VideoStartContext?

    private func withLock<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }

    public var state: State { withLock { _state } }
    public var pendingInput: VBTSessionInput? { withLock { _pendingInput } }
    public var activeFolder: URL? { withLock { _activeFolder } }

    // MARK: - Init

    public init(video: VideoRecorderPort, store: SessionStorePort, clock: ClockPort) {
        self.video = video
        self.store = store
        self.clock = clock
    }

    // MARK: - Inbound: メタ入力（UI 側）

    public func setPendingMetadata(_ input: VBTSessionInput) {
        withLock {
            _pendingInput = input
            _state = .waitingForStart
        }
    }

    // MARK: - Inbound: vbt.startRecording 受信時

    public func handleStartRecordingRequest() async -> HandleResult {
        let snapshot: (VBTSessionInput, Date)? = withLock {
            guard let input = _pendingInput else { return nil }
            return (input, clock.currentDate())
        }
        guard let (input, now) = snapshot else {
            return .error(reason: "meta input not provided")
        }

        // 録画開始（1080p/60fps）
        let startResult = await video.startRecording()
        switch startResult {
        case .failure(let err):
            withLock { _state = .failed }
            return .error(reason: Self.message(for: err))

        case .success(let context):
            // PENDING フォルダ作成
            let folderName = SessionFolderNaming.makeFolderName(
                startedAt: now,
                exercise: input.exercise,
                weightKg: input.weightKg,
                setIndex: input.setIndex
            )
            do {
                let folder = try store.createFolder(name: folderName)
                withLock {
                    _activeFolder = folder
                    _videoStartContext = context
                    _state = .recording
                }
                return .acknowledged
            } catch {
                _ = await video.stopRecording()
                withLock { _state = .failed }
                return .error(reason: "folder creation failed: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Inbound: vbt.imuCSV 転送完了時

    public func handleIMUFileReceived(source: URL, imuStartTimestamp: TimeInterval) async -> HandleResult {
        let snapshot: (URL, VBTSessionInput, VideoStartContext)? = withLock {
            guard _state == .recording,
                  let folder = _activeFolder,
                  let input = _pendingInput,
                  let videoContext = _videoStartContext else {
                return nil
            }
            return (folder, input, videoContext)
        }
        guard let (folder, input, videoContext) = snapshot else {
            return .error(reason: "no active recording session")
        }

        // 録画停止
        let stopOutcome = await video.stopRecording()
        switch stopOutcome {
        case .failure(let reason):
            store.delete(folder: folder)
            resetActiveSession()
            return .error(reason: "video stop failed: \(reason)")

        case .success(let videoURL):
            do {
                _ = try store.importIMUFile(from: source, to: folder)
                _ = try store.importVideoFile(from: videoURL, to: folder)
                let payload = try MetaJSONPayload(
                    exercise: input.exercise,
                    weightKg: input.weightKg,
                    repTarget: input.repTarget,
                    setIndex: input.setIndex,
                    subjectId: input.subjectId,
                    imuStartTimestamp: imuStartTimestamp,
                    videoStartIso8601: videoContext.videoStartIso8601,
                    sessionState: .valid
                )
                try store.writeMetaJSON(payload, to: folder)
                try store.finalize(folder: folder)
                withLock { _state = .completed }
                return .acknowledged
            } catch {
                store.delete(folder: folder)
                resetActiveSession()
                return .error(reason: "import failed: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Inbound: Watch 側から stop メッセージ等（録画のみ停止する経路）

    public func handleStopRecordingRequest() async {
        let isRecording = withLock { _state == .recording }
        guard isRecording else { return }
        // 動画停止のみ実施し、IMU CSV 到達まで保留（imu 受信時の finalize 処理に委ねる設計）。
        // Phase B 段階では IMU CSV 受信時に handleIMUFileReceived 内で stopRecording を呼ぶ。
        // ここはユーザーが手動で停止操作した場合のフックとして空実装。
    }

    public func reset() {
        withLock {
            _state = .idle
            _pendingInput = nil
            _activeFolder = nil
            _videoStartContext = nil
        }
    }

    private func resetActiveSession() {
        withLock {
            _state = .failed
            _activeFolder = nil
            _videoStartContext = nil
        }
    }

    private static func message(for error: VideoRecorderError) -> String {
        switch error {
        case .unsupported60fps:
            return "60fps unsupported on this device"
        case .unsupported1080p:
            return "1080p unsupported on this device"
        case .permissionDenied:
            return "camera permission denied"
        case .notReadyForMetaInput:
            return "meta input not provided"
        case .sessionSetupFailed(let detail):
            return "AVCaptureSession setup failed: \(detail)"
        }
    }
}
