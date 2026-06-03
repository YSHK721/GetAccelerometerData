// VBT Phase B テストカバレッジ拡充:
// VBTLabelingSkinShared.missingLabel(_:) の case 網羅検証。
// SwiftUI 依存の imuScrubGesture は対象外（Gesture 戻り値の検証不可）。
import XCTest
import SensorDataKit
@testable import GetAccelerometerData

final class VBTLabelingSkinSharedTests: XCTestCase {

    func test_missingLabel_syncVideoStart() {
        XCTAssertEqual(
            VBTLabelingSkinShared.missingLabel(.syncVideoStart),
            "SYNC START (Video) 未記録"
        )
    }
    func test_missingLabel_syncVideoEnd() {
        XCTAssertEqual(VBTLabelingSkinShared.missingLabel(.syncVideoEnd), "SYNC END (Video) 未記録")
    }
    func test_missingLabel_syncImuStart() {
        XCTAssertEqual(VBTLabelingSkinShared.missingLabel(.syncImuStart), "SYNC START (IMU) 未記録")
    }
    func test_missingLabel_syncImuEnd() {
        XCTAssertEqual(VBTLabelingSkinShared.missingLabel(.syncImuEnd), "SYNC END (IMU) 未記録")
    }
    func test_missingLabel_atLeastOneRep() {
        XCTAssertEqual(
            VBTLabelingSkinShared.missingLabel(.atLeastOneRep),
            "レップが 0 件（BOTTOM を最低1回）"
        )
    }
    func test_missingLabel_bottomTimeMissing() {
        XCTAssertEqual(
            VBTLabelingSkinShared.missingLabel(.bottomTimeMissing(repIndex: 3)),
            "rep #3 の bottom_time 欠落"
        )
    }
    func test_missingLabel_syncVideoOrderInvalid() {
        XCTAssertEqual(
            VBTLabelingSkinShared.missingLabel(.syncVideoOrderInvalid),
            "SYNC (Video) 順序不正（END > START でない）"
        )
    }
    func test_missingLabel_syncImuOrderInvalid() {
        XCTAssertEqual(
            VBTLabelingSkinShared.missingLabel(.syncImuOrderInvalid),
            "SYNC (IMU) 順序不正（END > START でない）"
        )
    }
}
