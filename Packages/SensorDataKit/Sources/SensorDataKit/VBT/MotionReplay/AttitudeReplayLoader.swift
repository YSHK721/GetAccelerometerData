import Foundation

// MARK: - AttitudeReplayLoader Protocol
// M-1 改善: MotionReplayViewModel の load 経路を Output Boundary（Protocol）経由に変更し、
// テスト容易性を向上させる（architecture-executor M-1 指摘対応）。
//
// 既定実装 `DefaultAttitudeReplayLoader` は `AttitudeIMUSource.load` + `AttitudeReconstructor.reconstruct`
// を合成する。テスト時は `AttitudeReplayLoader` を準拠した mock を ViewModel へ注入できる。
//
// 配置: SensorDataKit Domain 層。プロトコル自体は I/O / SwiftUI 非依存。
public protocol AttitudeReplayLoader: Sendable {
    /// 指定フォルダから `AttitudeSeries` をロードする。
    /// 既定実装は imu.csv パース → gyro 積分の合成だが、Adapter で差し替え可能。
    func load(folderURL: URL) async throws -> AttitudeSeries
}

// MARK: - DefaultAttitudeReplayLoader
// 既定アダプタ: `AttitudeIMUSource.load(folderURL:)`（File I/O + Pure Parser）+
// `AttitudeReconstructor.reconstruct(from:)`（gyro 積分）を合成する。
public struct DefaultAttitudeReplayLoader: AttitudeReplayLoader {

    public init() {}

    public func load(folderURL: URL) async throws -> AttitudeSeries {
        let samples = try AttitudeIMUSource.load(folderURL: folderURL)
        return try AttitudeReconstructor.reconstruct(from: samples)
    }
}
