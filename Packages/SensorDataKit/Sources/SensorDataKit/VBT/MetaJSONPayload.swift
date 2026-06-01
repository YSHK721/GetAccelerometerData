import Foundation

// MARK: - MetaJSONPayload
// VBT Ground Truth Tool Phase B: meta.json の永続化形式（仕様書 §6 / §7）。
//
// 仕様書 §7 主要フィールド:
//   - imu_start_timestamp (number?): IMU 記録開始時の motion.timestamp
//   - video_start_iso8601 (string?): 録画開始時の ISO8601 文字列
//   - session_state (string): "PENDING" / "VALID"
//
// SRP: meta.json 書き出し用 DTO + バリデーション（§5 入力データ表のルール）。
// SessionMetadata（既存）は labels.json と疎な「セッション識別子生成」を担う異なる責務。
// 本型は Phase B の meta.json 形式に特化し、PENDING/VALID 状態を保持する。
public struct MetaJSONPayload: Codable, Equatable, Sendable {

    public enum SessionState: String, Codable, Sendable, Equatable {
        case pending = "PENDING"
        case valid = "VALID"
    }

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
    public let imuStartTimestamp: TimeInterval?
    public let videoStartIso8601: String?
    public let sessionState: SessionState

    public init(
        exercise: String,
        weightKg: Double,
        repTarget: Int,
        setIndex: Int,
        subjectId: String,
        imuStartTimestamp: TimeInterval?,
        videoStartIso8601: String?,
        sessionState: SessionState
    ) throws {
        // 仕様書 §5 入力データ表のバリデーションを再適用
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
        self.imuStartTimestamp = imuStartTimestamp
        self.videoStartIso8601 = videoStartIso8601
        self.sessionState = sessionState
    }

    enum CodingKeys: String, CodingKey {
        case exercise
        case weightKg = "weight_kg"
        case repTarget = "rep_target"
        case setIndex = "set_index"
        case subjectId = "subject_id"
        case imuStartTimestamp = "imu_start_timestamp"
        case videoStartIso8601 = "video_start_iso8601"
        case sessionState = "session_state"
    }
}
