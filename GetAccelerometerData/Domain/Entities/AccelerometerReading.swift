import Foundation

// MARK: - AccelerometerReading
// 加速度データの基本構造体（Domain Entity）
struct AccelerometerReading: Identifiable, Equatable, Sendable {
    let id = UUID()
    let timestamp: Date
    let x: Double
    let y: Double
    let z: Double
    let magnitude: Double
    
    // MARK: - 初期化
    init(timestamp: Date, x: Double, y: Double, z: Double, magnitude: Double) {
        self.timestamp = timestamp
        self.x = x
        self.y = y
        self.z = z
        self.magnitude = magnitude
    }
    
    // MARK: - Equatable準拠
    static func == (lhs: AccelerometerReading, rhs: AccelerometerReading) -> Bool {
        return lhs.timestamp == rhs.timestamp &&
               lhs.x == rhs.x &&
               lhs.y == rhs.y &&
               lhs.z == rhs.z &&
               lhs.magnitude == rhs.magnitude
    }
}
