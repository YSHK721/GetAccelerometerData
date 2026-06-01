// VBT Ground Truth Tool Phase C: labels.json 出力ペイロード
// 仕様書: .docs/VBT_GroundTruth_Tool_Spec.md §8 / §10
//   - schema_version: "1.0"
//   - sync_markers_video（動画ローカル時刻）
//   - sync_markers_imu（統一時刻軸 = IMU motion.timestamp）
//   - reps（統一時刻軸 / 1始まり / 一意 rep_index）
import XCTest
@testable import SensorDataKit

final class LabelsJSONPayloadTests: XCTestCase {

    // MARK: 正常系: schema_version は "1.0" 固定で書き出される
    func test_encoding_includesSchemaVersion() throws {
        let payload = try LabelsJSONPayload(
            sessionId: "session_20260601_120000_back_squat_80kg_set1",
            syncMarkersVideo: SyncMarker(startTime: 1.0, endTime: 50.0),
            syncMarkersImu: SyncMarker(startTime: 1000.0, endTime: 1049.0),
            reps: [
                RepLabel(repIndex: 1, bottomTime: 1010.0, startTime: nil, endTime: nil)
            ]
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(payload)
        let json = String(data: data, encoding: .utf8) ?? ""

        XCTAssertTrue(json.contains("\"schema_version\":\"1.0\""), "schema_version 必須")
        XCTAssertTrue(json.contains("\"sync_markers_video\""), "sync_markers_video 必須")
        XCTAssertTrue(json.contains("\"sync_markers_imu\""), "sync_markers_imu 必須")
        XCTAssertTrue(json.contains("\"reps\""), "reps 必須")
        XCTAssertTrue(json.contains("\"session_id\""), "session_id 必須")
    }

    // MARK: 境界値: sessionId 空 → 失敗
    func test_init_emptySessionId_throws() {
        XCTAssertThrowsError(try LabelsJSONPayload(
            sessionId: "",
            syncMarkersVideo: SyncMarker(startTime: 0, endTime: 1),
            syncMarkersImu: SyncMarker(startTime: 0, endTime: 1),
            reps: [RepLabel(repIndex: 1, bottomTime: 0.5, startTime: nil, endTime: nil)]
        ))
    }

    // MARK: 境界値: reps 空 → 失敗（仕様書 §10 確定条件 #3）
    func test_init_emptyReps_throws() {
        XCTAssertThrowsError(try LabelsJSONPayload(
            sessionId: "session_x",
            syncMarkersVideo: SyncMarker(startTime: 0, endTime: 1),
            syncMarkersImu: SyncMarker(startTime: 0, endTime: 1),
            reps: []
        )) { error in
            XCTAssertEqual(error as? LabelsJSONPayload.ValidationError, .emptyReps)
        }
    }

    // MARK: 境界値: rep_index 重複 → 失敗
    func test_init_duplicateRepIndex_throws() {
        XCTAssertThrowsError(try LabelsJSONPayload(
            sessionId: "session_x",
            syncMarkersVideo: SyncMarker(startTime: 0, endTime: 1),
            syncMarkersImu: SyncMarker(startTime: 0, endTime: 1),
            reps: [
                RepLabel(repIndex: 1, bottomTime: 0.3, startTime: nil, endTime: nil),
                RepLabel(repIndex: 1, bottomTime: 0.5, startTime: nil, endTime: nil)
            ]
        )) { error in
            XCTAssertEqual(error as? LabelsJSONPayload.ValidationError, .duplicateRepIndex)
        }
    }

    // MARK: 正常系: JSON のキー名が仕様書通り（snake_case）
    func test_encoding_usesSnakeCaseKeys() throws {
        let payload = try LabelsJSONPayload(
            sessionId: "s1",
            syncMarkersVideo: SyncMarker(startTime: 1.23, endTime: 47.88),
            syncMarkersImu: SyncMarker(startTime: 1234.56, endTime: 1281.21),
            reps: [
                RepLabel(repIndex: 1, bottomTime: 1246.90, startTime: 1245.66, endTime: 1248.06)
            ]
        )
        let data = try JSONEncoder().encode(payload)
        let json = String(data: data, encoding: .utf8) ?? ""

        XCTAssertTrue(json.contains("\"rep_index\":1"))
        XCTAssertTrue(json.contains("\"bottom_time\":1246.9"))
        XCTAssertTrue(json.contains("\"start_time\":1245.66"))
        XCTAssertTrue(json.contains("\"end_time\":1248.06"))
    }
}
