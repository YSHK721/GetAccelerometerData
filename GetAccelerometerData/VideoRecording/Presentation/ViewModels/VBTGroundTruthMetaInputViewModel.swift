import Foundation
import SwiftUI
import SensorDataKit

// MARK: - VBTGroundTruthMetaInputViewModel
// VBT Ground Truth Tool Phase B: メタ入力画面の状態管理。
// 仕様書: .docs/VBT_GroundTruth_Tool_Spec.md §5 / §6
//
// Composition Root:
//   - VBTReceptionUseCase（Use Case 層） + VideoRecorder / SessionStore / Clock（Infrastructure）
//   - 既存 WatchSessionGateway（WatchSessionManager）に対し vbtRouter を attach する
//
// 共有：VBT セッションのコンポジションは静的 shared として保持する。
//   Watch 側から WCSession のメッセージが届く時点で UseCase が生きている必要があるため、
//   ContentView を抜けても UseCase インスタンスを保持する。
@MainActor
final class VBTGroundTruthMetaInputViewModel: ObservableObject {

    // 入力
    @Published var exercise: String = ""
    @Published var weightKg: Double? = nil
    @Published var repTarget: Int? = nil
    @Published var setIndex: Int? = nil
    @Published var subjectId: String = ""

    // 状態
    @Published private(set) var validationError: String?
    @Published private(set) var isWaitingForWatch: Bool = false
    @Published private(set) var statusText: String = "メタ情報未入力"

    var canSubmit: Bool {
        VBTGroundTruthMetaInputViewModel.buildInput(
            exercise: exercise,
            weightKg: weightKg,
            repTarget: repTarget,
            setIndex: setIndex,
            subjectId: subjectId
        ) != nil
    }

    /// shared composition：UseCase / Adapter は app 寿命と同じ。
    static let shared = VBTGroundTruthComposition()

    init() {
        // 起動時の現在状態を反映
        refreshStatus()
    }

    func attachRouterIfNeeded() {
        Self.shared.attachRouter()
    }

    func submitPendingMetadata() {
        guard let input = Self.buildInput(
            exercise: exercise,
            weightKg: weightKg,
            repTarget: repTarget,
            setIndex: setIndex,
            subjectId: subjectId
        ) else {
            validationError = "入力が不正です（非空 / > 0 / >= 1 / >= 0）"
            return
        }
        validationError = nil
        Self.shared.useCase.setPendingMetadata(input)
        isWaitingForWatch = true
        refreshStatus()
    }

    func refreshStatus() {
        switch Self.shared.useCase.state {
        case .idle:
            statusText = "未開始"
            isWaitingForWatch = false
        case .waitingForStart:
            statusText = "Watch 記録開始待機中"
            isWaitingForWatch = true
        case .recording:
            statusText = "記録中（録画 + IMU 待ち）"
            isWaitingForWatch = false
        case .completed:
            statusText = "セッション保存完了 (VALID)"
            isWaitingForWatch = false
        case .failed:
            statusText = "失敗：再試行してください"
            isWaitingForWatch = false
        }
    }

    private static func buildInput(
        exercise: String,
        weightKg: Double?,
        repTarget: Int?,
        setIndex: Int?,
        subjectId: String
    ) -> VBTSessionInput? {
        guard let weight = weightKg,
              let rep = repTarget,
              let set = setIndex else { return nil }
        return try? VBTSessionInput(
            exercise: exercise,
            weightKg: weight,
            repTarget: rep,
            setIndex: set,
            subjectId: subjectId
        )
    }
}

// MARK: - VBTGroundTruthComposition
// Phase B の Composition Root（iPhone 側）。
//   - Use Case + Video / Store / Clock を組み立てる
//   - 既存 WatchSessionManager（WCSessionDelegate を保持済）に Router を注入する
@MainActor
final class VBTGroundTruthComposition {
    let videoRecorder: AVFoundationVideoRecorder
    let sessionStore: FileSystemSessionStore
    let clock: SystemClock
    let useCase: VBTReceptionUseCase
    let router: VBTWatchMessageRouter

    // Phase C: ラベリング UI 用 UseCase（仕様書 §10）
    let loadSessionListUseCase: LoadSessionListUseCase
    let loadIMUWaveformUseCase: LoadIMUWaveformUseCase
    let saveLabelsUseCase: SaveLabelsUseCase

    // Phase D: エクスポート用 UseCase / Infrastructure（仕様書 §8）
    let labelsExistenceChecker: FileSystemLabelsExistenceChecker
    let exportSessionUseCase: ExportSessionUseCase

    private weak var attachedSessionManager: WatchSessionManager?

    init() {
        let video = AVFoundationVideoRecorder()
        let store = FileSystemSessionStore()
        let clk = SystemClock()
        let uc = VBTReceptionUseCase(video: video, store: store, clock: clk)
        let rt = VBTWatchMessageRouter(useCase: uc)
        self.videoRecorder = video
        self.sessionStore = store
        self.clock = clk
        self.useCase = uc
        self.router = rt

        // Phase C 配線
        let sessionListLoader = FileSystemSessionListStore()
        let imuLoader = CSVIMUWaveformLoader()
        let labelsStore = FileSystemLabelsStore()
        self.loadSessionListUseCase = LoadSessionListUseCase(loader: sessionListLoader)
        self.loadIMUWaveformUseCase = LoadIMUWaveformUseCase(loader: imuLoader)
        self.saveLabelsUseCase = SaveLabelsUseCase(store: labelsStore)

        // Phase D 配線（仕様書 §8）
        let labelsChecker = FileSystemLabelsExistenceChecker()
        self.labelsExistenceChecker = labelsChecker
        self.exportSessionUseCase = ExportSessionUseCase(
            loader: sessionListLoader,
            labelsChecker: labelsChecker
        )
    }

    /// WatchSessionManager が初期化済の場合に Router を attach する。
    /// `VBTGroundTruthMetaInputView` の onAppear から呼ばれる。
    func attachRouter() {
        // App 全体で唯一の WatchSessionManager に attach するため、最初に attach した参照を保持する。
        guard attachedSessionManager == nil else { return }
        // ContentView が保持する @StateObject の WatchSessionManager に直接アクセスできないため、
        // NotificationCenter で広報し、ContentView 側で受信した時に attach する。
        // 簡易化のため、global notification 経由で attach 要求を送る。
        NotificationCenter.default.post(
            name: VBTGroundTruthComposition.attachRouterRequestNotification,
            object: router
        )
    }

    static let attachRouterRequestNotification = Notification.Name("VBTGroundTruthComposition.attachRouterRequest")
}
