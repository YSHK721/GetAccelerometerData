import XCTest
@testable import SensorDataKit

// VBT Motion Replay PoC Phase 3: MotionReplayState の純粋ロジック検証。
// 内部設計書: .docs/07_vbt_motion_replay_internal_design.md §9
//
// ガード不要（Domain 層テストは macOS でも走る）。
final class MotionReplayStateTests: XCTestCase {

    // MARK: - Helpers

    /// duration が `duration` 秒（startTime = 0, endTime = duration）の
    /// 2 サンプルシリーズを作る（identity → identity）。回転テスト用は別途構築。
    private func makeIdentitySeries(duration: TimeInterval) -> AttitudeSeries {
        AttitudeSeries(samples: [
            AttitudeSeries.Sample(timestamp: 0, quaternion: .identity),
            AttitudeSeries.Sample(timestamp: duration, quaternion: .identity)
        ])
    }

    /// identity (t=0) → 90° yaw (t=1.0) の 2 サンプルシリーズ。
    /// 90° yaw quaternion: (cos(45°), 0, 0, sin(45°))
    private func makeYaw90Series() -> AttitudeSeries {
        let half = Double.pi / 4.0   // 45° = π/4 rad
        let q90 = AttitudeQuaternion(w: cos(half), x: 0, y: 0, z: sin(half))
        return AttitudeSeries(samples: [
            AttitudeSeries.Sample(timestamp: 0, quaternion: .identity),
            AttitudeSeries.Sample(timestamp: 1.0, quaternion: q90)
        ])
    }

    // MARK: - 1. 初期状態

    func test_initialState_hasEmptySeriesAndIdentityOrientation() {
        let state = MotionReplayState()

        XCTAssertTrue(state.series.isEmpty)
        XCTAssertEqual(state.currentTime, 0)
        XCTAssertFalse(state.isPlaying)
        XCTAssertEqual(state.currentOrientation, .identity)
    }

    // MARK: - 2. advance 前進

    func test_advance_movesCurrentTimeForward() {
        var state = MotionReplayState(
            series: makeIdentitySeries(duration: 10.0),
            currentTime: 0.5,
            isPlaying: true
        )

        state.advance(by: 0.1)

        XCTAssertEqual(state.currentTime, 0.6)
        XCTAssertTrue(state.isPlaying)
    }

    // MARK: - 3. advance 終端クランプ + 自動停止

    func test_advance_clampsAtDurationAndStops() {
        var state = MotionReplayState(
            series: makeIdentitySeries(duration: 1.0),
            currentTime: 0.9,
            isPlaying: true
        )

        state.advance(by: 0.2)

        XCTAssertEqual(state.currentTime, 1.0)
        XCTAssertFalse(state.isPlaying)
    }

    // MARK: - 4. advance 負値・ゼロ無視

    func test_advance_ignoresNonPositiveDelta() {
        let original = MotionReplayState(
            series: makeIdentitySeries(duration: 10.0),
            currentTime: 0.5,
            isPlaying: true
        )

        var s1 = original
        s1.advance(by: 0)
        XCTAssertEqual(s1, original)

        var s2 = original
        s2.advance(by: -0.1)
        XCTAssertEqual(s2, original)
    }

    // MARK: - 5. seek クランプ

    func test_seek_clampsBelowZeroAndAboveDuration() {
        var state = MotionReplayState(
            series: makeIdentitySeries(duration: 1.0),
            currentTime: 0.5
        )

        state.seek(to: -1.0)
        XCTAssertEqual(state.currentTime, 0)

        state.seek(to: 2.0)
        XCTAssertEqual(state.currentTime, 1.0)
    }

    // MARK: - 6. seek NaN/Inf 無視

    func test_seek_ignoresNaNAndInfinity() {
        let original = MotionReplayState(
            series: makeIdentitySeries(duration: 1.0),
            currentTime: 0.5
        )

        var s1 = original
        s1.seek(to: .nan)
        XCTAssertEqual(s1, original)

        var s2 = original
        s2.seek(to: .infinity)
        XCTAssertEqual(s2, original)

        var s3 = original
        s3.seek(to: -.infinity)
        XCTAssertEqual(s3, original)
    }

    // MARK: - 7. play 系条件

    func test_play_respectsEmptyAndEndConditions() {
        // 7-a: 空 series で play → isPlaying == false
        var empty = MotionReplayState()
        empty.play()
        XCTAssertFalse(empty.isPlaying)

        // 7-b: duration=1.0, currentTime=1.0（終端到達）で play → false
        var atEnd = MotionReplayState(
            series: makeIdentitySeries(duration: 1.0),
            currentTime: 1.0,
            isPlaying: false
        )
        atEnd.play()
        XCTAssertFalse(atEnd.isPlaying)

        // 7-c: duration=1.0, currentTime=0.5 で play → true
        var mid = MotionReplayState(
            series: makeIdentitySeries(duration: 1.0),
            currentTime: 0.5,
            isPlaying: false
        )
        mid.play()
        XCTAssertTrue(mid.isPlaying)
    }

    // MARK: - 8. currentOrientation: 0..1s で identity → 90° yaw、t=0.5 で半角 22.5°

    func test_currentOrientation_interpolatesAtMidpoint() {
        let state = MotionReplayState(
            series: makeYaw90Series(),
            currentTime: 0.5,
            isPlaying: false
        )

        // 半角 22.5° = π/8 rad
        let half = Double.pi / 8.0
        let expected = AttitudeQuaternion(w: cos(half), x: 0, y: 0, z: sin(half))
        let actual = state.currentOrientation

        let tolerance = 1e-6
        XCTAssertEqual(actual.w, expected.w, accuracy: tolerance)
        XCTAssertEqual(actual.x, expected.x, accuracy: tolerance)
        XCTAssertEqual(actual.y, expected.y, accuracy: tolerance)
        XCTAssertEqual(actual.z, expected.z, accuracy: tolerance)
    }
}
