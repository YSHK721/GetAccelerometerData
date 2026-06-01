import Foundation
import SensorDataKit

// MARK: - CSVIMUWaveformLoader
// VBT Ground Truth Tool Phase C: imu.csv 読み込み + ヘッダ駆動パース。
// 仕様書: .docs/VBT_GroundTruth_Tool_Spec.md §7 IMU CSV
//
// Clean Architecture:
//   - Infrastructure 層: ファイル I/O のみ隔離。パース本体は `IMUWaveformParser`（Domain）に委譲。
//   - UseCase (`LoadIMUWaveformUseCase`) が `IMUWaveformLoaderPort` 経由で参照
final class CSVIMUWaveformLoader: IMUWaveformLoaderPort, @unchecked Sendable {

    enum LoaderError: Error {
        case fileNotFound(URL)
    }

    private let fileManager = FileManager.default

    func load(fromFolder folder: URL) throws -> [IMUWaveformSample] {
        let csvURL = folder.appendingPathComponent("imu.csv")
        guard fileManager.fileExists(atPath: csvURL.path) else {
            throw LoaderError.fileNotFound(csvURL)
        }
        let content = try String(contentsOf: csvURL, encoding: .utf8)
        return try IMUWaveformParser.parse(csvString: content)
    }
}
