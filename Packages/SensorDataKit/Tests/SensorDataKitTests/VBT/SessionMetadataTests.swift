// VBT Ground Truth Tool: SessionMetadata（Item5 入力, Item7 meta.json）
// 仕様書: .docs/VBT_GroundTruth_Tool_Spec.md §5 / §7
import XCTest
@testable import SensorDataKit

final class SessionMetadataTests: XCTestCase {

    // MARK: 正常系: 全項目正当なら生成成功
    func test_init_withValidFields_succeeds() throws {
        let meta = try SessionMetadata(
            exercise: "back_squat",
            weightKg: 80,
            repTarget: 10,
            setIndex: 1,
            subjectId: "ao",
            startedAt: Date(timeIntervalSince1970: 1_700_000_000),
            endedAt: Date(timeIntervalSince1970: 1_700_000_060)
        )
        XCTAssertEqual(meta.exercise, "back_squat")
        XCTAssertEqual(meta.weightKg, 80)
        XCTAssertEqual(meta.repTarget, 10)
        XCTAssertEqual(meta.setIndex, 1)
        XCTAssertEqual(meta.subjectId, "ao")
    }

    // MARK: 異常系: exercise 空
    func test_init_withEmptyExercise_throws() {
        XCTAssertThrowsError(try SessionMetadata(
            exercise: "",
            weightKg: 80, repTarget: 10, setIndex: 1, subjectId: "ao",
            startedAt: Date(), endedAt: Date()
        )) { error in
            XCTAssertEqual(error as? SessionMetadata.ValidationError, .emptyExercise)
        }
    }

    // MARK: 境界値: weight_kg = 0 は不可（> 0）
    func test_init_withZeroWeight_throws() {
        XCTAssertThrowsError(try SessionMetadata(
            exercise: "back_squat",
            weightKg: 0, repTarget: 10, setIndex: 1, subjectId: "ao",
            startedAt: Date(), endedAt: Date()
        )) { error in
            XCTAssertEqual(error as? SessionMetadata.ValidationError, .nonPositiveWeight)
        }
    }

    // MARK: 境界値: weight_kg < 0
    func test_init_withNegativeWeight_throws() {
        XCTAssertThrowsError(try SessionMetadata(
            exercise: "back_squat",
            weightKg: -1, repTarget: 10, setIndex: 1, subjectId: "ao",
            startedAt: Date(), endedAt: Date()
        )) { error in
            XCTAssertEqual(error as? SessionMetadata.ValidationError, .nonPositiveWeight)
        }
    }

    // MARK: 境界値: rep_target = 0 は不可（>= 1）
    func test_init_withZeroRepTarget_throws() {
        XCTAssertThrowsError(try SessionMetadata(
            exercise: "back_squat",
            weightKg: 80, repTarget: 0, setIndex: 1, subjectId: "ao",
            startedAt: Date(), endedAt: Date()
        )) { error in
            XCTAssertEqual(error as? SessionMetadata.ValidationError, .invalidRepTarget)
        }
    }

    // MARK: 境界値: rep_target = 1 は可
    func test_init_withRepTargetOne_succeeds() throws {
        let meta = try SessionMetadata(
            exercise: "back_squat", weightKg: 80, repTarget: 1,
            setIndex: 0, subjectId: "ao",
            startedAt: Date(), endedAt: Date()
        )
        XCTAssertEqual(meta.repTarget, 1)
    }

    // MARK: 境界値: set_index = 0 は可（>= 0）
    func test_init_withSetIndexZero_succeeds() throws {
        let meta = try SessionMetadata(
            exercise: "back_squat", weightKg: 80, repTarget: 1,
            setIndex: 0, subjectId: "ao",
            startedAt: Date(), endedAt: Date()
        )
        XCTAssertEqual(meta.setIndex, 0)
    }

    // MARK: 異常系: set_index < 0
    func test_init_withNegativeSetIndex_throws() {
        XCTAssertThrowsError(try SessionMetadata(
            exercise: "back_squat", weightKg: 80, repTarget: 1,
            setIndex: -1, subjectId: "ao",
            startedAt: Date(), endedAt: Date()
        )) { error in
            XCTAssertEqual(error as? SessionMetadata.ValidationError, .invalidSetIndex)
        }
    }

    // MARK: 異常系: subject_id 空
    func test_init_withEmptySubjectId_throws() {
        XCTAssertThrowsError(try SessionMetadata(
            exercise: "back_squat", weightKg: 80, repTarget: 1,
            setIndex: 0, subjectId: "",
            startedAt: Date(), endedAt: Date()
        )) { error in
            XCTAssertEqual(error as? SessionMetadata.ValidationError, .emptySubjectId)
        }
    }

    // MARK: session_id 生成: フォーマット確認（例: session_YYYYMMDD_HHMMSS_<exercise>_<weight>kg_set<n>）
    func test_sessionId_format_followsSpecExample() throws {
        // 仕様書 §7 例: session_20260531_162601_back_squat_80kg_set1
        var components = DateComponents()
        components.year = 2026
        components.month = 5
        components.day = 31
        components.hour = 16
        components.minute = 26
        components.second = 1
        components.timeZone = TimeZone(identifier: "UTC")
        let date = Calendar(identifier: .gregorian).date(from: components)!

        let meta = try SessionMetadata(
            exercise: "back_squat", weightKg: 80, repTarget: 10,
            setIndex: 1, subjectId: "ao",
            startedAt: date,
            endedAt: date.addingTimeInterval(60)
        )
        XCTAssertEqual(meta.sessionId(timeZone: TimeZone(identifier: "UTC")!),
                       "session_20260531_162601_back_squat_80kg_set1")
    }

    // MARK: JSON 往復
    func test_jsonRoundTrip_preservesAllFields() throws {
        let original = try SessionMetadata(
            exercise: "back_squat", weightKg: 80, repTarget: 10,
            setIndex: 1, subjectId: "ao",
            startedAt: Date(timeIntervalSince1970: 1_700_000_000),
            endedAt: Date(timeIntervalSince1970: 1_700_000_060)
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(SessionMetadata.self, from: data)
        XCTAssertEqual(decoded, original)
    }
}
