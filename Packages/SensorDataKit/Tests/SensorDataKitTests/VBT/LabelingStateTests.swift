// VBT Ground Truth Tool Phase C: ラベリング UI 状態機械
// 仕様書: .docs/VBT_GroundTruth_Tool_Spec.md §10
//   - BOTTOM: 新レップ追加（rep_index 自動採番）
//   - START / END: 最大 rep_index を持つレップに上書き
//   - SYNC START/END (Video): sync_markers_video を現在動画時刻で上書き
//   - SYNC START/END (IMU): sync_markers_imu を IMU 波形カーソル位置（統一時刻軸）で上書き
//   - レップ削除: rep_index を 1 始まりで再採番
//   - 確定条件: video/imu 両マーカー + reps>=1 + 全 rep に bottom_time
import XCTest
@testable import SensorDataKit

final class LabelingStateTests: XCTestCase {

    // MARK: BOTTOM: 新レップ追加・自動採番
    func test_recordBottom_addsNewRepWithAutoIndex() {
        var state = LabelingState(sessionId: "s1")
        state.recordBottom(atVideoTime: 1.5)
        state.recordBottom(atVideoTime: 4.5)

        XCTAssertEqual(state.repsDraft.count, 2)
        XCTAssertEqual(state.repsDraft[0].repIndex, 1)
        XCTAssertEqual(state.repsDraft[0].bottomTimeVideo, 1.5)
        XCTAssertEqual(state.repsDraft[1].repIndex, 2)
        XCTAssertEqual(state.repsDraft[1].bottomTimeVideo, 4.5)
    }

    // MARK: START: 最大 rep_index を持つレップに上書き
    func test_recordStart_overwritesMaxRepIndex() {
        var state = LabelingState(sessionId: "s1")
        state.recordBottom(atVideoTime: 1.5)
        state.recordBottom(atVideoTime: 4.5)

        state.recordStart(atVideoTime: 4.0)

        XCTAssertNil(state.repsDraft[0].startTimeVideo)
        XCTAssertEqual(state.repsDraft[1].startTimeVideo, 4.0)
    }

    // MARK: END: 最大 rep_index を持つレップに上書き
    func test_recordEnd_overwritesMaxRepIndex() {
        var state = LabelingState(sessionId: "s1")
        state.recordBottom(atVideoTime: 1.5)
        state.recordBottom(atVideoTime: 4.5)

        state.recordEnd(atVideoTime: 5.0)

        XCTAssertNil(state.repsDraft[0].endTimeVideo)
        XCTAssertEqual(state.repsDraft[1].endTimeVideo, 5.0)
    }

    // MARK: 削除: rep_index を 1 始まりで再採番
    func test_deleteRep_reindexesFromOne() {
        var state = LabelingState(sessionId: "s1")
        state.recordBottom(atVideoTime: 1.0)
        state.recordBottom(atVideoTime: 2.0)
        state.recordBottom(atVideoTime: 3.0)

        state.deleteRep(at: 1) // index 1 (rep_index=2) を削除

        XCTAssertEqual(state.repsDraft.count, 2)
        XCTAssertEqual(state.repsDraft[0].repIndex, 1)
        XCTAssertEqual(state.repsDraft[0].bottomTimeVideo, 1.0)
        XCTAssertEqual(state.repsDraft[1].repIndex, 2)
        XCTAssertEqual(state.repsDraft[1].bottomTimeVideo, 3.0)
    }

    // MARK: SYNC マーカー: video / imu それぞれ独立上書き
    func test_recordSyncMarkers_overwritesIndependently() {
        var state = LabelingState(sessionId: "s1")
        state.recordSyncStartVideo(at: 1.0)
        state.recordSyncEndVideo(at: 50.0)
        state.recordSyncStartImu(at: 1000.0)
        state.recordSyncEndImu(at: 1049.0)

        XCTAssertEqual(state.syncMarkerVideoStart, 1.0)
        XCTAssertEqual(state.syncMarkerVideoEnd, 50.0)
        XCTAssertEqual(state.syncMarkerImuStart, 1000.0)
        XCTAssertEqual(state.syncMarkerImuEnd, 1049.0)

        // 上書き確認
        state.recordSyncStartVideo(at: 2.0)
        XCTAssertEqual(state.syncMarkerVideoStart, 2.0)
    }

    // MARK: 確定条件: すべて満たすとき canSave=true
    func test_canSave_allRequirementsMet() {
        var state = LabelingState(sessionId: "s1")
        state.recordSyncStartVideo(at: 1.0)
        state.recordSyncEndVideo(at: 50.0)
        state.recordSyncStartImu(at: 1000.0)
        state.recordSyncEndImu(at: 1049.0)
        state.recordBottom(atVideoTime: 10.0)

        XCTAssertTrue(state.canSave)
        XCTAssertTrue(state.missingRequirements.isEmpty)
    }

    // MARK: 確定条件: マーカー欠落 → canSave=false + 欠落要素列挙
    func test_canSave_missingMarkers_listsRequirements() {
        var state = LabelingState(sessionId: "s1")
        state.recordBottom(atVideoTime: 10.0)

        XCTAssertFalse(state.canSave)
        XCTAssertTrue(state.missingRequirements.contains(.syncVideoStart))
        XCTAssertTrue(state.missingRequirements.contains(.syncVideoEnd))
        XCTAssertTrue(state.missingRequirements.contains(.syncImuStart))
        XCTAssertTrue(state.missingRequirements.contains(.syncImuEnd))
    }

