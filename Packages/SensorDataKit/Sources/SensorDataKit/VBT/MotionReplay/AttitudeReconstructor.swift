import Foundation
import simd

// MARK: - AttitudeReconstructorError
public enum AttitudeReconstructorError: Error, Equatable {
    /// サンプル 0 件（再構築不能）
    case insufficientSamples
}

// MARK: - AttitudeReconstructor
// VBT Motion Replay PoC Phase 2: `[GyroSample]` → `AttitudeSeries` 変換器（gyro 積分）。
// 内部設計書: .docs/07_vbt_motion_replay_internal_design.md §6 Step 1-6
//
// SRP: 「gyro 時系列 → クォータニオン時系列の数値積分」のみ。
// 入出力 I/O / UI 非依存（純粋関数）。
//
// アルゴリズム（内部設計書 §6 Step 1-6 厳密準拠）:
//   1. q_0 = identity
//   2. for i in 1..<N:
//      - dt = t_i - t_{i-1}
//      - ω̄ = (ω_{i-1} + ω_i) / 2  （台形則）
//      - θ_vec = ω̄ * dt
//      - θ = |θ_vec|
//      - θ < epsilonAngle → Δq = identity
//      - else → axis = θ_vec / θ, Δq = (cos(θ/2), sin(θ/2)*axis)
//      - q_i = normalize(q_{i-1} * Δq)  （Hamilton 積、ローカル軸回転）
public enum AttitudeReconstructor {

    /// 数値定数: 微小回転角の閾値（rad）。
    /// θ < epsilonAngle では Δq を identity と見なし、ゼロ除算（axis = θ_vec / θ）を回避する。
    private static let epsilonAngle: Double = 1e-9

    public static func reconstruct(from samples: [GyroSample]) throws -> AttitudeSeries {
        if samples.isEmpty {
            throw AttitudeReconstructorError.insufficientSamples
        }

        // 1 サンプルのみ: identity 1 件のシリーズを返す
        if samples.count == 1 {
            let only = samples[0]
            let series = AttitudeSeries(samples: [
                AttitudeSeries.Sample(timestamp: only.timestamp, quaternion: .identity)
            ])
            return series
        }

        var quaternions: [simd_quatd] = []
        quaternions.reserveCapacity(samples.count)

        // q_0 = identity
        var q = simd_quatd(real: 1.0, imag: simd_double3(0, 0, 0))
        quaternions.append(q)

        for i in 1..<samples.count {
            let prev = samples[i - 1]
            let curr = samples[i]

            let dt = curr.timestamp - prev.timestamp
            let omegaPrev = simd_double3(prev.x, prev.y, prev.z)
            let omegaCurr = simd_double3(curr.x, curr.y, curr.z)
            let omegaMean = (omegaPrev + omegaCurr) * 0.5
            let thetaVec = omegaMean * dt
            let theta = simd_length(thetaVec)

            let deltaQ: simd_quatd
            if theta < epsilonAngle {
                deltaQ = simd_quatd(real: 1.0, imag: simd_double3(0, 0, 0))
            } else {
                let axis = thetaVec / theta
                let half = theta / 2.0
                deltaQ = simd_quatd(real: cos(half), imag: sin(half) * axis)
            }

            // Hamilton 積（ローカル軸回転）: q_i = q_{i-1} * Δq
            q = simd_normalize(q * deltaQ)
            quaternions.append(q)
        }

        var seriesSamples: [AttitudeSeries.Sample] = []
        seriesSamples.reserveCapacity(samples.count)
        for i in 0..<samples.count {
            seriesSamples.append(
                AttitudeSeries.Sample(
                    timestamp: samples[i].timestamp,
                    quaternion: AttitudeQuaternion(quaternions[i])
                )
            )
        }
        return AttitudeSeries(samples: seriesSamples)
    }
}
