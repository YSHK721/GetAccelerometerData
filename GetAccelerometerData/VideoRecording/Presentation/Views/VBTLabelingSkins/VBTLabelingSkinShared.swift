import SwiftUI
import SensorDataKit

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
}
