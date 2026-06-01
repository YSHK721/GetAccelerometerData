import Foundation
import SensorDataKit

// MARK: - FileSystemSessionListStore
// VBT Ground Truth Tool Phase C: Documents 配下の session_* + meta.json 列挙。
// 仕様書: .docs/VBT_GroundTruth_Tool_Spec.md §10 セッション一覧画面
//
// Clean Architecture:
//   - Infrastructure 層: FileManager + JSONDecoder 隔離
//   - UseCase (`LoadSessionListUseCase`) が `SessionListLoaderPort` 経由で参照
//
// SRP: 「Documents/session_* フォルダ列挙 + meta.json 読み込み」のみ。
//       VALID フィルタ・DTO 変換は UseCase が責務を持つ。
final class FileSystemSessionListStore: SessionListLoaderPort, @unchecked Sendable {

    enum LoaderError: Error {
        case documentDirectoryNotFound
    }

    private let fileManager = FileManager.default

    func loadAll() throws -> [(folderName: String, folderURL: URL, meta: MetaJSONPayload)] {
        guard let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw LoaderError.documentDirectoryNotFound
        }

        let entries = try fileManager.contentsOfDirectory(
            at: documents,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )

        let decoder = JSONDecoder()
        var results: [(folderName: String, folderURL: URL, meta: MetaJSONPayload)] = []
        for url in entries {
            let name = url.lastPathComponent
            guard name.hasPrefix("session_") else { continue }
            var isDir: ObjCBool = false
            guard fileManager.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue else { continue }

            let metaURL = url.appendingPathComponent("meta.json")
            guard fileManager.fileExists(atPath: metaURL.path) else { continue }

            do {
                let data = try Data(contentsOf: metaURL)
                let meta = try decoder.decode(MetaJSONPayload.self, from: data)
                results.append((folderName: name, folderURL: url, meta: meta))
            } catch {
                // 壊れた meta.json は静かにスキップ（UI 側で「該当 0 件」として扱う）
                continue
            }
        }
        // フォルダ名（タイムスタンプ昇順）で安定ソート
        results.sort { $0.folderName < $1.folderName }
        return results
    }
}
