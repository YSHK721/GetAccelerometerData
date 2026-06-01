// VBT Ground Truth Tool Phase B: iPhone 側 受信 Use Case
// 仕様書: .docs/VBT_GroundTruth_Tool_Spec.md §6 step 5〜13 / §7
//
// 責務（SRP）:
//   - 録画開始要求受信時: メタが入力済なら録画開始 → 成功時 ACK / 失敗時 error 返却
//   - IMU CSV 受信時: セッションフォルダへ配置 → meta.json 書き出し → VALID 遷移 / ACK 返却
//   - 録画停止要求受信時: 録画停止
//   - 欠落時はフォルダ削除（PENDING のまま残さない）
//
// DIP: Video / Storage / Clock を Port 経由で参照
import XCTest
@testable import SensorDataKit

final class VBTReceptionUseCaseTests: XCTestCase {

    // MARK: - fakes

    final class FakeVideoRecorder: VideoRecorderPort, @unchecked Sendable {
        var startResult: Result<VideoStartContext, VideoRecorderError> = .failure(.notReadyForMetaInput)
        var stopResult: VideoStopOutcome = .failure(reason: "not started")
        var didStart = false
        var didStop = false
        func startRecording() async -> Result<VideoStartContext, VideoRecorderError> {
            didStart = true
            return startResult
        }
        func stopRecording() async -> VideoStopOutcome {
            didStop = true
            return stopResult
        }
    }

    final class FakeSessionStore: SessionStorePort, @unchecked Sendable {
        var folderURL: URL?
        var importedIMU: URL?
        var importedVideo: URL?
        var writtenMeta: MetaJSONPayload?
        var didFinalize = false
        var didDelete = false
        var createFolderError: Error?
        var importIMUError: Error?
        var importVideoError: Error?
        var writeMetaError: Error?

        func createFolder(name: String) throws -> URL {
            if let e = createFolderError { throw e }
            let base = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            let dir = base.appendingPathComponent(name)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            folderURL = dir
            return dir
        }
        func importIMUFile(from source: URL, to folder: URL) throws -> URL {
            if let e = importIMUError { throw e }
            let dest = folder.appendingPathComponent("imu.csv")
            importedIMU = dest
            return dest
        }
        func importVideoFile(from source: URL, to folder: URL) throws -> URL {
            if let e = importVideoError { throw e }
            let dest = folder.appendingPathComponent("video.mp4")
            importedVideo = dest
            return dest
        }
        func writeMetaJSON(_ payload: MetaJSONPayload, to folder: URL) throws {
            if let e = writeMetaError { throw e }
            writtenMeta = payload
        }
        func finalize(folder: URL) throws { didFinalize = true }
        func delete(folder: URL) {
            didDelete = true
        }
    }

    final class FakeClock: ClockPort, @unchecked Sendable {
        var now: Date = Date(timeIntervalSince1970: 1_780_000_000)
        func currentDate() -> Date { now }
    }

    // MARK: - メタ入力 → 待機

    func test_setPendingMeta_storesInputAndSwitchesToWaiting() {
        let useCase = makeUseCase()
        let input = makeInput()
        useCase.setPendingMetadata(input)
        XCTAssertEqual(useCase.state, .waitingForStart)
        XCTAssertEqual(useCase.pendingInput?.exercise, "back_squat")
    }

    // MARK: - 録画開始: メタ未入力なら error 返却

    func test_handleStartRequest_withoutPendingMeta_returnsError() async {
        let video = FakeVideoRecorder()
        let useCase = makeUseCase(video: video)
        let ack = await useCase.handleStartRecordingRequest()
        switch ack {
        case .error(let reason):
            XCTAssertTrue(reason.contains("meta"))
        case .acknowledged:
            XCTFail("should error without pending meta")
        }
        XCTAssertFalse(video.didStart)
    }

    // MARK: - 録画開始: 60fps 失敗時 error 返却（仕様 §4 同期精度最優先・自動降格しない）

    func test_handleStartRequest_when60fpsUnsupported_returnsError() async {
        let video = FakeVideoRecorder()
        video.startResult = .failure(.unsupported60fps)
        let useCase = makeUseCase(video: video)
        useCase.setPendingMetadata(makeInput())
        let ack = await useCase.handleStartRecordingRequest()
        switch ack {
        case .error(let reason):
            XCTAssertTrue(reason.contains("60fps"), "got: \(reason)")
        case .acknowledged:
            XCTFail("should error when 60fps unsupported")
        }
        XCTAssertEqual(useCase.state, .failed)
    }

    // MARK: - 録画開始: 成功時 PENDING フォルダ作成 + ACK 返却

    func test_handleStartRequest_whenSuccess_createsPendingFolderAndReturnsAck() async {
        let video = FakeVideoRecorder()
        video.startResult = .success(VideoStartContext(
            videoStartIso8601: "2026-06-01T12:34:56.000Z"
        ))
        let store = FakeSessionStore()
        let clock = FakeClock()
        let useCase = makeUseCase(video: video, store: store, clock: clock)
        useCase.setPendingMetadata(makeInput())

        let ack = await useCase.handleStartRecordingRequest()
        XCTAssertEqual(ack, .acknowledged)
        XCTAssertTrue(video.didStart)
        XCTAssertNotNil(store.folderURL)
        XCTAssertEqual(useCase.state, .recording)
        XCTAssertNotNil(useCase.activeFolder)
    }

    // MARK: - IMU CSV 受信: 録画停止 → meta.json 書き出し → VALID

