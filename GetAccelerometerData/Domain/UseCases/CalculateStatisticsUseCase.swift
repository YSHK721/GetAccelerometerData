import Foundation

// MARK: - CalculateStatisticsUseCase
// 統計情報計算のユースケース（Domain）
protocol CalculateStatisticsUseCaseProtocol: Sendable {
    func execute(readings: [AccelerometerReading], dataType: DataType) -> DataStatistics
}

final class CalculateStatisticsUseCase: CalculateStatisticsUseCaseProtocol {
    
    func execute(readings: [AccelerometerReading], dataType: DataType) -> DataStatistics {
        // データがない場合は空の統計情報を返す
        guard !readings.isEmpty else {
            return DataStatistics.empty
        }
        
        // 測定時間
        let duration = readings.last!.timestamp.timeIntervalSince(readings.first!.timestamp)
        
        // 表示されているデータタイプに応じた値を抽出
        let values = extractValues(from: readings, for: dataType)
        
        // 統計値の計算
        let statistics = calculateBasicStatistics(values: values)
        let advancedStatistics = calculateAdvancedStatistics(values: values)
        
        // サンプリングレートの計算（Hz）
        let samplingRate = duration > 0 ? Double(readings.count) / duration : 0
        
        return DataStatistics(
            maxValue: statistics.max,
            minValue: statistics.min,
            average: statistics.average,
            standardDeviation: statistics.standardDeviation,
            sampleCount: readings.count,
            duration: duration,
            peakToPeak: statistics.max - statistics.min,
            rmsValue: advancedStatistics.rms,
            medianValue: advancedStatistics.median,
            samplingRate: samplingRate
        )
    }
    
    // MARK: - Private Methods
    
    private func extractValues(from readings: [AccelerometerReading], for dataType: DataType) -> [Double] {
        switch dataType {
        case .xAxis:
            return readings.map { $0.x }
        case .yAxis:
            return readings.map { $0.y }
        case .zAxis:
            return readings.map { $0.z }
        case .magnitude:
            return readings.map { $0.magnitude }
        case .all:
            return readings.map { $0.magnitude }
        }
    }
    
    private func calculateBasicStatistics(values: [Double]) -> (max: Double, min: Double, average: Double, standardDeviation: Double) {
        let maxValue = values.max() ?? 0
        let minValue = values.min() ?? 0
        let sum = values.reduce(0, +)
        let average = sum / Double(values.count)
        
        // 標準偏差の計算
        let sumOfSquaredDifferences = values.reduce(0) { $0 + pow($1 - average, 2) }
        let standardDeviation = sqrt(sumOfSquaredDifferences / Double(values.count))
        
        return (maxValue, minValue, average, standardDeviation)
    }
    
    private func calculateAdvancedStatistics(values: [Double]) -> (rms: Double, median: Double) {
        // RMS値（二乗平均平方根）の計算
        let sumOfSquares = values.reduce(0) { $0 + pow($1, 2) }
        let rmsValue = sqrt(sumOfSquares / Double(values.count))
        
        // 中央値の計算
        let sortedValues = values.sorted()
        let medianValue: Double
        if sortedValues.count % 2 == 0 {
            let middleIndex = sortedValues.count / 2
            medianValue = (sortedValues[middleIndex - 1] + sortedValues[middleIndex]) / 2
        } else {
            medianValue = sortedValues[sortedValues.count / 2]
        }
        
        return (rmsValue, medianValue)
    }
}
