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
// VBT Motion Replay PoC Phase 2: `<folderURL>/imu.csv` から `[GyroSample]` を読み取る独立パーサ。
// 内部設計書: .docs/07_vbt_motion_replay_internal_design.md §6 Step 1-6
//
// SRP: 「imu.csv → [GyroSample] の読み取り + 検証」のみ。
// 既存 `IMUWaveformParser` には触れず、独立実装として配置する（accel_magnitude 抽出と
// 責務を分離するため、両者は別 SRP として共存する）。
//
// 仕様（厳密準拠）:
//   1. `folderURL/imu.csv` の存在を `FileManager.default.fileExists(atPath:)` で確認
//   2. `String(contentsOf:encoding:)` で読み込み
//   3. 改行で分割、空行除外
//   4. 1 行目をヘッダとして取り出し（無ければ missingHeader）
//   5. ヘッダから timestamp / gyro_x / gyro_y / gyro_z のインデックスを取得（順序不問）
//   6. データ行 0 件なら emptyData
//   7. 各データ行をパース:
//      - timestamp: CSVTimestampFormatter.parseTimeInterval → Double() の二段フォールバック（ISSUE-024 と同方式）
//      - gyro_x/y/z: Double() でパース
//      - 列数不足は malformedRow
//   8. 直前サンプルより厳密に小さい timestamp は timestampNotMonotonic
public enum AttitudeIMUSource {

    public static func load(folderURL: URL) throws -> [GyroSample] {
        let fileURL = folderURL.appendingPathComponent("imu.csv")
        let fm = FileManager.default
        guard fm.fileExists(atPath: fileURL.path) else {
            throw AttitudeIMUSourceError.fileNotFound(path: fileURL.path)
        }

        let raw = try String(contentsOf: fileURL, encoding: .utf8)

        // 改行で分割し、空行は除外。元 CSV の物理行番号は line index（1-indexed）。
        let physicalLines = raw.split(separator: "\n", omittingEmptySubsequences: false).map { String($0) }
        // 非空行のみを (元行番号, 行内容) のタプルで保持
        var nonEmpty: [(line: Int, content: String)] = []
        nonEmpty.reserveCapacity(physicalLines.count)
        for (idx, content) in physicalLines.enumerated() {
            if !content.trimmingCharacters(in: .whitespaces).isEmpty {
                nonEmpty.append((line: idx + 1, content: content))
            }
        }

        guard let headerEntry = nonEmpty.first else {
            throw AttitudeIMUSourceError.missingHeader
        }

        let header = headerEntry.content
            .split(separator: ",", omittingEmptySubsequences: false)
            .map { String($0).trimmingCharacters(in: .whitespaces) }

        guard let tsIndex = header.firstIndex(of: "timestamp") else {
            throw AttitudeIMUSourceError.missingRequiredColumn(name: "timestamp")
        }
        guard let gxIndex = header.firstIndex(of: "gyro_x") else {
            throw AttitudeIMUSourceError.missingRequiredColumn(name: "gyro_x")
        }
        guard let gyIndex = header.firstIndex(of: "gyro_y") else {
            throw AttitudeIMUSourceError.missingRequiredColumn(name: "gyro_y")
        }
        guard let gzIndex = header.firstIndex(of: "gyro_z") else {
            throw AttitudeIMUSourceError.missingRequiredColumn(name: "gyro_z")
        }

        let dataRows = Array(nonEmpty.dropFirst())
        guard !dataRows.isEmpty else {
            throw AttitudeIMUSourceError.emptyData
        }

        let maxIndex = max(tsIndex, gxIndex, gyIndex, gzIndex)

        var samples: [GyroSample] = []
        samples.reserveCapacity(dataRows.count)

        var previousTimestamp: TimeInterval? = nil

        for row in dataRows {
            let cols = row.content
                .split(separator: ",", omittingEmptySubsequences: false)
                .map { String($0) }
            guard cols.count > maxIndex else {
                throw AttitudeIMUSourceError.malformedRow(line: row.line)
            }
            let tsRaw = cols[tsIndex].trimmingCharacters(in: .whitespaces)
            let gxRaw = cols[gxIndex].trimmingCharacters(in: .whitespaces)
            let gyRaw = cols[gyIndex].trimmingCharacters(in: .whitespaces)
            let gzRaw = cols[gzIndex].trimmingCharacters(in: .whitespaces)

            // ISSUE-024 と同じ二段フォールバック
            let ts: Double
            if let parsed = CSVTimestampFormatter.parseTimeInterval(tsRaw) {
                ts = parsed
            } else if let parsedDouble = Double(tsRaw) {
                ts = parsedDouble
            } else {
                throw AttitudeIMUSourceError.malformedRow(line: row.line)
            }

            guard let gx = Double(gxRaw),
                  let gy = Double(gyRaw),
                  let gz = Double(gzRaw) else {
                throw AttitudeIMUSourceError.malformedRow(line: row.line)
            }

            if let prev = previousTimestamp, ts < prev {
                throw AttitudeIMUSourceError.timestampNotMonotonic(line: row.line)
            }
            previousTimestamp = ts

            samples.append(GyroSample(timestamp: ts, x: gx, y: gy, z: gz))
        }

        return samples
    }
}
