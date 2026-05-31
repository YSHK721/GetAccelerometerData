import Foundation
import SensorDataKit

// MARK: - AccelerometerDataRepository
// 加速度データアクセスの実装（Data Layer）
final class AccelerometerDataRepository: AccelerometerDataRepositoryProtocol, @unchecked Sendable {
    
    func loadDataFromCSV(fileURL: URL) async throws -> [AccelerometerReading] {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let csvString = try String(contentsOf: fileURL, encoding: .utf8)
                    let readings = try self.parseCSVString(csvString)
                    continuation.resume(returning: readings)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func parseCSVString(_ csvString: String) throws -> [AccelerometerReading] {
        let rows = csvString.components(separatedBy: .newlines)
        var loadedReadings: [AccelerometerReading] = []

        // ヘッダー行をスキップ
        if rows.count > 1 {
            for i in 1..<rows.count {
                let row = rows[i].trimmingCharacters(in: .whitespacesAndNewlines)
                if row.isEmpty { continue }

                if let reading = parseCSVRow(row) {
                    loadedReadings.append(reading)
                }
            }
        }

        // タイムスタンプでソート（昇順）
        loadedReadings.sort { $0.timestamp < $1.timestamp }

        return loadedReadings
    }

    private func parseCSVRow(_ row: String) -> AccelerometerReading? {
        let columns = row.components(separatedBy: ",")
        guard columns.count >= 5,
              let date = CSVTimestampFormatter.parseDate(columns[0]),
              let x = Double(columns[1]),
              let y = Double(columns[2]),
              let z = Double(columns[3]),
              let magnitude = Double(columns[4]) else {
            return nil
        }

        return AccelerometerReading(
            timestamp: date,
            x: x,
            y: y,
            z: z,
            magnitude: magnitude
        )
    }
}
