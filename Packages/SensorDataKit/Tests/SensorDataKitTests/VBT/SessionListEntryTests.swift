// VBT Ground Truth Tool Phase C: セッション一覧エントリ DTO
// 仕様書: .docs/VBT_GroundTruth_Tool_Spec.md §10 セッション一覧画面
//   - VALID 状態のみ表示
//   - セッション名 / 種目 / 重量 / セット番号
import XCTest
@testable import SensorDataKit

final class SessionListEntryTests: XCTestCase {

    // MARK: VALID 状態のみフィルタリング
    func test_filter_keepsValidOnly() throws {
        let valid = try MetaJSONPayload(
            exercise: "back_squat", weightKg: 80, repTarget: 10, setIndex: 1,
            subjectId: "ao", imuStartTimestamp: 100.0, videoStartIso8601: "2026-06-01T12:00:00Z",
            sessionState: .valid
        )
        let pending = try MetaJSONPayload(
            exercise: "deadlift", weightKg: 100, repTarget: 5, setIndex: 1,
            subjectId: "ao", imuStartTimestamp: nil, videoStartIso8601: nil,
            sessionState: .pending
        )
        let entries = SessionListFilter.filter(metas: [
            ("session_a", valid),
            ("session_b", pending),
        ])
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].folderName, "session_a")
        XCTAssertEqual(entries[0].exercise, "back_squat")
        XCTAssertEqual(entries[0].weightKg, 80)
        XCTAssertEqual(entries[0].setIndex, 1)
    }

    // MARK: 空入力
    func test_filter_empty() {
        let entries = SessionListFilter.filter(metas: [])
        XCTAssertTrue(entries.isEmpty)
    }
}
