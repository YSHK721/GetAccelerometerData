import Foundation
import SensorDataKit

// MARK: - SensorDataRepository
// FileManager + CSV 文字列構築を隔離する Repository。
// AccelerometerManager から CSV 永続化の責務を切り出す（ISSUE-001 対応）。
@MainActor
final class SensorDataRepository {

    /// 統合済みセンサーデータを `sensor_data_yyyyMMdd_HHmmss.csv` として
    /// ドキュメントディレクトリに保存する。
    /// - Returns: 保存に成功した場合はファイル URL、失敗時は `nil`。
    func saveCSV(combinedData: [CombinedSensorData]) -> URL? {
        guard !combinedData.isEmpty else {
            print("保存するデータがありません")
            return nil
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        let timeStamp = formatter.string(from: Date())
        let fileName = "sensor_data_\(timeStamp).csv"

        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("ドキュメントディレクトリにアクセスできません")
            return nil
        }

        let fileURL = documentsDirectory.appendingPathComponent(fileName)

        var csvString = "timestamp,accel_x,accel_y,accel_z,accel_magnitude,gyro_x,gyro_y,gyro_z,gyro_magnitude\n"
        for data in combinedData {
            let timeString = CSVTimestampFormatter.format(data.timestamp)
            csvString.append("\(timeString),\(data.accelX),\(data.accelY),\(data.accelZ),\(data.accelMagnitude),\(data.gyroX),\(data.gyroY),\(data.gyroZ),\(data.gyroMagnitude)\n")
        }

        do {
            try csvString.write(to: fileURL, atomically: true, encoding: .utf8)
            print("データを保存しました: \(fileURL.path)")
            return fileURL
        } catch {
            print("データの保存に失敗しました: \(error)")
            return nil
        }
    }
}
