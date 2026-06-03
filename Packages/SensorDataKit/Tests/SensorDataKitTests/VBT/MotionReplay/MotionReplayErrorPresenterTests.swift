// VBT Motion Replay Phase B テストカバレッジ拡充:
// `MotionReplayErrorPresenter.message(for:)` の case 網羅テスト。
// 内部設計書 §9.2 のエラー → 日本語文言マッピングが期待通りであることを検証する。
import XCTest
@testable import SensorDataKit

final class MotionReplayErrorPresenterTests: XCTestCase {

    func test_fileNotFound_returnsPathSuffix() {
        let msg = MotionReplayErrorPresenter.message(
            for: AttitudeIMUSourceError.fileNotFound(path: "/tmp/x/imu.csv")
        )
        XCTAssertTrue(msg.contains("/tmp/x/imu.csv"))
        XCTAssertTrue(msg.contains("imu.csv が見つかりません"))
    }

    func test_missingHeader_returnsExpectedMessage() {
        let msg = MotionReplayErrorPresenter.message(for: AttitudeIMUSourceError.missingHeader)
        XCTAssertEqual(msg, "imu.csv が空です（ヘッダなし）")
    }

    func test_missingRequiredColumn_includesColumnName() {
        let msg = MotionReplayErrorPresenter.message(
            for: AttitudeIMUSourceError.missingRequiredColumn(name: "gyro_x")
        )
        XCTAssertEqual(msg, "必須列が欠落: gyro_x")
    }

    func test_malformedRow_includesLineNumber() {
        let msg = MotionReplayErrorPresenter.message(
            for: AttitudeIMUSourceError.malformedRow(line: 42)
        )
        XCTAssertEqual(msg, "42 行目のパース失敗")
    }

    func test_timestampNotMonotonic_includesLineNumber() {
        let msg = MotionReplayErrorPresenter.message(
            for: AttitudeIMUSourceError.timestampNotMonotonic(line: 7)
        )
        XCTAssertEqual(msg, "7 行目: timestamp が前行より小さい")
    }

    func test_emptyData_returnsExpectedMessage() {
        let msg = MotionReplayErrorPresenter.message(for: AttitudeIMUSourceError.emptyData)
        XCTAssertEqual(msg, "imu.csv にデータ行がありません")
    }

    func test_insufficientSamples_returnsExpectedMessage() {
        let msg = MotionReplayErrorPresenter.message(
            for: AttitudeReconstructorError.insufficientSamples
        )
        XCTAssertEqual(msg, "サンプル不足")
    }

    func test_unknownError_returnsFallbackMessage() {
        struct UnknownError: Error {}
        let msg = MotionReplayErrorPresenter.message(for: UnknownError())
        XCTAssertTrue(msg.contains("読み込みエラー"))
    }
}
