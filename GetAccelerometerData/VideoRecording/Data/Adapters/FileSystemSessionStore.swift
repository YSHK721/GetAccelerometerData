import Foundation
import SensorDataKit

// MARK: - FileSystemSessionStore
// VBT Ground Truth Tool Phase B: セッションフォルダ + meta.json アトミック書き込み。
// 仕様書: .docs/VBT_GroundTruth_Tool_Spec.md §7 / §10
//   - フォルダ: Documents/session_YYYYMMDD_HHMMSS_<exercise>_<weight_kg>kg_set<set_index>/
//   - meta.json は `FileManager.replaceItemAt` 経由でアトミック書き込み
//
// Clean Architecture:
//   - Infrastructure 層: FileManager 隔離
//   - Use Case（VBTReceptionUseCase）から `SessionStorePort` 経由でのみ参照される
final class FileSystemSessionStore: SessionStorePort, @unchecked Sendable {

    enum StoreError: Error {
        case documentDirectoryNotFound
        case folderAlreadyExists(URL)
        case encodingFailed(Error)
    }

    private let fileManager = FileManager.default

    func createFolder(name: String) throws -> URL {
        guard let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw StoreError.documentDirectoryNotFound
        }
        let folder = documents.appendingPathComponent(name, isDirectory: true)
        if fileManager.fileExists(atPath: folder.path) {
            // 同名フォルダが既に存在する場合、上書きを避けて失敗扱い（PENDING 排他保証）
            throw StoreError.folderAlreadyExists(folder)
        }
        try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    func importIMUFile(from source: URL, to folder: URL) throws -> URL {
        let dest = folder.appendingPathComponent("imu.csv")
        if fileManager.fileExists(atPath: dest.path) {
            try fileManager.removeItem(at: dest)
        }
        try fileManager.copyItem(at: source, to: dest)
        return dest
    }

    func importVideoFile(from source: URL, to folder: URL) throws -> URL {
        let dest = folder.appendingPathComponent("video.mp4")
        if fileManager.fileExists(atPath: dest.path) {
            try fileManager.removeItem(at: dest)
        }
        try fileManager.moveItem(at: source, to: dest)
        return dest
    }

    func writeMetaJSON(_ payload: MetaJSONPayload, to folder: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data: Data
        do {
            data = try encoder.encode(payload)
        } catch {
            throw StoreError.encodingFailed(error)
        }

        let target = folder.appendingPathComponent("meta.json")
        let tmp = folder.appendingPathComponent("meta.json.tmp")

        // tmp に書き出して replaceItemAt でアトミック置換（§10 と同じ書き込み戦略）
        try data.write(to: tmp, options: .atomic)

        if fileManager.fileExists(atPath: target.path) {
            _ = try fileManager.replaceItemAt(target, withItemAt: tmp)
        } else {
            try fileManager.moveItem(at: tmp, to: target)
        }
    }

    func finalize(folder: URL) throws {
        // フォルダ自体のフラッシュは OS 任せ。Phase B では特別な後処理なし。
        _ = folder
    }

    func delete(folder: URL) {
        try? fileManager.removeItem(at: folder)
    }
}

// MARK: - SystemClock

final class SystemClock: ClockPort, @unchecked Sendable {
    func currentDate() -> Date { Date() }
}
