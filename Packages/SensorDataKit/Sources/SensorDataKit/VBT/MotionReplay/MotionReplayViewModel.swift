// VBT Motion Replay PoC Phase 3: 非同期ロード + Timer 駆動による state.advance() の起動・停止。
// 内部設計書: .docs/07_vbt_motion_replay_internal_design.md §9
//
// ガード方針:
//   ファイル全体を `#if canImport(UIKit) && os(iOS)` でガードし、
//   macOS テストランナーから不可視にする（macOS テスト破壊回避）。
//   Domain 層（MotionReplayState）はガード外で macOS テストにも露出させる。

#if canImport(UIKit) && os(iOS)
import Foundation
import Combine

@MainActor
public final class MotionReplayViewModel: ObservableObject {

    @Published public private(set) var state: MotionReplayState
    @Published public private(set) var loadError: String?

    private var timerCancellable: AnyCancellable?

    /// Timer 周期（約 60Hz）
    private static let tickInterval: TimeInterval = 0.016

    /// M-1: ロード経路を Output Boundary 経由に変更。
    /// テスト時は mock loader を init で注入してロード結果を制御できる。
    private let loader: AttitudeReplayLoader

    public init(loader: AttitudeReplayLoader = DefaultAttitudeReplayLoader()) {
        self.state = MotionReplayState()
        self.loadError = nil
        self.timerCancellable = nil
        self.loader = loader
    }

    /// imu.csv を読み AttitudeSeries を構築。失敗時は loadError 設定。
    /// 重い処理（パース + 数値積分）は detached Task で `.userInitiated` 優先度実行し、
    /// 結果のみを MainActor 経由で state に反映する。
    public func load(folderURL: URL) async {
        // 🟡-1: 再エントラント保護。再生中の load 呼び出しでも確定的初期状態から開始する。
        stopTimer()
        self.state.isPlaying = false
        self.state.currentTime = 0
        self.loadError = nil

        let capturedLoader = self.loader
        let result: Result<AttitudeSeries, Error> = await Task.detached(priority: .userInitiated) {
            do {
                let series = try await capturedLoader.load(folderURL: folderURL)
                return .success(series)
            } catch {
                return .failure(error)
            }
        }.value

        switch result {
        case .success(let series):
            self.state.series = series
            self.state.currentTime = 0
            self.state.isPlaying = false
            self.loadError = nil
        case .failure(let error):
            self.loadError = MotionReplayErrorPresenter.message(for: error)
        }
    }

    /// 再生 ↔ 一時停止トグル。
    public func togglePlayPause() {
        if state.isPlaying {
            state.pause()
            stopTimer()
        } else {
            state.play()
            if state.isPlaying {
                startTimer()
            }
        }
    }

    /// シーク（Timer 状態は維持）。
    public func seek(to time: TimeInterval) {
        state.seek(to: time)
    }

    // Swift 6 strict concurrency: nonisolated deinit から MainActor-isolated property
    // である timerCancellable を直接 cancel() できないため、明示的 deinit は持たない。
    // AnyCancellable は dealloc 時に自動 cancel するため、参照を持つだけで充分。

    // MARK: - Timer

    private func startTimer() {
        timerCancellable?.cancel()
        timerCancellable = Timer.publish(every: Self.tickInterval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.tickAdvance()
            }
    }

    private func stopTimer() {
        timerCancellable?.cancel()
        timerCancellable = nil
    }

    private func tickAdvance() {
        state.advance(by: Self.tickInterval)
        if !state.isPlaying {
            stopTimer()
        }
    }

    // MARK: - Error mapping (内部設計書 §9.2 準拠)
    // 純粋ロジックは `MotionReplayErrorPresenter` に分離（macOS テストランナーから検証可能にするため）。
}
#endif
