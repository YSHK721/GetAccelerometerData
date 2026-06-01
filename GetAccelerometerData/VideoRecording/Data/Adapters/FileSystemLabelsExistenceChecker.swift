import Foundation
import SensorDataKit

// MARK: - FileSystemLabelsExistenceChecker
// VBT Ground Truth Tool Phase D: labels.json 存在判定の Infrastructure 実装。
// 仕様書: .docs/VBT_GroundTruth_Tool_Spec.md §8 セッション一括エクスポート型
//
// Clean Architecture:
//   - Infrastructure 層（FileManager 隔離）
//   - `LabelsExistenceCheckerPort`（UseCase 層の抽象）を実装
//
// SRP: 「セッションフォルダ内に labels.json があるか」のみ。
//       I/O 失敗（権限・破損）は防御的に「存在しない」として扱う
//       （エクスポート開始をブロックする方向に倒す）。
final class FileSystemLabelsExistenceChecker: LabelsExistenceCheckerPort, @unchecked Sendable {

    private let fileManager = FileManager.default

    func labelsExist(in folder: URL) -> Bool {
        let labelsURL = folder.appendingPathComponent("labels.json")
        return fileManager.fileExists(atPath: labelsURL.path)
    }
}
