import Foundation

// MARK: - SyncMarker
// VBT Ground Truth Tool: 物理マーカー2点（記録開始直後・終了直前）の時刻情報。
// 仕様書: .docs/VBT_GroundTruth_Tool_Spec.md §5（物理マーカー主同期）/ §8（labels.json sync_markers）
//
// SRP: 「2点線形補正のための時刻ペア」のみを表現する不変値オブジェクト。
// 不変条件: endTime > startTime（線形補正の傾きが定義されるための前提）。
public struct SyncMarker: Codable, Equatable, Sendable {
    public let startTime: TimeInterval
    public let endTime: TimeInterval

    public enum ValidationError: Error, Equatable {
        case endNotAfterStart
    }

    public init(startTime: TimeInterval, endTime: TimeInterval) throws {
        guard endTime > startTime else { throw ValidationError.endNotAfterStart }
        self.startTime = startTime
        self.endTime = endTime
    }

    enum CodingKeys: String, CodingKey {
        case startTime = "start"
        case endTime = "end"
    }
}
