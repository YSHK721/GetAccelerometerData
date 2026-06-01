import XCTest
@testable import SensorDataKit

// MARK: - VBTPrerequisiteValidatorTests
// 仕様書 §3 / §6 step 3 / §9 「前提未充足」「ストレージ不足」
final class VBTPrerequisiteValidatorTests: XCTestCase {

    private struct StubProbe: VBTPrerequisiteProbe {
        var isWatchConnectivityReachable: Bool
        var isDeviceMotionAvailable: Bool
        var freeStorageBytes: Int64
    }

    func test_validate_allSatisfied_returnsEmpty() {
        let sut = VBTPrerequisiteValidator()
        let probe = StubProbe(
            isWatchConnectivityReachable: true,
            isDeviceMotionAvailable: true,
            freeStorageBytes: VBTPrerequisiteValidator.minimumFreeStorageBytes + 1
        )
        XCTAssertEqual(sut.validate(probe: probe), [])
    }

    func test_validate_unreachable_listsReachability() {
        let sut = VBTPrerequisiteValidator()
        let probe = StubProbe(
            isWatchConnectivityReachable: false,
            isDeviceMotionAvailable: true,
            freeStorageBytes: 1_000_000_000
        )
        XCTAssertEqual(sut.validate(probe: probe), ["iPhone接続"])
    }

    func test_validate_imuUnavailable_listsIMU() {
        let sut = VBTPrerequisiteValidator()
        let probe = StubProbe(
            isWatchConnectivityReachable: true,
            isDeviceMotionAvailable: false,
            freeStorageBytes: 1_000_000_000
        )
        XCTAssertEqual(sut.validate(probe: probe), ["IMU"])
    }

    func test_validate_storageBelow500MB_listsStorage() {
        let sut = VBTPrerequisiteValidator()
        let probe = StubProbe(
            isWatchConnectivityReachable: true,
            isDeviceMotionAvailable: true,
            freeStorageBytes: VBTPrerequisiteValidator.minimumFreeStorageBytes - 1
        )
        XCTAssertEqual(sut.validate(probe: probe), ["ストレージ容量"])
    }

    func test_validate_storageAt500MB_isAccepted() {
        // 境界値: 500MB ちょうどは充足扱い（仕様書 §9 「500MB未満」）
        let sut = VBTPrerequisiteValidator()
        let probe = StubProbe(
            isWatchConnectivityReachable: true,
            isDeviceMotionAvailable: true,
            freeStorageBytes: VBTPrerequisiteValidator.minimumFreeStorageBytes
        )
        XCTAssertEqual(sut.validate(probe: probe), [])
    }

    func test_validate_multipleMissing_listsAllInOrder() {
        let sut = VBTPrerequisiteValidator()
        let probe = StubProbe(
            isWatchConnectivityReachable: false,
            isDeviceMotionAvailable: false,
            freeStorageBytes: 0
        )
        XCTAssertEqual(sut.validate(probe: probe), ["iPhone接続", "IMU", "ストレージ容量"])
    }
}
