// VBT Ground Truth Tool Phase C: ラベリング UI を統合する UseCase 群
// 仕様書: .docs/VBT_GroundTruth_Tool_Spec.md §10
//   - LoadSessionListUseCase: VALID セッション一覧取得
//   - LoadIMUWaveformUseCase: imu.csv 波形ロード
//   - SaveLabelsUseCase:      labels.json アトミック書き込み
import XCTest
@testable import SensorDataKit

// MARK: - Test doubles

private final class FakeSessionListLoader: SessionListLoaderPort, @unchecked Sendable {
    var stub: [(folderName: String, folderURL: URL, meta: MetaJSONPayload)] = []
    var error: Error?
    func loadAll() throws -> [(folderName: String, folderURL: URL, meta: MetaJSONPayload)] {
        if let e = error { throw e }
        return stub
    }
}

private final class FakeIMUWaveformLoader: IMUWaveformLoaderPort, @unchecked Sendable {
    var stub: [IMUWaveformSample] = []
    var error: Error?
    func load(fromFolder folder: URL) throws -> [IMUWaveformSample] {
        if let e = error { throw e }
        return stub
    }
}

private final class FakeLabelsStore: LabelsStorePort, @unchecked Sendable {
    private(set) var lastPayload: LabelsJSONPayload?
    private(set) var lastFolder: URL?
    var error: Error?
    func writeLabelsJSON(_ payload: LabelsJSONPayload, to folder: URL) throws {
        if let e = error { throw e }
        self.lastPayload = payload
        self.lastFolder = folder
    }
}

// MARK: - LoadSessionListUseCase

final class LoadSessionListUseCaseTests: XCTestCase {

    func test_execute_returnsOnlyValidSessions() throws {
        let loader = FakeSessionListLoader()
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
        loader.stub = [
            (folderName: "session_a", folderURL: URL(fileURLWithPath: "/tmp/a"), meta: valid),
            (folderName: "session_b", folderURL: URL(fileURLWithPath: "/tmp/b"), meta: pending),
        ]
        let useCase = LoadSessionListUseCase(loader: loader)
        let entries = try useCase.execute()
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].entry.folderName, "session_a")
        XCTAssertEqual(entries[0].folderURL.path, "/tmp/a")
    }
}

// MARK: - LoadIMUWaveformUseCase

final class LoadIMUWaveformUseCaseTests: XCTestCase {

    func test_execute_delegatesToPort() throws {
        let loader = FakeIMUWaveformLoader()
        loader.stub = [
            IMUWaveformSample(timestamp: 1.0, accelMagnitude: 1.5),
            IMUWaveformSample(timestamp: 1.01, accelMagnitude: 2.5),
        ]
        let useCase = LoadIMUWaveformUseCase(loader: loader)
        let samples = try useCase.execute(folderURL: URL(fileURLWithPath: "/tmp/a"))
        XCTAssertEqual(samples.count, 2)
        XCTAssertEqual(samples[0].accelMagnitude, 1.5)
    }
}

// MARK: - SaveLabelsUseCase

final class SaveLabelsUseCaseTests: XCTestCase {

    func test_execute_buildsPayloadAndDelegatesToStore() throws {
        let store = FakeLabelsStore()
        var state = LabelingState(sessionId: "s1")
        state.recordSyncStartVideo(at: 0.0)
        state.recordSyncEndVideo(at: 10.0)
        state.recordSyncStartImu(at: 100.0)
        state.recordSyncEndImu(at: 120.0)
        state.recordBottom(atVideoTime: 5.0)

        let useCase = SaveLabelsUseCase(store: store)
        let folder = URL(fileURLWithPath: "/tmp/a")
        try useCase.execute(state: state, folder: folder)

        XCTAssertEqual(store.lastFolder?.path, "/tmp/a")
        XCTAssertEqual(store.lastPayload?.sessionId, "s1")
        XCTAssertEqual(store.lastPayload?.reps.count, 1)
        XCTAssertEqual(store.lastPayload?.reps[0].bottomTime ?? .nan, 110.0, accuracy: 1e-9)
    }

    func test_execute_throwsWhenRequirementsNotMet() {
        let store = FakeLabelsStore()
        let state = LabelingState(sessionId: "s1")
        let useCase = SaveLabelsUseCase(store: store)
        XCTAssertThrowsError(try useCase.execute(state: state, folder: URL(fileURLWithPath: "/tmp/a")))
        XCTAssertNil(store.lastPayload)
    }
}
