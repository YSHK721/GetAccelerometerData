import Foundation

// MARK: - AttitudeIMUSourceError
public enum AttitudeIMUSourceError: Error, Equatable {
    case fileNotFound(path: String)
    case missingHeader
    case missingRequiredColumn(name: String)
    case malformedRow(line: Int)
    case timestampNotMonotonic(line: Int)
    case emptyData
}

// MARK: - AttitudeIMUSource
// VBT Motion Replay: `<folderURL>/imu.csv` から `[GyroSample]` を読み取るファイル I/O アダプタ。
//
// 責務分離（architecture-executor H-1/H-2 指摘対応、refactor/attitude-imu-source-split）:
//   - 純粋 CSV パース: `AttitudeIMUCSVParser.parse(csvText:)` に委譲（macOS テストで完全再現可能）
//   - ファイル I/O: 本 enum の `load(folderURL:)` のみが FileManager / URL に依存
//
// SRP: 「imu.csv ファイル読み込み」のみ。パース・検証は `AttitudeIMUCSVParser` の責務。
//
// 公開 API は無変更（後方互換）: `static func load(folderURL: URL) throws -> [GyroSample]`
public enum AttitudeIMUSource {

    /// `<folderURL>/imu.csv` を読み込んで `[GyroSample]` を返す。
    /// 1. ファイル存在確認（`fileNotFound`）
    /// 2. UTF-8 で読み込み（Foundation `String(contentsOf:encoding:)` が throw した場合は再 throw）
    /// 3. `AttitudeIMUCSVParser.parse(csvText:)` に委譲
    public static func load(folderURL: URL) throws -> [GyroSample] {
        let fileURL = folderURL.appendingPathComponent("imu.csv")
        let fm = FileManager.default
        guard fm.fileExists(atPath: fileURL.path) else {
            throw AttitudeIMUSourceError.fileNotFound(path: fileURL.path)
        }
        let raw = try String(contentsOf: fileURL, encoding: .utf8)
        return try AttitudeIMUCSVParser.parse(csvText: raw)
    }
}
