import Foundation

// MARK: - DataStatistics
// 統計情報モデル（Domain Entity）
struct DataStatistics: Equatable, Sendable {
    let maxValue: Double
    let minValue: Double
    let average: Double
    let standardDeviation: Double
    let sampleCount: Int
    let duration: TimeInterval
    let peakToPeak: Double
    let rmsValue: Double
    let medianValue: Double
    let samplingRate: Double
    
    // MARK: - 初期化
    init(
        maxValue: Double,
        minValue: Double,
        average: Double,
        standardDeviation: Double,
        sampleCount: Int,
        duration: TimeInterval,
        peakToPeak: Double,
        rmsValue: Double,
        medianValue: Double,
        samplingRate: Double
    ) {
        self.maxValue = maxValue
        self.minValue = minValue
        self.average = average
        self.standardDeviation = standardDeviation
        self.sampleCount = sampleCount
        self.duration = duration
        self.peakToPeak = peakToPeak
        self.rmsValue = rmsValue
        self.medianValue = medianValue
        self.samplingRate = samplingRate
    }
    
    // MARK: - 空の統計情報
    static let empty = DataStatistics(
        maxValue: 0,
        minValue: 0,
        average: 0,
        standardDeviation: 0,
        sampleCount: 0,
        duration: 0,
        peakToPeak: 0,
        rmsValue: 0,
        medianValue: 0,
        samplingRate: 0
    )
}
