import SwiftUI
import SensorDataKit

// MARK: - SharedVideoScrubBar
// 5 スキンで重複していた動画スクラブバー UI を 1 つの View に集約。
// 視覚パラメータ（capsule 高さ / 色 / ノブサイズ / SYNC ライン寸法）はスキン側で指定。
// 共通振る舞い: 進捗 Capsule + SYNC START/END マーカー線 + 円形ノブ + LongPress(0.5s)+Drag ジェスチャ
struct SharedVideoScrubBar: View {

    @ObservedObject var viewModel: VBTLabelingViewModel

    // 視覚パラメータ（デフォルトは Classic/CardBased 値）
    var trackHeight: CGFloat = 6
    var trackInactiveColor: Color = Color.gray.opacity(0.3)
    var trackActiveColor: Color = .blue
    var knobSize: CGFloat = 14
    var knobColor: Color = .blue
    var knobShadow: Bool = false
    var syncLineHeight: CGFloat = 18
    var syncLineWidth: CGFloat = 2

    var body: some View {
        GeometryReader { geo in
            let progress = VBTLabelingSkinShared.videoProgress(
                currentTime: viewModel.currentVideoTime,
                duration: viewModel.videoDuration
            )
            ZStack(alignment: .leading) {
                Capsule().fill(trackInactiveColor).frame(height: trackHeight)
                Capsule().fill(trackActiveColor)
                    .frame(width: geo.size.width * progress, height: trackHeight)
                if viewModel.videoDuration > 0 {
                    if let s = viewModel.state.syncMarkerVideoStart {
                        let x = geo.size.width * min(1.0, max(0.0, s / viewModel.videoDuration))
                        Rectangle().fill(Color.green)
                            .frame(width: syncLineWidth, height: syncLineHeight)
                            .offset(x: x - syncLineWidth / 2)
                    }
                    if let e = viewModel.state.syncMarkerVideoEnd {
                        let x = geo.size.width * min(1.0, max(0.0, e / viewModel.videoDuration))
                        Rectangle().fill(Color.orange)
                            .frame(width: syncLineWidth, height: syncLineHeight)
                            .offset(x: x - syncLineWidth / 2)
                    }
                }
                knobView
                    .offset(x: geo.size.width * progress - knobSize / 2)
            }
            .contentShape(Rectangle())
            .gesture(scrubGesture(width: geo.size.width))
        }
    }

    @ViewBuilder
    private var knobView: some View {
        if knobShadow {
            Circle().fill(knobColor).frame(width: knobSize, height: knobSize)
                .shadow(color: knobColor.opacity(0.6), radius: 6)
        } else {
            Circle().fill(knobColor).frame(width: knobSize, height: knobSize)
        }
    }

    private func scrubGesture(width: CGFloat) -> some Gesture {
        LongPressGesture(minimumDuration: 0.5)
            .sequenced(before: DragGesture(minimumDistance: 0))
            .onChanged { value in
                if case .second(true, let drag?) = value {
                    viewModel.isScrubbing = true
                    let ratio = min(1.0, max(0.0, drag.location.x / width))
                    viewModel.seek(to: ratio * viewModel.videoDuration)
                }
            }
            .onEnded { _ in viewModel.isScrubbing = false }
    }
}

/// 5 スキンが共有する純粋ヘルパー集。
/// 仕様変更は本ファイルのみで反映されるため、スキン間の挙動ずれを防止する。
enum VBTLabelingSkinShared {

    /// 既存 VBTLabelingView.swift:197-213 と等価の IMU 波形スクラブジェスチャ。
    /// 0.5 秒長押し → ドラッグで `viewModel.imuCursorTime` を更新する。
    /// - Parameters:
    ///   - viewModel: 共有 VBTLabelingViewModel
    ///   - containerWidth: 波形コンテナの想定幅（pt）。drag.location.x を [0,1] にクランプするための分母。
    ///     既存実装に合わせて既定 300pt。スキン側で異なる幅を採用する場合に明示指定する。
    /// - Note: GeometryReader を介さない簡易マッピング。改善は後段（仕様書範囲外）。
    @MainActor
    static func imuScrubGesture(
        viewModel: VBTLabelingViewModel,
        containerWidth: CGFloat = 300
    ) -> some Gesture {
        LongPressGesture(minimumDuration: 0.5)
            .sequenced(before: DragGesture(minimumDistance: 0))
            .onChanged { value in
                if case .second(true, let drag?) = value {
                    if let first = viewModel.samples.first?.timestamp,
                       let last = viewModel.samples.last?.timestamp,
                       last > first {
                        let ratio = max(0.0, min(1.0, drag.location.x / containerWidth))
                        viewModel.imuCursorTime = first + ratio * (last - first)
                    }
                }
            }
    }

    /// 欠落要素の日本語ラベル変換。既存 VBTLabelingView.missingLabel と等価。
    static func missingLabel(_ r: LabelingState.MissingRequirement) -> String {
        switch r {
        case .syncVideoStart:           return "SYNC START (Video) 未記録"
        case .syncVideoEnd:             return "SYNC END (Video) 未記録"
        case .syncImuStart:             return "SYNC START (IMU) 未記録"
        case .syncImuEnd:               return "SYNC END (IMU) 未記録"
        case .atLeastOneRep:            return "レップが 0 件（BOTTOM を最低1回）"
        case .bottomTimeMissing(let i): return "rep #\(i) の bottom_time 欠落"
        case .syncVideoOrderInvalid:    return "SYNC (Video) 順序不正（END > START でない）"
        case .syncImuOrderInvalid:      return "SYNC (IMU) 順序不正（END > START でない）"
        }
    }

    /// Compact スキン用の短縮ラベル変換。
    /// 1 画面密集配置のため文字数を抑えた版。`missingLabel` と用途違いで併存させる。
    /// 文言は CompactLabelingSkin の従前 private 実装と完全等価。
    static func shortMissingLabel(_ r: LabelingState.MissingRequirement) -> String {
        switch r {
        case .syncVideoStart:           return "SYNC-S(V)"
        case .syncVideoEnd:             return "SYNC-E(V)"
        case .syncImuStart:             return "SYNC-S(I)"
        case .syncImuEnd:               return "SYNC-E(I)"
        case .atLeastOneRep:            return "BOTTOM未"
        case .bottomTimeMissing(let i): return "#\(i)bottom欠"
        case .syncVideoOrderInvalid:    return "V順不正"
        case .syncImuOrderInvalid:      return "I順不正"
        }
    }

    /// 動画スクラブバーの進捗比率 [0, 1] を計算する純粋関数。
    /// duration <= 0 の場合は 0.0、それ以外は clamp(currentTime/duration, 0, 1) を返す。
    static func videoProgress(currentTime: TimeInterval, duration: TimeInterval) -> Double {
        guard duration > 0 else { return 0.0 }
        return min(1.0, max(0.0, currentTime / duration))
    }
}
