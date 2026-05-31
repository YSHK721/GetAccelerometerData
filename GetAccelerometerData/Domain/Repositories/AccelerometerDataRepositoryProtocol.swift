import Foundation

// MARK: - AccelerometerDataRepositoryProtocol
// 加速度データアクセスのプロトコル（Domain）
protocol AccelerometerDataRepositoryProtocol: Sendable {
    /// CSVファイルから加速度データを読み込む
    /// - Parameter fileURL: CSVファイルのURL
    /// - Returns: 読み込んだ加速度データの配列
    func loadDataFromCSV(fileURL: URL) async throws -> [AccelerometerReading]
}
