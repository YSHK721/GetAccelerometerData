// VBT Ground Truth Tool Phase D: エクスポート可否判定の純ドメインロジック。
// 仕様書: .docs/VBT_GroundTruth_Tool_Spec.md §8 セッション一括エクスポート型
//   - session_state == "VALID" のみ対象
//   - labels.json が存在する（ラベリング完了済み）のみ対象
import XCTest
@testable import SensorDataKit

final class SessionExportabilityTests: XCTestCase {

    private func makeMeta(state: MetaJSONPayload.SessionState) throws -> MetaJSONPayload {
        try MetaJSONPayload(
            exercise: "back_squat",
            weightKg: 80,
            repTarget: 10,
            setIndex: 1,
            subjectId: "ao",
            imuStartTimestamp: 100.0,
            videoStartIso8601: "2026-06-01T12:00:00Z",
            sessionState: state
        )
    }

    // MARK: VALID + labels.json 存在 → exportable
    func test_evaluate_validAndLabelsPresent_isExportable() throws {
        let meta = try makeMeta(state: .valid)
        let result = SessionExportability.evaluate(meta: meta, labelsExists: true)
        XCTAssertTrue(result.isExportable)
        XCTAssertNil(result.reason)
    }

    // MARK: VALID だが labels.json 未生成 → not exportable
    func test_evaluate_validButLabelsMissing_isNotExportable() throws {
        let meta = try makeMeta(state: .valid)
        let result = SessionExportability.evaluate(meta: meta, labelsExists: false)
        XCTAssertFalse(result.isExportable)
        XCTAssertEqual(result.reason, .labelsNotGenerated)
    }

    // MARK: PENDING → not exportable（ラベリング前段でフィルタ済みのはずだが防御的に判定）
    func test_evaluate_pendingState_isNotExportable() throws {
        let meta = try makeMeta(state: .pending)
        let result = SessionExportability.evaluate(meta: meta, labelsExists: true)
        XCTAssertFalse(result.isExportable)
        XCTAssertEqual(result.reason, .sessionNotValid)
    }

    // MARK: PENDING かつ labels.json 未生成 → sessionNotValid を優先
    func test_evaluate_pendingAndLabelsMissing_reasonIsSessionNotValid() throws {
        let meta = try makeMeta(state: .pending)
        let result = SessionExportability.evaluate(meta: meta, labelsExists: false)
        XCTAssertFalse(result.isExportable)
        XCTAssertEqual(result.reason, .sessionNotValid)
    }
}
