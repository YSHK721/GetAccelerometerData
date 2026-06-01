import Foundation

// MARK: - ExportSessionUseCase
// VBT Ground Truth Tool Phase D: 仕様書 §8 セッション一括エクスポート用 UseCase。
//   - 入力: セッション ID（フォルダ名）
//   - 出力: セッションフォルダの絶対 URL
//   - エラー: セッション未存在 / VALID 未満 / labels.json 未生成
//
// Clean Architecture:
//   - Application Business Rules 層。Infrastructure（FileManager / UIActivityViewController）には触れない。
//   - SessionListLoaderPort（既存）+ LabelsExistenceCheckerPort（Phase D 新規）に依存。
//
// SRP: 「セッション ID からエクスポート可能なフォルダ URL を解決する」のみ。
//   - 実際の共有シート起動は Presentation 層（iOS UI）に分離。
public final class ExportSessionUseCase: Sendable {

    public enum ExportError: Error, Equatable {
        /// 指定 ID のセッションが存在しない
        case sessionNotFound
        /// session_state が VALID でない
        case sessionNotValid
        /// labels.json が未生成（ラベリング未完了）
        case labelsNotGenerated
    }

    private let loader: SessionListLoaderPort
    private let labelsChecker: LabelsExistenceCheckerPort

    public init(loader: SessionListLoaderPort, labelsChecker: LabelsExistenceCheckerPort) {
        self.loader = loader
        self.labelsChecker = labelsChecker
    }

    /// セッション ID（フォルダ名）からエクスポート対象フォルダの URL を返す。
    /// - Throws: `ExportError.sessionNotFound` / `.sessionNotValid` / `.labelsNotGenerated`
    public func execute(sessionId: String) throws -> URL {
        let items = try loader.loadAll()
        guard let target = items.first(where: { $0.folderName == sessionId }) else {
            throw ExportError.sessionNotFound
        }
        let exportability = SessionExportability.evaluate(
            meta: target.meta,
            labelsExists: labelsChecker.labelsExist(in: target.folderURL)
        )
        guard exportability.isExportable else {
            switch exportability.reason {
            case .sessionNotValid:    throw ExportError.sessionNotValid
            case .labelsNotGenerated: throw ExportError.labelsNotGenerated
            case .none:               throw ExportError.sessionNotValid // 防御的
            }
        }
        return target.folderURL
    }
}
