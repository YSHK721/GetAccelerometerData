import Foundation
import SwiftUI
import AVFoundation
import Combine
import SensorDataKit

// MARK: - VBTLabelingViewModel
// VBT Ground Truth Tool Phase C: ラベリング画面 ViewModel。
// 仕様書: .docs/VBT_GroundTruth_Tool_Spec.md §10
//
// 責務:
//   - AVPlayer のライフサイクル管理（動画ローカル時刻の取得・スクラブ）
//   - LabelingState（Domain 状態機械）への UI イベント委譲
//   - IMU 波形の読み込みと UI 公開
//   - SaveLabelsUseCase 経由での labels.json 書き出し
//
// Clean Architecture: AVPlayer は Infrastructure 寄りだが、SwiftUI の VideoPlayer / AVPlayer は
// View からも参照する必要があるため、本 ViewModel が橋渡しする（Presentation 層内部）。
@MainActor
final class VBTLabelingViewModel: ObservableObject {

    // UI に晒す状態
    @Published private(set) var state: LabelingState
    @Published private(set) var samples: [IMUWaveformSample] = []
    @Published var currentVideoTime: TimeInterval = 0.0
    @Published var imuCursorTime: TimeInterval = 0.0   // 統一時刻軸（波形カーソル）
    @Published private(set) var videoDuration: TimeInterval = 0.0
    @Published private(set) var saveError: String?
    @Published private(set) var didSave: Bool = false
    @Published var isScrubbing: Bool = false

    let player: AVPlayer
    let folderURL: URL
    let sessionId: String

    private let loadIMU: LoadIMUWaveformUseCase
    private let saveLabels: SaveLabelsUseCase
    // Sendable 制約のため box 経由（deinit が nonisolated でも参照可能にする）
    private let observerHolder = ObserverHolder()

    private final class ObserverHolder: @unchecked Sendable {
        var token: Any?
    }

    init(
        sessionId: String,
        folderURL: URL,
        loadIMU: LoadIMUWaveformUseCase,
        saveLabels: SaveLabelsUseCase
    ) {
        self.sessionId = sessionId
        self.folderURL = folderURL
        self.loadIMU = loadIMU
        self.saveLabels = saveLabels
        self.state = LabelingState(sessionId: sessionId)
        let videoURL = folderURL.appendingPathComponent("video.mp4")
        self.player = AVPlayer(url: videoURL)
        attachTimeObserver()
    }

    nonisolated deinit {
        if let token = observerHolder.token {
            player.removeTimeObserver(token)
        }
    }

    // MARK: - Load

    func load() {
        // IMU 波形ロード
        do {
            let s = try loadIMU.execute(folderURL: folderURL)
            self.samples = s
            // 初期カーソルは最初のサンプルに合わせる
            if let first = s.first {
                self.imuCursorTime = first.timestamp
            }
        } catch {
            self.samples = []
        }
        // 動画 duration
        Task { [weak self] in
            guard let self else { return }
            do {
                let asset = self.player.currentItem?.asset
                if let duration = try await asset?.load(.duration).seconds, duration.isFinite {
                    await MainActor.run { self.videoDuration = duration }
                }
            } catch {
                // 取得失敗時は 0 のまま
            }
        }
    }

    private func attachTimeObserver() {
        let interval = CMTime(seconds: 1.0 / 60.0, preferredTimescale: 600)
        observerHolder.token = player.addPeriodicTimeObserver(
            forInterval: interval, queue: .main
        ) { [weak self] time in
            guard let self else { return }
            let seconds = CMTimeGetSeconds(time)
            Task { @MainActor in
                if !self.isScrubbing {
                    self.currentVideoTime = seconds
                }
            }
        }
    }

    // MARK: - Player controls

    func togglePlayPause() {
        if player.timeControlStatus == .playing {
            player.pause()
        } else {
            player.play()
        }
    }

    func stepForward() {
        let next = max(0.0, currentVideoTime + (1.0 / 60.0))
        seek(to: next)
    }

    func stepBackward() {
        let prev = max(0.0, currentVideoTime - (1.0 / 60.0))
        seek(to: prev)
    }

    func seek(to videoTime: TimeInterval) {
        let clamped = max(0.0, min(videoTime, max(videoDuration, videoTime)))
        currentVideoTime = clamped
        player.seek(
            to: CMTime(seconds: clamped, preferredTimescale: 600),
            toleranceBefore: .zero,
            toleranceAfter: .zero
        )
    }

    // MARK: - Event recording

    func recordBottom() {
        state.recordBottom(atVideoTime: currentVideoTime)
    }

    func recordStart() {
        state.recordStart(atVideoTime: currentVideoTime)
    }

    func recordEnd() {
        state.recordEnd(atVideoTime: currentVideoTime)
    }

    func recordSyncStartVideo() {
        state.recordSyncStartVideo(at: currentVideoTime)
    }

    func recordSyncEndVideo() {
        state.recordSyncEndVideo(at: currentVideoTime)
    }

    func recordSyncStartImu() {
        state.recordSyncStartImu(at: imuCursorTime)
    }

    func recordSyncEndImu() {
        state.recordSyncEndImu(at: imuCursorTime)
    }

    func deleteRep(at index: Int) {
        state.deleteRep(at: index)
    }

    // MARK: - Save

    func save() {
        do {
            try saveLabels.execute(state: state, folder: folderURL)
            self.didSave = true
            self.saveError = nil
        } catch {
            self.didSave = false
            self.saveError = "保存失敗: \(error.localizedDescription)"
        }
    }
}
