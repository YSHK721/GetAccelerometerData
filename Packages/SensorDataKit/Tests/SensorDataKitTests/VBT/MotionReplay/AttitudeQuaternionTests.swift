// VBT Motion Replay PoC: AttitudeQuaternion ユニットテスト。
// 内部設計書: .docs/07_vbt_motion_replay_internal_design.md §2.5 AttitudeQuaternionTests
import XCTest
import simd
@testable import SensorDataKit

final class AttitudeQuaternionTests: XCTestCase {

    private let eps = 1e-9

    // MARK: 1. identity は (1, 0, 0, 0)
    func test_identity_isUnitQuaternion() {
        let q = AttitudeQuaternion.identity
        XCTAssertEqual(q.w, 1.0)
        XCTAssertEqual(q.x, 0.0)
        XCTAssertEqual(q.y, 0.0)
        XCTAssertEqual(q.z, 0.0)
    }

    // MARK: 2. slerp(identity, identity, 0.5) == identity
    func test_slerp_identityToIdentity_returnsIdentity() {
        let q = AttitudeQuaternion.slerp(from: .identity, to: .identity, t: 0.5)
        // dot == 1 → LERP fallback 経路、(0.5+0.5, 0, 0, 0) を正規化
        XCTAssertEqual(q.w, 1.0, accuracy: eps)
        XCTAssertEqual(q.x, 0.0, accuracy: eps)
        XCTAssertEqual(q.y, 0.0, accuracy: eps)
        XCTAssertEqual(q.z, 0.0, accuracy: eps)
    }

    // MARK: 3. 0° → 90° yaw、中間 45° yaw（SLERP 線形）
    func test_slerp_zeroToNinetyYaw_midIsFortyFive() {
        // yaw = rot around Z 軸
        let q0 = AttitudeQuaternion.identity                  // 0°
        let half90 = Double.pi / 4.0                          // 45° (= 90°/2)
        let q90 = AttitudeQuaternion(w: cos(half90), x: 0, y: 0, z: sin(half90))

        let qMid = AttitudeQuaternion.slerp(from: q0, to: q90, t: 0.5)
        // q0=0°, q90=90° yaw 間を t=0.5 で SLERP → 中間回転角 45° → 半角 22.5°
        // → クォータニオン期待値 w=cos(22.5°), z=sin(22.5°)
        let halfMid = Double.pi / 8.0                         // 半角 22.5° = π/8 rad
        XCTAssertEqual(qMid.w, cos(halfMid), accuracy: 1e-6)
        XCTAssertEqual(qMid.x, 0.0, accuracy: 1e-9)
        XCTAssertEqual(qMid.y, 0.0, accuracy: 1e-9)
        XCTAssertEqual(qMid.z, sin(halfMid), accuracy: 1e-6)
    }

    // MARK: 4. dot < 0 の組（q と -q）で最短弧化されて identity を返す
    func test_slerp_negatedTwin_shortestArcReturnsIdentity() {
        let q = AttitudeQuaternion.identity
        let qNeg = AttitudeQuaternion(w: -1, x: 0, y: 0, z: 0)
        let result = AttitudeQuaternion.slerp(from: q, to: qNeg, t: 0.5)
        // dot = -1 → b 反転 → (1, 0, 0, 0) → 自分自身との補間 → identity
        XCTAssertEqual(result.w, 1.0, accuracy: eps)
        XCTAssertEqual(result.x, 0.0, accuracy: eps)
        XCTAssertEqual(result.y, 0.0, accuracy: eps)
        XCTAssertEqual(result.z, 0.0, accuracy: eps)
    }

    // MARK: 5. dot > 0.9995 で LERP fallback、結果が正規化されている
    func test_slerp_nearlyIdentical_lerpFallbackProducesNormalized() {
        // 0.01 rad ≈ 0.57° の微小回転
        let halfAngle = 0.005
        let q0 = AttitudeQuaternion.identity
        let qSmall = AttitudeQuaternion(w: cos(halfAngle), x: 0, y: 0, z: sin(halfAngle))
        // dot ≈ cos(halfAngle) ≈ 0.9999875 > 0.9995 → LERP fallback 経路

        let qMid = AttitudeQuaternion.slerp(from: q0, to: qSmall, t: 0.5)
        let norm = sqrt(qMid.w * qMid.w + qMid.x * qMid.x + qMid.y * qMid.y + qMid.z * qMid.z)
        XCTAssertEqual(norm, 1.0, accuracy: 1e-9)
    }

    // MARK: 6. simdValue ↔ init(simd:) ラウンドトリップ
    func test_simdValue_roundtrip() {
        let original = AttitudeQuaternion(w: 0.5, x: 0.5, y: 0.5, z: 0.5)
        let simd = original.simdValue
        let restored = AttitudeQuaternion(simd)
        XCTAssertEqual(original, restored)
    }

    // MARK: 補足 (a): slerp t=0 → a, t=1 → b
    func test_slerp_endpoints() {
        let half90 = Double.pi / 4.0
        let q90 = AttitudeQuaternion(w: cos(half90), x: 0, y: 0, z: sin(half90))

        let qAt0 = AttitudeQuaternion.slerp(from: .identity, to: q90, t: 0)
        XCTAssertEqual(qAt0.w, 1.0, accuracy: 1e-9)

        let qAt1 = AttitudeQuaternion.slerp(from: .identity, to: q90, t: 1)
        XCTAssertEqual(qAt1.w, cos(half90), accuracy: 1e-9)
        XCTAssertEqual(qAt1.z, sin(half90), accuracy: 1e-9)
    }
}
