// VBT Motion Replay — 案 B（非対称軸検出方式）pivot 選定ロジック
// 内部設計書: ISSUE-034 参照
//
// 責務:
//   ロード済み 3D モデルの bbox（min, max）から、Apple Watch 本体中心を近似する pivot を算出する。
//   各軸ごとに「非対称度（asymmetryRatio = |center / extent|）」を評価し、最も非対称な軸が
//   しきい値を超える場合のみその軸の pivot を 0 に強制する。それ以外の軸は bbox 中心を維持する。
//
// 設計背景:
//   OBJ アセット全体（本体+バンド）の bbox 中心を pivot に設定すると、バンドが片側に長く延びる
//   Apple Watch アセット（Steel_Classic_42 等）では本体中心から最大 ~19mm ズレ、姿勢変化時に
//   本体が振り子状に円弧運動する問題が発生する。本体は概ね OBJ 座標原点付近に置かれている
//   前提を活用し、「最も非対称な軸」だけ pivot=0 に強制することで本体中心回転を実現する。
//
// プラットフォーム:
//   SIMD3<Float>（simd モジュール）のみに依存。SceneKit / UIKit 非依存のため
//   macOS テストランナーで実行可能（テストの非 iOS 実行を阻害しない）。

import simd

/// Apple Watch 3D モデルの本体中心 pivot を算出する純粋関数の名前空間。
///
/// アルゴリズム（案 B：非対称軸検出方式）:
/// 1. bbox 中心 `center = (min + max) / 2`、寸法 `extent = max - min` を 3 軸算出
/// 2. 各軸の非対称度 `asymmetryRatio[i] = |center[i] / extent[i]|`（extent[i]=0 は 0 扱い）
/// 3. `maxAxis = argmax(asymmetryRatio)` を決定
/// 4. `asymmetryRatio[maxAxis] > threshold` なら、その軸の pivot を 0 に強制
/// 5. それ以外の軸は bbox 中心を維持
///
/// しきい値根拠:
///   `threshold = 0.10` は「片側寸法が反対側より 22% 以上長い（= ratio > 0.10）軸を非対称と判定」
///   に相当する。Apple Watch 本体（X / Y 軸：~30mm / ~50mm の対称形状）と
///   バンド方向（Z 軸：~47mm のうち本体外側に最大 42mm 延びる）を確実に区別できる値として選定。
///   将来別アセットで誤判定が出た場合は呼び出し側で個別に調整可能。
public enum WatchModelPivot {

    /// bbox から本体中心 pivot を算出する。
    ///
    /// - Parameters:
    ///   - bboxMin: bbox の最小頂点（3 軸最小値）
    ///   - bboxMax: bbox の最大頂点（3 軸最大値）
    ///   - asymmetryThreshold: 非対称判定しきい値（例: 0.10）。`ratio > threshold` のみで発火し、
    ///     等値（`==`）では発火しない（境界条件は「しきい値超過のみ」）
    /// - Returns: 算出された pivot 座標。各軸は以下のいずれか:
    ///   - 最も非対称な軸かつ ratio がしきい値超: `0`
    ///   - それ以外: bbox 中心 `(min + max) / 2`
    ///
    /// 退化ケース動作:
    ///   - `extent[axis] = 0`（min == max）の場合、その軸の asymmetryRatio は `0` として扱い、
    ///     NaN / 無限大を発生させない。pivot 値は bbox 中心（= min = max）を返す
    ///   - 全軸対称（全 ratio が threshold 以下）の場合、bbox 中心をそのまま返す
    public static func selectBodyCenterPivot(
        bboxMin: SIMD3<Float>,
        bboxMax: SIMD3<Float>,
        asymmetryThreshold: Float
    ) -> SIMD3<Float> {
        let center = (bboxMin + bboxMax) * 0.5
        let extent = bboxMax - bboxMin

        // 各軸の非対称度を算出（extent=0 は 0 扱いで 0 除算を回避）
        var ratios = SIMD3<Float>(0, 0, 0)
        for i in 0..<3 {
            if extent[i] > 0 {
                ratios[i] = abs(center[i] / extent[i])
            } else {
                ratios[i] = 0
            }
        }

        // 最も非対称な軸を決定
        var maxAxis = 0
        var maxRatio = ratios[0]
        for i in 1..<3 {
            if ratios[i] > maxRatio {
                maxRatio = ratios[i]
                maxAxis = i
            }
        }

        // しきい値超のときのみ、その軸の pivot を 0 に強制
        var pivot = center
        if maxRatio > asymmetryThreshold {
            pivot[maxAxis] = 0
        }
        return pivot
    }
}
