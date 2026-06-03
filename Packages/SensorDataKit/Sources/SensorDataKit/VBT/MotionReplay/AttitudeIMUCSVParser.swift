import Foundation

// MARK: - AttitudeIMUCSVParser
// 純粋 CSV パーサ: imu.csv の文字列内容 → `[GyroSample]` を生成する。
// I/O とパースを分離するため `AttitudeIMUSource.load(folderURL:)` から本パーサへ責務を分割した
// （architecture-executor H-1/H-2 指摘対応）。
//
// SRP: 「CSV テキストから timestamp / gyro_x/y/z 列を抽出 + 検証」のみ。
// FileManager / URL に依存せず、`String` のみを入力とするため macOS テストで完全に再現可能。
//
// 仕様（既存 AttitudeIMUSource からの 1:1 抽出、振る舞い完全等価）:
//   1. 改行で分割、空行除外（物理行番号は 1-indexed で保持）
//   2. 1 行目をヘッダとして取り出し（無ければ missingHeader）
//   3. ヘッダから timestamp / gyro_x / gyro_y / gyro_z のインデックスを取得（順序不問、欠落で missingRequiredColumn）
//   4. データ行 0 件なら emptyData
//   5. 各データ行: 列数不足 → malformedRow、timestamp は CSVTimestampFormatter → Double() の二段 fallback
//   6. timestamp 単調性違反は timestampNotMonotonic
//
// エラー型: 既存 `AttitudeIMUSourceError` を継続採用（後方互換、テスト変更不要）。
// `fileNotFound` ケースのみ本パーサからは投げない（I/O 関心事として `AttitudeIMUSource.load` 側に残置）。
public enum AttitudeIMUCSVParser {

    /// CSV テキストを解析して `[GyroSample]` を返す。
    /// - Parameter csvText: imu.csv の全文（UTF-8 デコード済み）
    /// - Throws: `AttitudeIMUSourceError`（fileNotFound 以外の全ケース）
    public static func parse(csvText: String) throws -> [GyroSample] {
        // 改行で分割し、空行は除外。元 CSV の物理行番号は 1-indexed で保持。
        let physicalLines = csvText.split(separator: "\n", omittingEmptySubsequences: false).map { String($0) }
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
