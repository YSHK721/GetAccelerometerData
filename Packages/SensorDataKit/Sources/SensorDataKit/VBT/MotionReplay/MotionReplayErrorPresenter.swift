// VBT Motion Replay PoC Phase 3: エラー → 表示用日本語メッセージ変換の純粋関数。
// 内部設計書: .docs/07_vbt_motion_replay_internal_design.md §9.2
//
// 配置方針:
//   UIKit / Combine 非依存の純粋ロジックのため、`#if canImport(UIKit) && os(iOS)` ガードの **外** に
//   配置し、macOS テストランナーからも参照可能にする。
//   `MotionReplayViewModel` 本体は iOS 限定のため、本 Presenter を委譲先として利用する。
import Foundation

/// `MotionReplayViewModel` のエラー表示文言生成を担う純粋関数集。
/// ViewModel から分離することで、SwiftUI / Combine に依存せず単体テスト可能にする。
public enum MotionReplayErrorPresenter {

    /// 内部設計書 §9.2 に準拠した日本語メッセージへ変換する。
    /// 既知のドメインエラー（`AttitudeIMUSourceError` / `AttitudeReconstructorError`）は
    /// case ごとに専用文言を返し、未知エラーは `localizedDescription` を含むフォールバックを返す。
    public static func message(for error: Error) -> String {
        if let e = error as? AttitudeIMUSourceError {
            switch e {
            case .fileNotFound(let path):
                return "imu.csv が見つかりません: \(path)"
            case .missingHeader:
                return "imu.csv が空です（ヘッダなし）"
            case .missingRequiredColumn(let name):
                return "必須列が欠落: \(name)"
            case .malformedRow(let line):
                return "\(line) 行目のパース失敗"
            case .timestampNotMonotonic(let line):
                return "\(line) 行目: timestamp が前行より小さい"
            case .emptyData:
                return "imu.csv にデータ行がありません"
            }
        }
        if let e = error as? AttitudeReconstructorError {
            switch e {
            case .insufficientSamples:
                return "サンプル不足"
            }
        }
        return "読み込みエラー: \(error.localizedDescription)"
    }
}
