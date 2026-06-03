// M-1: AttitudeReplayLoader Protocol の DI 動作実証テスト。
// `DefaultAttitudeReplayLoader` の合成構成 + mock loader による Protocol 経由のテスト容易性を確認する。
import XCTest
@testable import SensorDataKit

final class AttitudeReplayLoaderTests: XCTestCase {

    // MARK: Mock loader が任意の AttitudeSeries を返す（DI 動作実証）
    func test_mockLoader_returnsInjectedSeries() async throws {
        let identity = AttitudeQuaternion.identity
        let injectedSeries = AttitudeSeries(samples: [
            .init(timestamp: 100, quaternion: identity),
            .init(timestamp: 101, quaternion: identity)
        ])
        let mock = MockAttitudeReplayLoader(result: .success(injectedSeries))

        let result = try await mock.load(folderURL: URL(fileURLWithPath: "/dummy"))

        XCTAssertEqual(result.samples.count, 2)
        XCTAssertEqual(result.duration, 1.0, accuracy: 1e-9)
    }

    // MARK: Mock loader がエラーを throw できる
    func test_mockLoader_throwsInjectedError() async {
        let mock = MockAttitudeReplayLoader(
            result: .failure(AttitudeIMUSourceError.emptyData)
        )
        do {
            _ = try await mock.load(folderURL: URL(fileURLWithPath: "/dummy"))
            XCTFail("Expected throw")
        } catch let error as AttitudeIMUSourceError {
            XCTAssertEqual(error, .emptyData)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    // MARK: DefaultAttitudeReplayLoader は AttitudeIMUSource + AttitudeReconstructor を合成する
    // ファイル不存在で fileNotFound を伝播することを確認（実 I/O 経路の sanity test）
    func test_defaultLoader_propagatesFileNotFound() async {
        let loader = DefaultAttitudeReplayLoader()
        let nonexistent = URL(fileURLWithPath: "/tmp/nonexistent_replay_loader_\(UUID().uuidString)")
        do {
            _ = try await loader.load(folderURL: nonexistent)
            XCTFail("Expected throw")
        } catch let error as AttitudeIMUSourceError {
            if case .fileNotFound = error {
                // OK
            } else {
                XCTFail("Expected .fileNotFound, got \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
}

// MARK: - Mock
private struct MockAttitudeReplayLoader: AttitudeReplayLoader {
    let result: Result<AttitudeSeries, Error>
    func load(folderURL: URL) async throws -> AttitudeSeries {
        try result.get()
    }
}
