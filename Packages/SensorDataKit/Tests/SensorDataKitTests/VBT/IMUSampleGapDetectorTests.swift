import XCTest
@testable import SensorDataKit

// MARK: - IMUSampleGapDetectorTests
// 仕様書: .docs/VBT_GroundTruth_Tool_Spec.md §9 「IMU途絶」
//   検出条件: `motion.timestamp` の連続サンプル間隔が 0.5 秒以上
//
// Red 観測ゲート: テスト対象 `IMUSampleGapDetector` は本コミット時点で未実装。
final class IMUSampleGapDetectorTests: XCTestCase {

    // MARK: 正常系（境界値・下限）

    func test_observe_firstSample_doesNotReportGap() {
        // Arrange
        var detector = IMUSampleGapDetector(maxIntervalSeconds: 0.5)

        // Act
        let gap = detector.observe(timestamp: 100.0)

        // Assert
        XCTAssertNil(gap)
    }

    func test_observe_intervalUnderThreshold_doesNotReportGap() {
        // Arrange
        var detector = IMUSampleGapDetector(maxIntervalSeconds: 0.5)
        _ = detector.observe(timestamp: 100.0)

        // Act
        let gap = detector.observe(timestamp: 100.4)

        // Assert
        XCTAssertNil(gap)
    }

    // MARK: 境界値（しきい値 0.5s 丁度）

    func test_observe_intervalAtThreshold_reportsGap() {
        // Arrange
        var detector = IMUSampleGapDetector(maxIntervalSeconds: 0.5)
        _ = detector.observe(timestamp: 100.0)

        // Act
        let gap = detector.observe(timestamp: 100.5)

        // Assert
        XCTAssertNotNil(gap)
        XCTAssertEqual(gap?.interval ?? 0, 0.5, accuracy: 1e-9)
    }

    // MARK: 異常系（しきい値超過）

    func test_observe_intervalAboveThreshold_reportsGap() {
        // Arrange
        var detector = IMUSampleGapDetector(maxIntervalSeconds: 0.5)
        _ = detector.observe(timestamp: 100.0)

        // Act
        let gap = detector.observe(timestamp: 100.75)

        // Assert
        XCTAssertEqual(gap?.previousTimestamp ?? 0, 100.0, accuracy: 1e-9)
        XCTAssertEqual(gap?.currentTimestamp ?? 0, 100.75, accuracy: 1e-9)
        XCTAssertEqual(gap?.interval ?? 0, 0.75, accuracy: 1e-9)
    }

    func test_observe_afterGap_continuesMonitoring() {
        // Arrange: ギャップ検出後も観測自体は継続できる（停止判断は呼び出し側）
        var detector = IMUSampleGapDetector(maxIntervalSeconds: 0.5)
        _ = detector.observe(timestamp: 100.0)
        _ = detector.observe(timestamp: 100.75)

        // Act
        let gap = detector.observe(timestamp: 100.80)

        // Assert
        XCTAssertNil(gap)
    }

    // MARK: 不変条件: 最初のサンプルが取れていなければギャップ判定しない
    func test_init_resetsState() {
        // Arrange
        var detector = IMUSampleGapDetector(maxIntervalSeconds: 0.5)
        _ = detector.observe(timestamp: 100.0)
        _ = detector.observe(timestamp: 200.0) // 100s gap → 検出される

        // Act
        detector.reset()
        let gap = detector.observe(timestamp: 300.0)

        // Assert: reset 後の最初の観測ではギャップを検出しない
        XCTAssertNil(gap)
    }
}
