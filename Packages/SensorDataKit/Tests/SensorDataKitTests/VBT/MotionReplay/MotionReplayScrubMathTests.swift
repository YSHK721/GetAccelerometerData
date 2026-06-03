// VBT Motion Replay Phase B テストカバレッジ拡充:
// `MotionReplayScrubMath` の progress / knobOffsetX / currentTimeFromDragLocation を網羅検証する。
import XCTest
@testable import SensorDataKit
import CoreGraphics

final class MotionReplayScrubMathTests: XCTestCase {

    // MARK: progress
    func test_progress_durationZero_returnsZero() {
        XCTAssertEqual(MotionReplayScrubMath.progress(currentTime: 5, duration: 0), 0.0)
    }
    func test_progress_currentTimeNegative_clampsToZero() {
        XCTAssertEqual(MotionReplayScrubMath.progress(currentTime: -1, duration: 10), 0.0)
    }
    func test_progress_currentTimeBeyondDuration_clampsToOne() {
        XCTAssertEqual(MotionReplayScrubMath.progress(currentTime: 15, duration: 10), 1.0)
    }
    func test_progress_normalRange_returnsRatio() {
        XCTAssertEqual(MotionReplayScrubMath.progress(currentTime: 5, duration: 10), 0.5, accuracy: 1e-9)
    }

    // MARK: knobOffsetX
    func test_knobOffsetX_progressZero_returnsZero() {
        XCTAssertEqual(MotionReplayScrubMath.knobOffsetX(progress: 0, width: 100), 0)
    }
    func test_knobOffsetX_progressOne_clampsToWidthMinusKnobSize() {
        XCTAssertEqual(MotionReplayScrubMath.knobOffsetX(progress: 1, width: 100), 100 - 14)
    }
    func test_knobOffsetX_progressMid_returnsClampedCenter() {
        // raw = 50 - 7 = 43、clamp で 43
        XCTAssertEqual(MotionReplayScrubMath.knobOffsetX(progress: 0.5, width: 100), 43)
    }
    func test_knobOffsetX_widthSmallerThanKnobSize_returnsZero() {
        // raw < 0 → clamp 0
        XCTAssertEqual(MotionReplayScrubMath.knobOffsetX(progress: 0.5, width: 10), 0)
    }

    // MARK: currentTimeFromDragLocation
    func test_currentTimeFromDragLocation_widthZero_returnsZero() {
        XCTAssertEqual(MotionReplayScrubMath.currentTimeFromDragLocation(x: 50, width: 0, duration: 10), 0.0)
    }
    func test_currentTimeFromDragLocation_durationZero_returnsZero() {
        XCTAssertEqual(MotionReplayScrubMath.currentTimeFromDragLocation(x: 50, width: 100, duration: 0), 0.0)
    }
    func test_currentTimeFromDragLocation_negativeX_clampsToZero() {
        XCTAssertEqual(MotionReplayScrubMath.currentTimeFromDragLocation(x: -10, width: 100, duration: 10), 0.0)
    }
    func test_currentTimeFromDragLocation_xBeyondWidth_clampsToDuration() {
        XCTAssertEqual(MotionReplayScrubMath.currentTimeFromDragLocation(x: 200, width: 100, duration: 10), 10.0)
    }
    func test_currentTimeFromDragLocation_normalRange() {
        XCTAssertEqual(
            MotionReplayScrubMath.currentTimeFromDragLocation(x: 50, width: 100, duration: 10),
            5.0, accuracy: 1e-9
        )
    }
}
