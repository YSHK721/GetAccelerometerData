import Foundation

// MARK: - VBTPrerequisiteValidator
// 仕様書: .docs/VBT_GroundTruth_Tool_Spec.md §3 / §6 step 3
//   技術前提（接続/権限/容量/IMU）のいずれかが欠ける場合、記録開始をブロックし
//   欠落した前提名をユーザーに明示する。
//
// SRP: 前提条件の充足チェックと欠落リストの算出のみを担う純粋計算ロジック。
// DIP: ProbePort 経由で外部状態を取得する（テスト容易性のため）。

public protocol VBTPrerequisiteProbe: Sendable {
    var isWatchConnectivityReachable: Bool { get }
    var isDeviceMotionAvailable: Bool { get }
    var freeStorageBytes: Int64 { get }
}

public struct VBTPrerequisiteValidator: Sendable {

    /// 仕様書 §9: ストレージ不足 = 500MB 未満
    public static let minimumFreeStorageBytes: Int64 = 500 * 1024 * 1024

    public init() {}

    /// 欠落している前提名のリストを返す。空であれば全前提充足。
    public func validate(probe: VBTPrerequisiteProbe) -> [String] {
        var missing: [String] = []
        if !probe.isWatchConnectivityReachable {
            missing.append("iPhone接続")
        }
        if !probe.isDeviceMotionAvailable {
            missing.append("IMU")
        }
        if probe.freeStorageBytes < Self.minimumFreeStorageBytes {
            missing.append("ストレージ容量")
        }
        return missing
    }
}
