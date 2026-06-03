import Foundation
import simd

// MARK: - AttitudeQuaternion
// VBT Motion Replay PoC: 姿勢を表現する不変クォータニオン値型。
// 内部設計書: .docs/07_vbt_motion_replay_internal_design.md §2.2.1 / §6
//
// SRP: 「単位クォータニオンの値保持 + SLERP/LERP 補間」のみを担う純粋値型。
// SwiftUI / SceneKit / UIKit に依存しないため、本パッケージのドメイン層に常駐できる。
//
// 規約:
//   - 符号規約: w >= 0 強制は行わない（隣接間 dot 検査で連続性を保つため）
//   - simd_quatd（倍精度）を内部表現とし、SceneKit 反映時のみ simd_quatf にダウンキャスト
public struct AttitudeQuaternion: Sendable, Equatable {

    public let w: Double
    public let x: Double
    public let y: Double
    public let z: Double

    public init(w: Double, x: Double, y: Double, z: Double) {
        self.w = w
        self.x = x
        self.y = y
        self.z = z
    }

    /// 単位クォータニオン `(1, 0, 0, 0)`（無回転）
    public static let identity = AttitudeQuaternion(w: 1, x: 0, y: 0, z: 0)

    /// simd_quatd への変換（数値演算用）
    public var simdValue: simd_quatd {
        simd_quatd(ix: x, iy: y, iz: z, r: w)
    }

    /// simd_quatd からの初期化
    public init(_ q: simd_quatd) {
        self.w = q.real
        self.x = q.imag.x
        self.y = q.imag.y
        self.z = q.imag.z
    }

    // MARK: - SLERP

    /// 数値定数: 補間方式分岐しきい値（OpenGL Red Book / id Software 標準値）
    /// dot_abs > この値で LERP fallback、それ未満で SLERP を採用
    public static let slerpLerpThreshold: Double = 0.9995

    /// SLERP 分母 sin(Ω) の 0 近傍判定しきい値。
    /// dotClamped <= slerpLerpThreshold の経路に到達しているため理論上 sinOmega は十分大きいが、
    /// 浮動小数誤差で 0 近傍に振れた場合の 0 除算回避のための防御（超低発生確率）。
    private static let sinOmegaEpsilon: Double = 1e-12

    /// 2 クォータニオン間の球面線形補間（SLERP）。
    /// 内部設計書 §6 Step 7 の仕様に厳密準拠:
    /// 1. dot < 0 なら b を反転して最短弧を採用
    /// 2. dot_abs > 0.9995 で LERP fallback（特異点回避）
    /// 3. それ未満で標準 SLERP
    /// 4. 結果は常に正規化される
    ///
    /// - Parameters:
    ///   - a: 始点クォータニオン
    ///   - b: 終点クォータニオン
    ///   - t: 補間係数 [0, 1]（範囲外でもクランプせず計算可、呼び出し側責務）
    /// - Returns: 補間結果（正規化済み）
    public static func slerp(
        from a: AttitudeQuaternion,
        to b: AttitudeQuaternion,
        t: Double
    ) -> AttitudeQuaternion {
        // dot 計算（最短弧化）
        let rawDot = a.w * b.w + a.x * b.x + a.y * b.y + a.z * b.z
        let bAdjusted: AttitudeQuaternion
        let dot: Double
        if rawDot < 0 {
            bAdjusted = AttitudeQuaternion(w: -b.w, x: -b.x, y: -b.y, z: -b.z)
            dot = -rawDot
        } else {
            bAdjusted = b
            dot = rawDot
        }

        // 浮動小数誤差で dot が > 1.0 になり得るためクランプ
        let dotClamped = min(1.0, max(-1.0, dot))

        // 補間方式分岐
        if dotClamped > slerpLerpThreshold {
            // LERP fallback（数値安定性）: 線形補間 + 正規化
            let w = (1 - t) * a.w + t * bAdjusted.w
            let x = (1 - t) * a.x + t * bAdjusted.x
            let y = (1 - t) * a.y + t * bAdjusted.y
            let z = (1 - t) * a.z + t * bAdjusted.z
            return Self.normalize(w: w, x: x, y: y, z: z)
        }

        // 標準 SLERP
        let omega = acos(dotClamped)
        let sinOmega = sin(omega)
        // sinOmega が 0 に近すぎる場合は LERP fallback（理論上ここには来ないが防御）
        if sinOmega < Self.sinOmegaEpsilon {
            return a
        }
        let factorA = sin((1 - t) * omega) / sinOmega
        let factorB = sin(t * omega) / sinOmega
        let w = factorA * a.w + factorB * bAdjusted.w
        let x = factorA * a.x + factorB * bAdjusted.x
        let y = factorA * a.y + factorB * bAdjusted.y
        let z = factorA * a.z + factorB * bAdjusted.z
        return AttitudeQuaternion(w: w, x: x, y: y, z: z)
    }

    // MARK: - Helpers

    /// 4 成分を正規化して新規クォータニオンを返す。
    /// ノルムが極小（< 1e-15）の場合は identity を返す（数値安定）。
    private static func normalize(w: Double, x: Double, y: Double, z: Double) -> AttitudeQuaternion {
        let norm = sqrt(w * w + x * x + y * y + z * z)
        guard norm > 1e-15 else { return .identity }
        return AttitudeQuaternion(w: w / norm, x: x / norm, y: y / norm, z: z / norm)
    }
}
