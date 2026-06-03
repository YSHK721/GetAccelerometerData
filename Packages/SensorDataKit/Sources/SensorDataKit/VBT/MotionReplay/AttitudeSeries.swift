import Foundation

// MARK: - AttitudeSeries
// VBT Motion Replay PoC: 時刻 → クォータニオンの時系列値型。
// 内部設計書: .docs/07_vbt_motion_replay_internal_design.md §2.2.1 / §6 Step 7
//
// SRP: 「時刻ソート済みクォータニオン列の保持 + 時刻指定での補間取得」のみ。
// I/O / SwiftUI / SceneKit 非依存（純粋値型）。
//
// 不変条件:
//   - samples の timestamp は単調非減少（呼び出し側保証、本型は検証しない）
//   - 空配列を許容する（orientation(at:) は identity を返す）
public struct AttitudeSeries: Sendable, Equatable {

    public struct Sample: Sendable, Equatable {
        public let timestamp: TimeInterval     // UNIX 秒
        public let quaternion: AttitudeQuaternion

        public init(timestamp: TimeInterval, quaternion: AttitudeQuaternion) {
            self.timestamp = timestamp
            self.quaternion = quaternion
        }
    }

    public let samples: [Sample]

    public init(samples: [Sample]) {
        self.samples = samples
    }

    public var isEmpty: Bool { samples.isEmpty }

    public var startTime: TimeInterval { samples.first?.timestamp ?? 0 }

    public var endTime: TimeInterval { samples.last?.timestamp ?? 0 }

    public var duration: TimeInterval { endTime - startTime }

    /// 指定時刻のクォータニオンを SLERP 補間で返す。
    /// 内部設計書 §6 Step 7 仕様:
    ///   - isEmpty → identity
    ///   - time が NaN/Inf → identity
    ///   - time <= startTime → samples.first.quaternion
    ///   - time >= endTime → samples.last.quaternion
    ///   - 中間 → 隣接 2 点間で SLERP（dot 符号修正 + LERP fallback）
    public func orientation(at time: TimeInterval) -> AttitudeQuaternion {
        guard !samples.isEmpty else { return .identity }
        guard time.isFinite else { return .identity }
        if samples.count == 1 {
            return samples[0].quaternion
        }
        if time <= startTime {
            return samples.first!.quaternion
        }
        if time >= endTime {
            return samples.last!.quaternion
        }
        // 二分探索: time_i <= time < time_{i+1} となる i を見つける
        let i = lowerBoundIndex(for: time)
        let a = samples[i]
        let b = samples[i + 1]
        let span = b.timestamp - a.timestamp
        // 同時刻サンプルがある場合は a を返す（除算回避）
        guard span > 0 else { return a.quaternion }
        let u = (time - a.timestamp) / span
        return AttitudeQuaternion.slerp(from: a.quaternion, to: b.quaternion, t: u)
    }

    // MARK: - Helpers

    /// `samples[i].timestamp <= time < samples[i+1].timestamp` となる i を返す。
    /// 呼び出し側で `startTime < time < endTime` が保証されている前提。
    private func lowerBoundIndex(for time: TimeInterval) -> Int {
        var lo = 0
        var hi = samples.count - 1
        while lo + 1 < hi {
            let mid = (lo + hi) / 2
            if samples[mid].timestamp <= time {
                lo = mid
            } else {
                hi = mid
            }
        }
        return lo
    }
}
