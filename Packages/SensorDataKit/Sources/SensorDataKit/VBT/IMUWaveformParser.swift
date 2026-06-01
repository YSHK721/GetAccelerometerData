import Foundation

// MARK: - IMUWaveformSample
// VBT Ground Truth Tool Phase C: imu.csv から抽出した波形サンプル（timestamp + accel_magnitude のみ）。
// SRP: UI プレビュー描画に必要な最小データ単位を表現する。
public struct IMUWaveformSample: Sendable, Equatable {
    public let timestamp: TimeInterval     // 統一時刻軸（IMU motion.timestamp 基準, 秒）
    public let accelMagnitude: Double      // |a| の大きさ

    public init(timestamp: TimeInterval, accelMagnitude: Double) {
        self.timestamp = timestamp
        self.accelMagnitude = accelMagnitude
    }
}

// MARK: - IMUWaveformParser
// VBT Ground Truth Tool Phase C: imu.csv ヘッダ駆動パーサ。
// 仕様書: .docs/VBT_GroundTruth_Tool_Spec.md §7 IMU CSV フォーマット
//   timestamp, accel_x/y/z, accel_magnitude, gyro_x/y/z, gyro_magnitude
//
// SRP: 「CSV 文字列 → timestamp + accel_magnitude 列の値オブジェクト列」変換のみ。
// FileManager 操作・I/O は Infrastructure 層 (`CSVIMUWaveformLoader`) が担う。
public enum IMUWaveformParser {

    public enum ParseError: Error, Equatable {
        case missingHeader
        case missingRequiredColumn(String)
        case malformedRow(line: Int)
    }

    public static func parse(csvString: String) throws -> [IMUWaveformSample] {
        let lines = csvString
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { String($0) }
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }

        guard let headerLine = lines.first else { throw ParseError.missingHeader }
        let header = headerLine.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }
        guard let tsIndex = header.firstIndex(of: "timestamp") else {
            throw ParseError.missingRequiredColumn("timestamp")
        }
        guard let magIndex = header.firstIndex(of: "accel_magnitude") else {
            throw ParseError.missingRequiredColumn("accel_magnitude")
        }

        var samples: [IMUWaveformSample] = []
        samples.reserveCapacity(lines.count - 1)
        for (offset, raw) in lines.dropFirst().enumerated() {
            let cols = raw.split(separator: ",", omittingEmptySubsequences: false).map { String($0) }
            guard cols.count > max(tsIndex, magIndex) else {
                throw ParseError.malformedRow(line: offset + 2)
            }
            guard
                let ts = Double(cols[tsIndex].trimmingCharacters(in: .whitespaces)),
                let mag = Double(cols[magIndex].trimmingCharacters(in: .whitespaces))
            else {
                throw ParseError.malformedRow(line: offset + 2)
            }
            samples.append(IMUWaveformSample(timestamp: ts, accelMagnitude: mag))
        }
        return samples
    }
}
