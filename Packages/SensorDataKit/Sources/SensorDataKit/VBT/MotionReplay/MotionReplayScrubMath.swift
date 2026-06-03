// VBT Motion Replay Phase B: スクラブバー計算の純粋関数化。
// `MotionReplayView` 内に inline されていた進捗比率・ノブ座標・ドラッグ位置→時刻 計算を抽出し、
// UIKit / SwiftUI に依存しないユニットテスト可能な形へ分離する。
import Foundation
import CoreGraphics

/// MotionReplayView のスクラブバー計算用純粋関数群。
/// `MotionReplayView` から抽出し、ユニットテスト可能にした。
public enum MotionReplayScrubMath {

    /// スクラブノブの既定サイズ（pt）。View 側 Circle().frame と同期させるため定数化。
    /// 仕様変更時はこの定数のみ更新すれば、View / テスト両側の値が同期される。
    public static let defaultKnobSize: CGFloat = 14

    /// 再生位置 [0, 1] の進捗比率を計算する。
    /// duration <= 0 の場合は 0.0、それ以外は clamp(currentTime/duration, 0, 1) を返す。
    public static func progress(currentTime: TimeInterval, duration: TimeInterval) -> Double {
        guard duration > 0 else { return 0.0 }
        return min(1.0, max(0.0, currentTime / duration))
    }

    /// ノブの x 座標（pt）を計算する。
    /// width 内で `[0, width - knobSize]` にクランプし、初期レイアウト時の左端はみ出しを回避する。
    public static func knobOffsetX(
        progress: Double,
        width: CGFloat,
        knobSize: CGFloat = defaultKnobSize
    ) -> CGFloat {
        let raw = width * progress - knobSize / 2
        return max(0, min(width - knobSize, raw))
    }

    /// ドラッグ位置 x（pt）から currentTime（秒）を算出する。
    /// `[0, duration]` にクランプして返す。width <= 0 や duration <= 0 の場合は 0.0 を返す。
    public static func currentTimeFromDragLocation(
        x: CGFloat,
        width: CGFloat,
        duration: TimeInterval
    ) -> TimeInterval {
        guard width > 0, duration > 0 else { return 0.0 }
        let ratio = min(1.0, max(0.0, Double(x / width)))
        return ratio * duration
    }
}
