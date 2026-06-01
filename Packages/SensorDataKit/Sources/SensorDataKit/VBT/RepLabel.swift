import Foundation

// MARK: - RepLabel
// VBT Ground Truth Tool: 各レップのイベント時刻（人手ラベリング結果）。
// 仕様書: .docs/VBT_GroundTruth_Tool_Spec.md §8 labels.json reps[]
//
// SRP: 1 レップの時刻ラベル単位を表現する。
// 不変条件:
//   - repIndex >= 1
//   - startTime（存在時）<= bottomTime <= endTime（存在時）
public struct RepLabel: Codable, Equatable, Sendable {
    public let repIndex: Int
    public let bottomTime: TimeInterval
    public let startTime: TimeInterval?
    public let endTime: TimeInterval?

    public enum ValidationError: Error, Equatable {
        case invalidRepIndex
        case nonMonotonicTimes
    }

    public init(
        repIndex: Int,
        bottomTime: TimeInterval,
        startTime: TimeInterval?,
        endTime: TimeInterval?
    ) throws {
        guard repIndex >= 1 else { throw ValidationError.invalidRepIndex }
        if let start = startTime, start > bottomTime {
            throw ValidationError.nonMonotonicTimes
        }
        if let end = endTime, end < bottomTime {
            throw ValidationError.nonMonotonicTimes
        }
        self.repIndex = repIndex
        self.bottomTime = bottomTime
        self.startTime = startTime
        self.endTime = endTime
    }

    enum CodingKeys: String, CodingKey {
        case repIndex = "rep_index"
        case bottomTime = "bottom_time"
        case startTime = "start_time"
        case endTime = "end_time"
    }
}
