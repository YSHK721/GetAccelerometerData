// VBT Motion Replay — 案 B（非対称軸検出方式）pivot 選定ロジックのテスト
// 内部設計書: ISSUE-034 参照
//
// テスト対象: `WatchModelPivot.selectBodyCenterPivot(bboxMin:bboxMax:asymmetryThreshold:)`
//
// 設計意図:
//   OBJ アセット（本体+バンド）の bbox 中心ではなく「最も非対称な軸」だけ pivot=0 に強制することで
//   Apple Watch 本体中心を中心に姿勢回転させる。バンドが片側に長く延びる Steel_Classic_42 系統で
//   姿勢変化時の振り子状円弧運動を解消するのが目的。
//
// プラットフォーム:
//   `WatchModelPivot` は SIMD3<Float>（simd モジュール）のみに依存し SceneKit 非依存のため、
//   macOS テストランナーで実行可能。`#if canImport(UIKit)` ガード不要。

import XCTest
@testable import SensorDataKit
import simd

final class WatchModelPivotTests: XCTestCase {

    private let defaultThreshold: Float = 0.10

    // MARK: - TC-001: Steel_Classic_42 想定値（実機 OBJ の bbox 実測値相当）

    /// バンドが -Z 方向に大きく延びる Steel_Classic_42 想定。
    /// center.z = -19.265, extent.z = 46.93 → ratio = 0.4104 (> 0.10) → pivot.z=0 に強制
    /// center.x = 0.58, extent.x = 29.88 → ratio = 0.0194 → bbox 中心維持
    /// center.y = 0.045, extent.y = 52.35 → ratio = 0.00086 → bbox 中心維持
    func test_selectBodyCenterPivot_steelClassic42_zAxisForcedToZero() {
        let bboxMin = SIMD3<Float>(-14.36, -26.13, -42.73)
        let bboxMax = SIMD3<Float>(15.52, 26.22, 4.20)

        let pivot = WatchModelPivot.selectBodyCenterPivot(
            bboxMin: bboxMin,
            bboxMax: bboxMax,
            asymmetryThreshold: defaultThreshold
        )

        XCTAssertEqual(pivot.x, 0.58, accuracy: 1e-4, "X 軸は対称的（ratio≈0.019）なので bbox 中心維持")
        XCTAssertEqual(pivot.y, 0.045, accuracy: 1e-4, "Y 軸は対称的（ratio≈0.0009）なので bbox 中心維持")
        XCTAssertEqual(pivot.z, 0.0, accuracy: 1e-6, "Z 軸は最も非対称（ratio≈0.410）なので 0 に強制")
    }

    // MARK: - TC-002: 全軸対称モデル

    /// 全軸対称（原点中心）モデル: asymmetryRatio はすべて 0 → 全軸 bbox 中心を維持
    /// bbox 中心が原点と一致するため pivot=(0,0,0) になる
    func test_selectBodyCenterPivot_fullySymmetric_returnsOrigin() {
        let bboxMin = SIMD3<Float>(-1, -1, -1)
        let bboxMax = SIMD3<Float>(1, 1, 1)

        let pivot = WatchModelPivot.selectBodyCenterPivot(
            bboxMin: bboxMin,
            bboxMax: bboxMax,
            asymmetryThreshold: defaultThreshold
        )

        XCTAssertEqual(pivot.x, 0.0, accuracy: 1e-6)
        XCTAssertEqual(pivot.y, 0.0, accuracy: 1e-6)
        XCTAssertEqual(pivot.z, 0.0, accuracy: 1e-6)
    }

    // MARK: - TC-003: X 軸のみ非対称

    /// X 軸のみ非対称: center.x = -20, extent.x = 60 → ratio = 0.333 (> 0.10) → pivot.x=0
    /// Y / Z は bbox 中心（=0）と一致するので結果は全軸 0
    func test_selectBodyCenterPivot_xAxisAsymmetricOnly_forcesXToZero() {
        let bboxMin = SIMD3<Float>(-50, -1, -1)
        let bboxMax = SIMD3<Float>(10, 1, 1)

        let pivot = WatchModelPivot.selectBodyCenterPivot(
            bboxMin: bboxMin,
            bboxMax: bboxMax,
            asymmetryThreshold: defaultThreshold
        )

        XCTAssertEqual(pivot.x, 0.0, accuracy: 1e-6, "X 軸は最も非対称なので 0 に強制")
        XCTAssertEqual(pivot.y, 0.0, accuracy: 1e-6, "Y 軸は対称（center=0）")
        XCTAssertEqual(pivot.z, 0.0, accuracy: 1e-6, "Z 軸は対称（center=0）")
    }

    // MARK: - TC-004: 境界値（asymmetryRatio がしきい値ちょうど）

    /// asymmetryRatio = 0.10 ちょうどの軸 → bbox 中心維持を期待（しきい値超過のみで発火、等値は発火しない）
    /// center = 1, extent = 10 → ratio = 0.10
    func test_selectBodyCenterPivot_atThreshold_keepsBboxCenter() {
        // center.x = 1.0, extent.x = 10.0 → ratio = 0.10（しきい値ちょうど）
        let bboxMin = SIMD3<Float>(-4, -4, -4)
        let bboxMax = SIMD3<Float>(6, 6, 6)

        let pivot = WatchModelPivot.selectBodyCenterPivot(
            bboxMin: bboxMin,
            bboxMax: bboxMax,
            asymmetryThreshold: defaultThreshold
        )

        // 全軸とも ratio == 0.10 ちょうどなので bbox 中心 (1, 1, 1) を維持
        XCTAssertEqual(pivot.x, 1.0, accuracy: 1e-6, "ratio == threshold なので bbox 中心維持")
        XCTAssertEqual(pivot.y, 1.0, accuracy: 1e-6, "ratio == threshold なので bbox 中心維持")
        XCTAssertEqual(pivot.z, 1.0, accuracy: 1e-6, "ratio == threshold なので bbox 中心維持")
    }

    // MARK: - TC-005: 0 寸法ガード（退化ケース）

    /// extent[axis] = 0 を含む退化ケース: ZeroDivisionError や NaN を発生させない
    /// X 軸の extent=0、Y/Z は通常値
    func test_selectBodyCenterPivot_zeroExtentAxis_doesNotCrashOrProduceNaN() {
        // X 軸 extent=0（min=max=5）, Y/Z は対称（center=0）
        let bboxMin = SIMD3<Float>(5, -1, -1)
        let bboxMax = SIMD3<Float>(5, 1, 1)

        let pivot = WatchModelPivot.selectBodyCenterPivot(
            bboxMin: bboxMin,
            bboxMax: bboxMax,
            asymmetryThreshold: defaultThreshold
        )

        XCTAssertFalse(pivot.x.isNaN, "X 成分が NaN にならない")
        XCTAssertFalse(pivot.y.isNaN, "Y 成分が NaN にならない")
        XCTAssertFalse(pivot.z.isNaN, "Z 成分が NaN にならない")
        XCTAssertTrue(pivot.x.isFinite, "X 成分が有限値である")
        XCTAssertTrue(pivot.y.isFinite, "Y 成分が有限値である")
        XCTAssertTrue(pivot.z.isFinite, "Z 成分が有限値である")
        // extent=0 軸の asymmetryRatio は 0 として扱われるため、bbox 中心 (=5) が維持される
        XCTAssertEqual(pivot.x, 5.0, accuracy: 1e-6, "extent=0 軸は ratio=0 扱いで bbox 中心維持")
    }
}