    // MARK: 確定条件: reps 空 → canSave=false
    func test_canSave_noReps() {
        var state = LabelingState(sessionId: "s1")
        state.recordSyncStartVideo(at: 1.0)
        state.recordSyncEndVideo(at: 50.0)
        state.recordSyncStartImu(at: 1000.0)
        state.recordSyncEndImu(at: 1049.0)

        XCTAssertFalse(state.canSave)
        XCTAssertTrue(state.missingRequirements.contains(.atLeastOneRep))
    }

    // MARK: SAVE 変換: rep の動画時刻 → 統一時刻軸 / sync_markers はそのまま
    func test_buildPayload_convertsRepTimesToUnified() throws {
        var state = LabelingState(sessionId: "s1")
        state.recordSyncStartVideo(at: 0.0)
        state.recordSyncEndVideo(at: 10.0)
        state.recordSyncStartImu(at: 100.0)
        state.recordSyncEndImu(at: 120.0)
        // 傾き 2 / 切片 100
        state.recordBottom(atVideoTime: 5.0) // → 110.0
        state.recordStart(atVideoTime: 4.0)  // → 108.0
        state.recordEnd(atVideoTime: 6.0)    // → 112.0

        let payload = try state.buildPayload()

        XCTAssertEqual(payload.sessionId, "s1")
        XCTAssertEqual(payload.schemaVersion, "1.0")
        XCTAssertEqual(payload.syncMarkersVideo.startTime, 0.0)
        XCTAssertEqual(payload.syncMarkersVideo.endTime, 10.0)
        XCTAssertEqual(payload.syncMarkersImu.startTime, 100.0)
        XCTAssertEqual(payload.syncMarkersImu.endTime, 120.0)
        XCTAssertEqual(payload.reps.count, 1)
        XCTAssertEqual(payload.reps[0].repIndex, 1)
        XCTAssertEqual(payload.reps[0].bottomTime, 110.0, accuracy: 1e-9)
        XCTAssertEqual(payload.reps[0].startTime ?? .nan, 108.0, accuracy: 1e-9)
        XCTAssertEqual(payload.reps[0].endTime ?? .nan, 112.0, accuracy: 1e-9)
    }

    // MARK: SAVE: 確定条件未満で buildPayload → throw
    func test_buildPayload_throwsWhenIncomplete() {
        let state = LabelingState(sessionId: "s1")
        XCTAssertThrowsError(try state.buildPayload())
    }

    // MARK: ISSUE-027: SYNC (Video) end <= start → canSave=false + 順序不正を列挙
    func test_canSave_videoSyncOrderInvalid_isBlocked() {
        var state = LabelingState(sessionId: "s1")
        state.recordSyncStartVideo(at: 50.0)
        state.recordSyncEndVideo(at: 50.0) // 同値（degenerateVideoSpan）
        state.recordSyncStartImu(at: 1000.0)
        state.recordSyncEndImu(at: 1049.0)
        state.recordBottom(atVideoTime: 10.0)

        XCTAssertFalse(state.canSave)
        XCTAssertTrue(state.missingRequirements.contains(.syncVideoOrderInvalid))
    }

    // MARK: ISSUE-027: SYNC (IMU) end < start → canSave=false + 順序不正を列挙
    func test_canSave_imuSyncOrderInvalid_isBlocked() {
        var state = LabelingState(sessionId: "s1")
        state.recordSyncStartVideo(at: 1.0)
        state.recordSyncEndVideo(at: 50.0)
        state.recordSyncStartImu(at: 1050.0)
        state.recordSyncEndImu(at: 1000.0) // 逆転
        state.recordBottom(atVideoTime: 10.0)

        XCTAssertFalse(state.canSave)
        XCTAssertTrue(state.missingRequirements.contains(.syncImuOrderInvalid))
    }

    // MARK: ISSUE-027: SYNC 未記録時は順序不正を二重表示しない
    func test_missingRequirements_doesNotEmitOrderInvalidWhenSyncMissing() {
        let state = LabelingState(sessionId: "s1")
        XCTAssertFalse(state.missingRequirements.contains(.syncVideoOrderInvalid))
        XCTAssertFalse(state.missingRequirements.contains(.syncImuOrderInvalid))
    }

    // MARK: ISSUE-027: BuildError.requirementsNotMet が人間に読める localizedDescription を返す
    func test_buildError_localizedDescription_isHumanReadable() {
        let err = LabelingState.BuildError.requirementsNotMet([.syncVideoOrderInvalid])
        let desc = err.errorDescription ?? ""
        XCTAssertTrue(desc.contains("SYNC (Video) 順序不正"), "got: \(desc)")
    }

    // MARK: ISSUE-027: BuildError.converterFailed が人間に読める localizedDescription を返す
    func test_buildError_converterFailed_localizedDescription() {
        let err = LabelingState.BuildError.converterFailed
        let desc = err.errorDescription ?? ""
        XCTAssertTrue(desc.contains("SYNC マーカー"), "got: \(desc)")
    }
}
