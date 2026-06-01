import Foundation

// MARK: - VBT Export Ports
// VBT Ground Truth Tool Phase D: 仕様書 §8 セッション一括エクスポート用 Output Boundary。
//
// Clean Architecture / DIP:
//   - UseCase 層が依存する抽象。FileManager は Infrastructure 実装（iOS app 側）に隔離。
//   - ISP: 単一機能（labels.json 存在チェック）のみ。

// MARK: - LabelsExistenceCheckerPort

public protocol LabelsExistenceCheckerPort: AnyObject, Sendable {
    /// 指定セッションフォルダ内に `labels.json` が存在するかを返す。
    /// ファイル I/O 失敗は「存在しない」として扱う（エクスポート可否の防御的判定）。
    func labelsExist(in folder: URL) -> Bool
}
