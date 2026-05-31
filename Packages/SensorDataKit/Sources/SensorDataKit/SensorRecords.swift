import Foundation

// MARK: - センサ計測値（iOS / watchOS 共有）
// ISSUE-015 対応：iOS / Watch 間で別定義されていた以下 4 種類を 1 箇所に統合。
//   - Watch top-level `AccelerometerRecord` / `GyroscopeRecord` / `CombinedSensorData`
//   - iOS `WatchSessionGateway.AccelerometerRecord` / `CombinedSensorData`（nested）

/// 加速度センサーの 1 サンプル
public struct AccelerometerRecord: Codable, Sendable, Equatable {
    public let timestamp: TimeInterval
    public let x: Double
    public let y: Double
    public let z: Double

    public init(timestamp: TimeInterval, x: Double, y: Double, z: Double) {
        self.timestamp = timestamp
        self.x = x
        self.y = y
        self.z = z
    }
}

/// ジャイロスコープセンサーの 1 サンプル
public struct GyroscopeRecord: Codable, Sendable, Equatable {
    public let timestamp: TimeInterval
    public let x: Double
    public let y: Double
    public let z: Double

    public init(timestamp: TimeInterval, x: Double, y: Double, z: Double) {
        self.timestamp = timestamp
        self.x = x
        self.y = y
        self.z = z
    }
}

/// 加速度・ジャイロを統合した転送用のサンプル。
/// iOS / Watch 双方で Codable 互換のシリアライゼーションを行うため公開する。
public struct CombinedSensorData: Codable, Sendable, Equatable {
    public let timestamp: TimeInterval
    public let accelX: Double
    public let accelY: Double
    public let accelZ: Double
    public let accelMagnitude: Double
    public let gyroX: Double
    public let gyroY: Double
    public let gyroZ: Double
    public let gyroMagnitude: Double

    public init(
        timestamp: TimeInterval,
        accelX: Double, accelY: Double, accelZ: Double, accelMagnitude: Double,
        gyroX: Double, gyroY: Double, gyroZ: Double, gyroMagnitude: Double
    ) {
        self.timestamp = timestamp
        self.accelX = accelX
        self.accelY = accelY
        self.accelZ = accelZ
        self.accelMagnitude = accelMagnitude
        self.gyroX = gyroX
        self.gyroY = gyroY
        self.gyroZ = gyroZ
        self.gyroMagnitude = gyroMagnitude
    }
}
