import Foundation

// MARK: - SessionExportability
// VBT Ground Truth Tool Phase D: エクスポート可否判定の純ドメインロジック。
// 仕様書: .docs/VBT_GroundTruth_Tool_Spec.md §8 セッション一括エクスポート型
//   - session_state == "VALID" のみエクスポート可能
//   - labels.json が存在する（ラベリング完了済み）のみエクスポート可能
//
// Clean Architecture:
//   - Pure ドメイン値オブジェクト（FileManager 等の Infrastructure 依存なし）
//   - labels.json の存在判定は LabelsExistenceCheckerPort 経由で UseCase が解決
//
// SRP: 「meta.json と labels.json 存在の 2 入力からエクスポート可否を判定する」のみ。
public struct SessionExportability: Sendable, Equatable {

    public enum Reason: String, Sendable, Equatable {
        /// session_state が VALID でない（PENDING 等）
        case sessionNotValid
        /// labels.json が未生成（ラベリング未完了）
        case labelsNotGenerated
    }

    public let isExportable: Bool
    public let reason: Reason?

    private init(isExportable: Bool, reason: Reason?) {
        self.isExportable = isExportable
        self.reason = reason
    }

    /// meta.json と labels.json 存在情報からエクスポート可否を判定する。
    /// - Parameters:
    ///   - meta: セッションの meta.json 内容
    ///   - labelsExists: 当該セッションフォルダに labels.json が存在するか
    /// - Returns: 可否判定値オブジェクト
    /// - Note: sessionNotValid と labelsNotGenerated が同時成立する場合、sessionNotValid を優先する
    ///   （より根本的な前提崩壊であり、ラベリング以前の問題のため）。
    public static func evaluate(meta: MetaJSONPayload, labelsExists: Bool) -> SessionExportability {
        guard meta.sessionState == .valid else {
            return SessionExportability(isExportable: false, reason: .sessionNotValid)
        }
        guard labelsExists else {
            return SessionExportability(isExportable: false, reason: .labelsNotGenerated)
        }
        return SessionExportability(isExportable: true, reason: nil)
    }
}
