// VBT Ground Truth Tool: LabeledSession（Item8 labels.json トップ構造）
// 仕様書: .docs/VBT_GroundTruth_Tool_Spec.md §8
import XCTest
@testable import SensorDataKit

final class LabeledSessionTests: XCTestCase {

    // MARK: 正常系: 構築・JSON 往復
    func test_jsonRoundTrip_preservesShape() throws {
        let original = try LabeledSession(
            sessionId: "session_20260531_162601_back_squat_80kg_set1",
            syncMarkers: SyncMarker(startTime: 1.23, endTime: 47.88),
            reps: [
                try RepLabel(repIndex: 1, bottomTime: 12.34, startTime: 11.10, endTime: 13.50),
                try RepLabel(repIndex: 2, bottomTime: 17.20, startTime: nil, endTime: nil)
            ]
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(LabeledSession.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    // MARK: 異常系: rep_index 重複
    func test_init_withDuplicateRepIndices_throws() {
        XCTAssertThrowsError(try LabeledSession(
            sessionId: "s1",
            syncMarkers: try SyncMarker(startTime: 0, endTime: 10),
            reps: [
                try RepLabel(repIndex: 1, bottomTime: 1, startTime: nil, endTime: nil),
                try RepLabel(repIndex: 1, bottomTime: 2, startTime: nil, endTime: nil)
            ]
        )) { error in
            XCTAssertEqual(error as? LabeledSession.ValidationError, .duplicateRepIndex)
        }
    }

    // MARK: 異常系: session_id 空
    func test_init_withEmptySessionId_throws() {
        XCTAssertThrowsError(try LabeledSession(
            sessionId: "",
            syncMarkers: try SyncMarker(startTime: 0, endTime: 10),
            reps: []
        )) { error in
            XCTAssertEqual(error as? LabeledSession.ValidationError, .emptySessionId)
        }
    }

    // MARK: 仕様書の JSON キー命名に準拠（snake_case）
    func test_jsonEncoding_usesSnakeCaseKeysFromSpec() throws {
        let session = try LabeledSession(
            sessionId: "s1",
            syncMarkers: try SyncMarker(startTime: 1.23, endTime: 47.88),
            reps: [try RepLabel(repIndex: 1, bottomTime: 12.34, startTime: 11.1, endTime: 13.5)]
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(session)
        let json = String(data: data, encoding: .utf8)!
        XCTAssertTrue(json.contains("\"session_id\""), "session_id key missing: \(json)")
        XCTAssertTrue(json.contains("\"sync_markers\""), "sync_markers key missing")
        XCTAssertTrue(json.contains("\"reps\""), "reps key missing")
        XCTAssertTrue(json.contains("\"rep_index\""), "rep_index key missing")
        XCTAssertTrue(json.contains("\"bottom_time\""), "bottom_time key missing")
        XCTAssertTrue(json.contains("\"start_time\""), "start_time key missing")
        XCTAssertTrue(json.contains("\"end_time\""), "end_time key missing")
    }
}
