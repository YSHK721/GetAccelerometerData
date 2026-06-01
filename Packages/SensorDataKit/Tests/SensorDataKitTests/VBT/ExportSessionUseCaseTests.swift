// VBT Ground Truth Tool Phase D: セッションフォルダ URL を返す UseCase。
// 仕様書: .docs/VBT_GroundTruth_Tool_Spec.md §8 セッション一括エクスポート型
//   - エクスポート可（VALID + labels.json 存在）のみフォルダ URL を返す
//   - 不正セッションは明示エラー
import XCTest
@testable import SensorDataKit

final class ExportSessionUseCaseTests: XCTestCase {

    private final class StubSessionListLoader: SessionListLoaderPort, @unchecked Sendable {
        var items: [(folderName: String, folderURL: URL, meta: MetaJSONPayload)] = []
        func loadAll() throws -> [(folderName: String, folderURL: URL, meta: MetaJSONPayload)] { items }
    }

    private final class StubLabelsChecker: LabelsExistenceCheckerPort, @unchecked Sendable {
        var existsByFolder: [URL: Bool] = [:]
        func labelsExist(in folder: URL) -> Bool { existsByFolder[folder] ?? false }
    }

    private func makeMeta(state: MetaJSONPayload.SessionState) throws -> MetaJSONPayload {
        try MetaJSONPayload(
            exercise: "back_squat", weightKg: 80, repTarget: 10, setIndex: 1,
            subjectId: "ao", imuStartTimestamp: 100.0, videoStartIso8601: "2026-06-01T12:00:00Z",
            sessionState: state
        )
    }

    // MARK: VALID + labels.json 存在 → 該当フォルダ URL を返す
    func test_execute_validSessionWithLabels_returnsFolderURL() throws {
        let folderURL = URL(fileURLWithPath: "/tmp/session_a")
        let loader = StubSessionListLoader()
        loader.items = [(folderName: "session_a", folderURL: folderURL, meta: try makeMeta(state: .valid))]
        let checker = StubLabelsChecker()
        checker.existsByFolder = [folderURL: true]
        let useCase = ExportSessionUseCase(loader: loader, labelsChecker: checker)
        let url = try useCase.execute(sessionId: "session_a")
        XCTAssertEqual(url, folderURL)
    }

    // MARK: セッション未存在 → sessionNotFound
    func test_execute_unknownSession_throwsNotFound() throws {
        let loader = StubSessionListLoader()
        let checker = StubLabelsChecker()
        let useCase = ExportSessionUseCase(loader: loader, labelsChecker: checker)
        XCTAssertThrowsError(try useCase.execute(sessionId: "does_not_exist")) { error in
            XCTAssertEqual(error as? ExportSessionUseCase.ExportError, .sessionNotFound)
        }
    }

    // MARK: PENDING 状態 → sessionNotValid
    func test_execute_pendingSession_throwsNotValid() throws {
        let folderURL = URL(fileURLWithPath: "/tmp/session_b")
        let loader = StubSessionListLoader()
        loader.items = [(folderName: "session_b", folderURL: folderURL, meta: try makeMeta(state: .pending))]
        let checker = StubLabelsChecker()
        checker.existsByFolder = [folderURL: true]
        let useCase = ExportSessionUseCase(loader: loader, labelsChecker: checker)
        XCTAssertThrowsError(try useCase.execute(sessionId: "session_b")) { error in
            XCTAssertEqual(error as? ExportSessionUseCase.ExportError, .sessionNotValid)
        }
    }

    // MARK: VALID だが labels.json 未生成 → labelsNotGenerated
    func test_execute_validButLabelsMissing_throwsLabelsNotGenerated() throws {
        let folderURL = URL(fileURLWithPath: "/tmp/session_c")
        let loader = StubSessionListLoader()
        loader.items = [(folderName: "session_c", folderURL: folderURL, meta: try makeMeta(state: .valid))]
        let checker = StubLabelsChecker()
        checker.existsByFolder = [folderURL: false]
        let useCase = ExportSessionUseCase(loader: loader, labelsChecker: checker)
        XCTAssertThrowsError(try useCase.execute(sessionId: "session_c")) { error in
            XCTAssertEqual(error as? ExportSessionUseCase.ExportError, .labelsNotGenerated)
        }
    }

    // MARK: 複数セッションから ID で正しく解決される
    func test_execute_multipleSessions_resolvesById() throws {
        let urlA = URL(fileURLWithPath: "/tmp/session_a")
        let urlB = URL(fileURLWithPath: "/tmp/session_b")
        let loader = StubSessionListLoader()
        loader.items = [
            (folderName: "session_a", folderURL: urlA, meta: try makeMeta(state: .valid)),
            (folderName: "session_b", folderURL: urlB, meta: try makeMeta(state: .valid)),
        ]
        let checker = StubLabelsChecker()
        checker.existsByFolder = [urlA: true, urlB: true]
        let useCase = ExportSessionUseCase(loader: loader, labelsChecker: checker)
        XCTAssertEqual(try useCase.execute(sessionId: "session_b"), urlB)
    }
}
