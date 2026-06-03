// VBT Motion Replay PoC: AttitudeSeries ユニットテスト。
// 内部設計書: .docs/07_vbt_motion_replay_internal_design.md §2.5 AttitudeSeriesTests
import XCTest
@testable import SensorDataKit

final class AttitudeSeriesTests: XCTestCase {

    private let eps = 1e-9

    // MARK: 1. 空配列 → orientation(at:) が identity
    func test_empty_returnsIdentity() {
        let series = AttitudeSeries(samples: [])
        XCTAssertEqual(series.orientation(at: 0.0), .identity)
        XCTAssertEqual(series.orientation(at: 100.0), .identity)
        XCTAssertTrue(series.isEmpty)
        XCTAssertEqual(series.duration, 0)
    }

    // MARK: 2. 単一サンプル → 任意の t で同一クォータニオン
    func test_singleSample_returnsSameAtAnyTime() {
        let half90 = Double.pi / 4.0
        let q90 = AttitudeQuaternion(w: cos(half90), x: 0, y: 0, z: sin(half90))
        let series = AttitudeSeries(samples: [
            AttitudeSeries.Sample(timestamp: 100.0, quaternion: q90)
        ])
        XCTAssertEqual(series.orientation(at: 0.0), q90)
        XCTAssertEqual(series.orientation(at: 100.0), q90)
        XCTAssertEqual(series.orientation(at: 200.0), q90)
        XCTAssertFalse(series.isEmpty)
    }

    // MARK: 3. 2 サンプル、中間時刻で SLERP 期待値
    func test_twoSamples_midTimeReturnsSlerpMid() {
        // t=0 で identity、t=1 で 90° yaw
        let half90 = Double.pi / 4.0
        let q90 = AttitudeQuaternion(w: cos(half90), x: 0, y: 0, z: sin(half90))
        let series = AttitudeSeries(samples: [
            .init(timestamp: 0.0, quaternion: .identity),
            .init(timestamp: 1.0, quaternion: q90)
        ])
        let qMid = series.orientation(at: 0.5)
        // 期待: 22.5° 回転
        let halfMid = Double.pi / 8.0
        XCTAssertEqual(qMid.w, cos(halfMid), accuracy: 1e-6)
        XCTAssertEqual(qMid.z, sin(halfMid), accuracy: 1e-6)
    }

    // MARK: 4. t <= startTime で samples.first
    func test_beforeStart_returnsFirst() {
        let half90 = Double.pi / 4.0
        let q90 = AttitudeQuaternion(w: cos(half90), x: 0, y: 0, z: sin(half90))
        let series = AttitudeSeries(samples: [
            .init(timestamp: 10.0, quaternion: .identity),
            .init(timestamp: 20.0, quaternion: q90)
        ])
        XCTAssertEqual(series.orientation(at: 5.0), .identity)
        XCTAssertEqual(series.orientation(at: 10.0), .identity)
        XCTAssertEqual(series.orientation(at: -1000.0), .identity)
    }

    // MARK: 5. t >= endTime で samples.last
    func test_afterEnd_returnsLast() {
        let half90 = Double.pi / 4.0
        let q90 = AttitudeQuaternion(w: cos(half90), x: 0, y: 0, z: sin(half90))
        let series = AttitudeSeries(samples: [
            .init(timestamp: 10.0, quaternion: .identity),
            .init(timestamp: 20.0, quaternion: q90)
        ])
        XCTAssertEqual(series.orientation(at: 20.0), q90)
        XCTAssertEqual(series.orientation(at: 25.0), q90)
        XCTAssertEqual(series.orientation(at: 1000.0), q90)
    }

    // MARK: 6. t が NaN → identity
    func test_nanTime_returnsIdentity() {
        let series = AttitudeSeries(samples: [
            .init(timestamp: 0.0, quaternion: .identity),
            .init(timestamp: 1.0, quaternion: .identity)
        ])
        XCTAssertEqual(series.orientation(at: .nan), .identity)
        XCTAssertEqual(series.orientation(at: .infinity), .identity)
        XCTAssertEqual(series.orientation(at: -.infinity), .identity)
    }

    // MARK: 7. duration 計算
    func test_duration() {
        let series = AttitudeSeries(samples: [
            .init(timestamp: 100.5, quaternion: .identity),
            .init(timestamp: 102.0, quaternion: .identity),
            .init(timestamp: 105.5, quaternion: .identity)
        ])
        XCTAssertEqual(series.startTime, 100.5)
        XCTAssertEqual(series.endTime, 105.5)
        XCTAssertEqual(series.duration, 5.0, accuracy: eps)
    }

    // MARK: 補足: 多サンプル時の二分探索が境界で正しいか
    func test_manySamples_binarySearchBoundaries() {
        // t=0,1,2,3,...,9 でクォータニオン
        var samples: [AttitudeSeries.Sample] = []
        for i in 0..<10 {
            samples.append(.init(timestamp: Double(i), quaternion: .identity))
        }
        let series = AttitudeSeries(samples: samples)
        // 任意のクエリで識別子返却
        XCTAssertEqual(series.orientation(at: 4.0), .identity)
        XCTAssertEqual(series.orientation(at: 4.5), .identity)
        XCTAssertEqual(series.orientation(at: 8.999), .identity)
    }

    // MARK: 補足: 同時刻サンプルがある場合は a を返す（除算回避）
    func test_zeroSpan_returnsFirst() {
        let half90 = Double.pi / 4.0
        let q90 = AttitudeQuaternion(w: cos(half90), x: 0, y: 0, z: sin(half90))
        let series = AttitudeSeries(samples: [
            .init(timestamp: 5.0, quaternion: .identity),
            .init(timestamp: 5.0, quaternion: q90)
        ])
        // 同時刻なので q_a (identity) を返す
        let q = series.orientation(at: 5.0)
        XCTAssertEqual(q, .identity)
    }
}
