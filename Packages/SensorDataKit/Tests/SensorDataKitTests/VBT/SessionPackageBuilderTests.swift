// VBT Ground Truth Tool: SessionPackageBuilder（Item6 アトミック型 / Item9 即時破棄）
// 仕様書: .docs/VBT_GroundTruth_Tool_Spec.md §6 / §9
//   「IF (IMU記録あり AND 動画記録あり) THEN セッションを有効として保存
//    ELSE セッション全体を無効とし両デバイスの記録を破棄」
import XCTest
@testable import SensorDataKit

final class SessionPackageBuilderTests: XCTestCase {

    // MARK: 正常系: 両方存在で valid
    func test_evaluate_withBothRecordings_returnsValid() {
        let result = SessionPackageBuilder.evaluate(
            hasIMURecording: true,
            hasVideoRecording: true
        )
        XCTAssertEqual(result, .valid)
    }

    // MARK: 異常系: IMU のみ → invalid（動画欠落）
    func test_evaluate_withIMUOnly_returnsInvalidMissingVideo() {
        let result = SessionPackageBuilder.evaluate(
            hasIMURecording: true,
            hasVideoRecording: false
        )
        XCTAssertEqual(result, .invalid(reason: .missingVideo))
    }

    // MARK: 異常系: 動画のみ → invalid（IMU欠落）
    func test_evaluate_withVideoOnly_returnsInvalidMissingIMU() {
        let result = SessionPackageBuilder.evaluate(
            hasIMURecording: false,
            hasVideoRecording: true
        )
        XCTAssertEqual(result, .invalid(reason: .missingIMU))
    }

    // MARK: 異常系: 両方欠落 → invalid
    func test_evaluate_withNeither_returnsInvalidMissingBoth() {
        let result = SessionPackageBuilder.evaluate(
            hasIMURecording: false,
            hasVideoRecording: false
        )
        XCTAssertEqual(result, .invalid(reason: .missingBoth))
    }
}
