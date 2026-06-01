import Foundation
import SensorDataKit

// MARK: - FileSystemLabelsStore
// VBT Ground Truth Tool Phase C: labels.json アトミック書き込み。
// 仕様書: .docs/VBT_GroundTruth_Tool_Spec.md §10
//   "labels.json.tmp に書き込み → FileManager.replaceItemAt で labels.json に rename"
//
// Clean Architecture:
//   - Infrastructure 層: FileManager + JSONEncoder 隔離
//   - UseCase (`SaveLabelsUseCase`) が `LabelsStorePort` 経由で参照
//
// SRP: アトミック書き込みのみ（payload 構築は Domain `LabelingState.buildPayload`）。
final class FileSystemLabelsStore: LabelsStorePort, @unchecked Sendable {

    enum StoreError: Error {
        case encodingFailed(Error)
    }

    private let fileManager = FileManager.default

    func writeLabelsJSON(_ payload: LabelsJSONPayload, to folder: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data: Data
        do {
            data = try encoder.encode(payload)
        } catch {
            throw StoreError.encodingFailed(error)
        }

        let target = folder.appendingPathComponent("labels.json")
        let tmp = folder.appendingPathComponent("labels.json.tmp")

        try data.write(to: tmp, options: .atomic)

        if fileManager.fileExists(atPath: target.path) {
            _ = try fileManager.replaceItemAt(target, withItemAt: tmp)
        } else {
            try fileManager.moveItem(at: tmp, to: target)
        }
    }
}
