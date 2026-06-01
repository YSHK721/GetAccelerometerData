import Foundation

// MARK: - SessionMetadata
// VBT Ground Truth Tool: 1セッションのメタ情報（meta.json に対応）。
// 仕様書: .docs/VBT_GroundTruth_Tool_Spec.md §5（入力）/ §7（meta.json）
//
// SRP: アクター=被験者（メタ入力）が独立変更要求を出す。バリデーション・session_id 生成のみを担う。
// LSP: 値型（struct）として置換可能。事前条件は init で検証。
public struct SessionMetadata: Codable, Equatable, Sendable {
    public let exercise: String
    public let weightKg: Double
    public let repTarget: Int
    public let setIndex: Int
    public let subjectId: String
    public let startedAt: Date
    public let endedAt: Date

    public enum ValidationError: Error, Equatable {
        case emptyExercise
        case nonPositiveWeight
        case invalidRepTarget
        case invalidSetIndex
        case emptySubjectId
    }

    public init(
        exercise: String,
        weightKg: Double,
        repTarget: Int,
        setIndex: Int,
        subjectId: String,
        startedAt: Date,
        endedAt: Date
    ) throws {
        guard !exercise.isEmpty else { throw ValidationError.emptyExercise }
        guard weightKg > 0 else { throw ValidationError.nonPositiveWeight }
        guard repTarget >= 1 else { throw ValidationError.invalidRepTarget }
        guard setIndex >= 0 else { throw ValidationError.invalidSetIndex }
        guard !subjectId.isEmpty else { throw ValidationError.emptySubjectId }
        self.exercise = exercise
        self.weightKg = weightKg
        self.repTarget = repTarget
        self.setIndex = setIndex
        self.subjectId = subjectId
        self.startedAt = startedAt
        self.endedAt = endedAt
    }

    // session_id 生成。
    // 仕様書 §7 例: session_20260531_162601_back_squat_80kg_set1
    public func sessionId(timeZone: TimeZone = .current) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        let stamp = formatter.string(from: startedAt)
        let weightString: String
        if weightKg == weightKg.rounded() {
            weightString = String(Int(weightKg))
        } else {
            weightString = String(weightKg)
        }
        return "session_\(stamp)_\(exercise)_\(weightString)kg_set\(setIndex)"
    }

    enum CodingKeys: String, CodingKey {
        case exercise
        case weightKg = "weight_kg"
        case repTarget = "rep_target"
        case setIndex = "set_index"
        case subjectId = "subject_id"
        case startedAt = "started_at"
        case endedAt = "ended_at"
    }
}
