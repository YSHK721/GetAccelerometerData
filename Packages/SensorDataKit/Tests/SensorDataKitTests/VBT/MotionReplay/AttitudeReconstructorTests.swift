// VBT Motion Replay PoC Phase 2: AttitudeReconstructor のテスト
// 内部設計書: .docs/07_vbt_motion_replay_internal_design.md §6 Step 1-6
import XCTest
import simd
@testable import SensorDataKit

final class AttitudeReconstructorTests: XCTestCase {

    // MARK: - 1. 0 サンプル → throw insufficientSamples

    func test_reconstruct_emptySamples_throws() {
        XCTAssertThrowsError(try AttitudeReconstructor.reconstruct(from: [])) { error in
            XCTAssertEqual(error as? AttitudeReconstructorError, .insufficientSamples)
        }
    }

    // MARK: - 2. 1 サンプル → identity 1 件

    func test_reconstruct_singleSample_returnsIdentitySeries() throws {
        let samples = [GyroSample(timestamp: 1000.0, x: 0.5, y: 1.0, z: -0.3)]
        let series = try AttitudeReconstructor.reconstruct(from: samples)
        XCTAssertEqual(series.samples.count, 1)
        XCTAssertEqual(series.samples[0].timestamp, 1000.0, accuracy: 1e-12)
        let q = series.samples[0].quaternion
        XCTAssertEqual(q.w, 1.0, accuracy: 1e-12)
        XCTAssertEqual(q.x, 0.0, accuracy: 1e-12)
        XCTAssertEqual(q.y, 0.0, accuracy: 1e-12)
        XCTAssertEqual(q.z, 0.0, accuracy: 1e-12)
    }

    // MARK: - 3. 静止（ω=0）→ 全 quaternion が identity

    func test_reconstruct_zeroAngularVelocity_allIdentity() throws {
        // ω=0、100 サンプル、dt=0.01s
        var samples: [GyroSample] = []
        for i in 0..<100 {
            samples.append(
                GyroSample(timestamp: Double(i) * 0.01, x: 0.0, y: 0.0, z: 0.0)
            )
        }
        let series = try AttitudeReconstructor.reconstruct(from: samples)
        XCTAssertEqual(series.samples.count, 100)
        for s in series.samples {
            XCTAssertEqual(s.quaternion.w, 1.0, accuracy: 1e-9)
            XCTAssertEqual(s.quaternion.x, 0.0, accuracy: 1e-9)
            XCTAssertEqual(s.quaternion.y, 0.0, accuracy: 1e-9)
            XCTAssertEqual(s.quaternion.z, 0.0, accuracy: 1e-9)
        }
    }

    // MARK: - 4. 1 秒間 yaw 90°/s 印加（z 軸のみ）

    func test_reconstruct_yaw90DegreesPerSecond_finalQuaternionMatchesExpected() throws {
        // gyro_z = π/2 rad/s 一定、100 サンプル、dt = 1/99 s で合計 1 秒
        // 最終 quaternion ≈ 90° yaw (z 軸): w = cos(π/4), z = sin(π/4)
        let n = 100
        var samples: [GyroSample] = []
        let totalDuration = 1.0
        for i in 0..<n {
            let t = Double(i) * (totalDuration / Double(n - 1))
            samples.append(
                GyroSample(timestamp: t, x: 0.0, y: 0.0, z: .pi / 2.0)
            )
        }
        let series = try AttitudeReconstructor.reconstruct(from: samples)
        XCTAssertEqual(series.samples.count, n)
        let final = series.samples.last!.quaternion

        let expectedW = cos(.pi / 4.0)
        let expectedZ = sin(.pi / 4.0)
        XCTAssertEqual(final.w, expectedW, accuracy: 1e-6)
        XCTAssertEqual(final.x, 0.0, accuracy: 1e-9)
        XCTAssertEqual(final.y, 0.0, accuracy: 1e-9)
        XCTAssertEqual(final.z, expectedZ, accuracy: 1e-6)
    }

    // MARK: - 5. ノルム維持（10000 ステップ）

    func test_reconstruct_normPreserved_after10000Steps() throws {
        // ω = (1, 2, 3) rad/s 一定、dt = 0.001s、10000 サンプル
        let n = 10000
        let dt = 0.001
        var samples: [GyroSample] = []
        samples.reserveCapacity(n)
        for i in 0..<n {
            samples.append(
                GyroSample(timestamp: Double(i) * dt, x: 1.0, y: 2.0, z: 3.0)
            )
        }
        let series = try AttitudeReconstructor.reconstruct(from: samples)
        XCTAssertEqual(series.samples.count, n)
        let final = series.samples.last!.quaternion
        let norm = sqrt(final.w * final.w + final.x * final.x + final.y * final.y + final.z * final.z)
        XCTAssertEqual(norm, 1.0, accuracy: 1e-12)
    }

    // MARK: - 6. 純粋 x 軸回転 → y, z 虚部成分が ≈ 0

    func test_reconstruct_pureXAxisRotation_yzImaginaryComponentsAreZero() throws {
        // gyro = (0.5, 0, 0) rad/s 一定、1 秒間、100 サンプル
        let n = 100
        let totalDuration = 1.0
        var samples: [GyroSample] = []
        samples.reserveCapacity(n)
        for i in 0..<n {
            let t = Double(i) * (totalDuration / Double(n - 1))
            samples.append(
                GyroSample(timestamp: t, x: 0.5, y: 0.0, z: 0.0)
            )
        }
        let series = try AttitudeReconstructor.reconstruct(from: samples)
        XCTAssertEqual(series.samples.count, n)
        let final = series.samples.last!.quaternion
        // 純粋 x 軸回転: w, x のみが非ゼロ、y, z 虚部成分 ≈ 0
        XCTAssertEqual(final.y, 0.0, accuracy: 1e-9)
        XCTAssertEqual(final.z, 0.0, accuracy: 1e-9)
    }
}
