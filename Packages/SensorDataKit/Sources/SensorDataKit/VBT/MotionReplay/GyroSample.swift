import Foundation

// MARK: - GyroSample
// VBT Motion Replay PoC Phase 2: 角速度（gyro）1 サンプルを表現する純粋値型。
// 内部設計書: .docs/07_vbt_motion_replay_internal_design.md §6 Step 1-6
//
// SRP: 「1 サンプルの timestamp + gyro 3 軸（rad/s）の値保持」のみ。
// Foundation のみ依存（simd / SwiftUI / SceneKit 非依存）。
public struct GyroSample: Sendable, Equatable {

    /// UNIX 秒（imu.csv の timestamp 列）
    public let timestamp: TimeInterval
    /// 角速度 x [rad/s]
    public let x: Double
    /// 角速度 y [rad/s]
    public let y: Double
    /// 角速度 z [rad/s]
    public let z: Double

    public init(timestamp: TimeInterval, x: Double, y: Double, z: Double) {
        self.timestamp = timestamp
        self.x = x
        self.y = y
        self.z = z
    }
}