    func test_handleIMUFileReceived_whenAllPresent_finalizesValid() async throws {
        let video = FakeVideoRecorder()
        video.startResult = .success(VideoStartContext(
            videoStartIso8601: "2026-06-01T12:34:56.000Z"
        ))
        // 動画ファイル URL（実体不要、Fake で参照されない）
        let tmpVideo = FileManager.default.temporaryDirectory.appendingPathComponent("vbt-test-\(UUID()).mp4")
        FileManager.default.createFile(atPath: tmpVideo.path, contents: Data())
        defer { try? FileManager.default.removeItem(at: tmpVideo) }
        video.stopResult = .success(videoURL: tmpVideo)

        let store = FakeSessionStore()
        let useCase = makeUseCase(video: video, store: store)
        useCase.setPendingMetadata(makeInput())
        _ = await useCase.handleStartRecordingRequest()

        // 受信した IMU CSV の擬似 source URL
        let tmpIMU = FileManager.default.temporaryDirectory.appendingPathComponent("vbt-test-\(UUID()).csv")
        FileManager.default.createFile(atPath: tmpIMU.path, contents: Data("x".utf8))
        defer { try? FileManager.default.removeItem(at: tmpIMU) }

        let result = await useCase.handleIMUFileReceived(source: tmpIMU, imuStartTimestamp: 12345.6789)
        XCTAssertEqual(result, .acknowledged)
        XCTAssertEqual(useCase.state, .completed)
        XCTAssertTrue(video.didStop)
        XCTAssertNotNil(store.importedIMU)
        XCTAssertNotNil(store.importedVideo)
        let meta = try XCTUnwrap(store.writtenMeta)
        XCTAssertEqual(meta.sessionState, .valid)
        XCTAssertEqual(meta.imuStartTimestamp, 12345.6789)
        XCTAssertEqual(meta.videoStartIso8601, "2026-06-01T12:34:56.000Z")
    }

    // MARK: - IMU CSV 受信: 動画失敗 → フォルダ削除 + PENDING 残さず

    func test_handleIMUFileReceived_whenVideoStopFails_deletesFolderAndReturnsError() async {
        let video = FakeVideoRecorder()
        video.startResult = .success(VideoStartContext(
            videoStartIso8601: "2026-06-01T12:34:56.000Z"
        ))
        video.stopResult = .failure(reason: "av error")

        let store = FakeSessionStore()
        let useCase = makeUseCase(video: video, store: store)
        useCase.setPendingMetadata(makeInput())
        _ = await useCase.handleStartRecordingRequest()

        let tmpIMU = FileManager.default.temporaryDirectory.appendingPathComponent("vbt-test-\(UUID()).csv")
        FileManager.default.createFile(atPath: tmpIMU.path, contents: Data("x".utf8))
        defer { try? FileManager.default.removeItem(at: tmpIMU) }

        let result = await useCase.handleIMUFileReceived(source: tmpIMU, imuStartTimestamp: 100.0)
        switch result {
        case .error: break
        case .acknowledged: XCTFail("should error when video stop fails")
        }
        XCTAssertTrue(store.didDelete)
        XCTAssertNil(store.writtenMeta)
        XCTAssertEqual(useCase.state, .failed)
    }

    // MARK: - helpers

    private func makeInput() -> VBTSessionInput {
        // バリデーション: 非空 / > 0 / >= 1 / >= 0
        try! VBTSessionInput(
            exercise: "back_squat",
            weightKg: 80,
            repTarget: 10,
            setIndex: 1,
            subjectId: "ao"
        )
    }

    private func makeUseCase(
        video: VideoRecorderPort = FakeVideoRecorder(),
        store: SessionStorePort = FakeSessionStore(),
        clock: ClockPort = FakeClock()
    ) -> VBTReceptionUseCase {
        return VBTReceptionUseCase(video: video, store: store, clock: clock)
    }
}

// MARK: - VBTSessionInput tests

final class VBTSessionInputTests: XCTestCase {
    func test_init_withValidFields_succeeds() throws {
        let input = try VBTSessionInput(
            exercise: "back_squat", weightKg: 80, repTarget: 10, setIndex: 1, subjectId: "ao"
        )
        XCTAssertEqual(input.exercise, "back_squat")
    }

    func test_init_emptyExercise_throws() {
        XCTAssertThrowsError(try VBTSessionInput(
            exercise: "", weightKg: 80, repTarget: 10, setIndex: 1, subjectId: "ao"
        ))
    }

    func test_init_zeroWeight_throws() {
        XCTAssertThrowsError(try VBTSessionInput(
            exercise: "back_squat", weightKg: 0, repTarget: 10, setIndex: 1, subjectId: "ao"
        ))
    }

    func test_init_repTargetZero_throws() {
        XCTAssertThrowsError(try VBTSessionInput(
            exercise: "back_squat", weightKg: 80, repTarget: 0, setIndex: 1, subjectId: "ao"
        ))
    }

    func test_init_setIndexZero_succeeds() throws {
        let input = try VBTSessionInput(
            exercise: "back_squat", weightKg: 80, repTarget: 1, setIndex: 0, subjectId: "ao"
        )
        XCTAssertEqual(input.setIndex, 0)
    }

    func test_init_setIndexNegative_throws() {
        XCTAssertThrowsError(try VBTSessionInput(
            exercise: "back_squat", weightKg: 80, repTarget: 1, setIndex: -1, subjectId: "ao"
        ))
    }

    func test_init_emptySubjectId_throws() {
        XCTAssertThrowsError(try VBTSessionInput(
            exercise: "back_squat", weightKg: 80, repTarget: 1, setIndex: 0, subjectId: ""
        ))
    }
}
