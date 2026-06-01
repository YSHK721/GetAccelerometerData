import Foundation

// MARK: - VBTSessionInput
// 仕様書: .docs/VBT_GroundTruth_Tool_Spec.md §5 入力データ表
//   メタ入力 5 項目: exercise / weight_kg / rep_target / set_index / subject_id
//   バリデーション: 非空 / > 0 / >= 1 / >= 0 / 非空
//
// SRP: 入力フォームのバリデーションのみ。永続化（meta.json）形式は MetaJSONPayload が担う。
public struct VBTSessionInput: Equatable, Sendable {

    public enum ValidationError: Error, Equatable {
        case emptyExercise
        case nonPositiveWeight
        case invalidRepTarget
        case invalidSetIndex
        case emptySubjectId
    }

    public let exercise: String
    public let weightKg: Double
    public let repTarget: Int
    public let setIndex: Int
    public let subjectId: String

    public init(
        exercise: String,
        weightKg: Double,
        repTarget: Int,
        setIndex: Int,
        subjectId: String
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
    }
}
