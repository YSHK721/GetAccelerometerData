// VBT Ground Truth Tool Phase B: meta.json ペイロード（§7 meta.json + §6 PENDING/VALID）
// 仕様書: .docs/VBT_GroundTruth_Tool_Spec.md §6 / §7
import XCTest
@testable import SensorDataKit

final class MetaJSONPayloadTests: XCTestCase {

    // MARK: 正常系: 全 8 フィールドが揃った VALID ペイロード
    func test_init_withAllFields_succeeds() throws {
        let payload = try MetaJSONPayload(
            exercise: "back_squat",
            weightKg: 80,
            repTarget: 10,
            setIndex: 1,
            subjectId: "ao",
            imuStartTimestamp: 1234.5678,
            videoStartIso8601: "2026-06-01T12:34:56.789Z",
            sessionState: .valid
        )
        XCTAssertEqual(payload.exercise, "back_squat")
        XCTAssertEqual(payload.weightKg, 80)
        XCTAssertEqual(payload.repTarget, 10)
        XCTAssertEqual(payload.setIndex, 1)
        XCTAssertEqual(payload.subjectId, "ao")
        XCTAssertEqual(payload.imuStartTimestamp, 1234.5678)
        XCTAssertEqual(payload.videoStartIso8601, "2026-06-01T12:34:56.789Z")
        XCTAssertEqual(payload.sessionState, .valid)
    }

    // MARK: PENDING 状態も生成可能（imu_start_timestamp / video_start_iso8601 が欠落でも OK）
    func test_init_withPendingState_allowsMissingTimestamps() throws {
        let payload = try MetaJSONPayload(
            exercise: "back_squat",
            weightKg: 80,
            repTarget: 10,
            setIndex: 1,
            subjectId: "ao",
            imuStartTimestamp: nil,
            videoStartIso8601: nil,
            sessionState: .pending
        )
        XCTAssertNil(payload.imuStartTimestamp)
        XCTAssertNil(payload.videoStartIso8601)
        XCTAssertEqual(payload.sessionState, .pending)
    }

    // MARK: バリデーション: exercise 空
    func test_init_withEmptyExercise_throws() {
        XCTAssertThrowsError(try MetaJSONPayload(
            exercise: "", weightKg: 80, repTarget: 10, setIndex: 1, subjectId: "ao",
            imuStartTimestamp: nil, videoStartIso8601: nil, sessionState: .pending
        ))
    }

    // MARK: バリデーション: weight_kg = 0 不可
    func test_init_withZeroWeight_throws() {
        XCTAssertThrowsError(try MetaJSONPayload(
            exercise: "back_squat", weightKg: 0, repTarget: 10, setIndex: 1, subjectId: "ao",
            imuStartTimestamp: nil, videoStartIso8601: nil, sessionState: .pending
        ))
    }

    // MARK: バリデーション: rep_target = 0 不可
    func test_init_withZeroRepTarget_throws() {
        XCTAssertThrowsError(try MetaJSONPayload(
            exercise: "back_squat", weightKg: 80, repTarget: 0, setIndex: 1, subjectId: "ao",
            imuStartTimestamp: nil, videoStartIso8601: nil, sessionState: .pending
        ))
    }

    // MARK: 境界値: set_index = 0 は可
    func test_init_withSetIndexZero_succeeds() throws {
        let payload = try MetaJSONPayload(
            exercise: "back_squat", weightKg: 80, repTarget: 1, setIndex: 0, subjectId: "ao",
            imuStartTimestamp: nil, videoStartIso8601: nil, sessionState: .pending
        )
        XCTAssertEqual(payload.setIndex, 0)
    }

    // MARK: バリデーション: set_index 負値
    func test_init_withNegativeSetIndex_throws() {
        XCTAssertThrowsError(try MetaJSONPayload(
            exercise: "back_squat", weightKg: 80, repTarget: 1, setIndex: -1, subjectId: "ao",
            imuStartTimestamp: nil, videoStartIso8601: nil, sessionState: .pending
        ))
    }

    // MARK: バリデーション: subject_id 空
    func test_init_withEmptySubjectId_throws() {
        XCTAssertThrowsError(try MetaJSONPayload(
            exercise: "back_squat", weightKg: 80, repTarget: 1, setIndex: 0, subjectId: "",
            imuStartTimestamp: nil, videoStartIso8601: nil, sessionState: .pending
        ))
    }

    // MARK: JSON エンコード: snake_case キー
    func test_jsonEncode_usesSnakeCaseKeys() throws {
        let payload = try MetaJSONPayload(
            exercise: "back_squat", weightKg: 80, repTarget: 10, setIndex: 1, subjectId: "ao",
            imuStartTimestamp: 1234.5, videoStartIso8601: "2026-06-01T12:00:00.000Z",
            sessionState: .valid
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(payload)
        let json = try XCTUnwrap(String(data: data, encoding: .utf8))
        XCTAssertTrue(json.contains("\"weight_kg\":80"), json)
        XCTAssertTrue(json.contains("\"rep_target\":10"), json)
        XCTAssertTrue(json.contains("\"set_index\":1"), json)
        XCTAssertTrue(json.contains("\"subject_id\":\"ao\""), json)
        XCTAssertTrue(json.contains("\"imu_start_timestamp\":1234.5"), json)
        XCTAssertTrue(json.contains("\"video_start_iso8601\":\"2026-06-01T12:00:00.000Z\""), json)
        XCTAssertTrue(json.contains("\"session_state\":\"VALID\""), json)
    }

    // MARK: JSON 往復
    func test_jsonRoundTrip_preservesAllFields() throws {
        let original = try MetaJSONPayload(
            exercise: "back_squat", weightKg: 80, repTarget: 10, setIndex: 1, subjectId: "ao",
            imuStartTimestamp: 1234.5, videoStartIso8601: "2026-06-01T12:00:00.000Z",
            sessionState: .valid
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(MetaJSONPayload.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    // MARK: session_state 文字列表現
    func test_sessionState_rawValues() {
        XCTAssertEqual(MetaJSONPayload.SessionState.pending.rawValue, "PENDING")
        XCTAssertEqual(MetaJSONPayload.SessionState.valid.rawValue, "VALID")
    }
}
