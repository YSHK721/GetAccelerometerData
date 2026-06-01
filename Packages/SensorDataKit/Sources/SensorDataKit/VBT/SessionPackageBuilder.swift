import Foundation

// MARK: - SessionPackageBuilder
// VBT Ground Truth Tool: アトミック型継続性戦略の中核判定。
// 仕様書: .docs/VBT_GroundTruth_Tool_Spec.md §6 / §9
//   「IF (IMU記録あり AND 動画記録あり) THEN セッションを有効として保存
//    ELSE セッション全体を無効とし両デバイスの記録を破棄」
//
// SRP: 「2 種の記録存在に基づくセッション有効性判定」のみを担う純粋関数。
// 副作用なし。記録の物理削除は呼び出し側（インフラ層）が responsibility を持つ。
public enum SessionPackageBuilder {
    public enum InvalidReason: Equatable, Sendable {
        case missingIMU
        case missingVideo
        case missingBoth
    }

    public enum EvaluationResult: Equatable, Sendable {
        case valid
        case invalid(reason: InvalidReason)
    }

    public static func evaluate(
        hasIMURecording: Bool,
        hasVideoRecording: Bool
    ) -> EvaluationResult {
        switch (hasIMURecording, hasVideoRecording) {
        case (true, true):
            return .valid
        case (true, false):
            return .invalid(reason: .missingVideo)
        case (false, true):
            return .invalid(reason: .missingIMU)
        case (false, false):
            return .invalid(reason: .missingBoth)
        }
    }
}
