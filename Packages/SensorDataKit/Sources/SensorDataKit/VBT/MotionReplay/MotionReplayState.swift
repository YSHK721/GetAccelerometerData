import Foundation

// MARK: - MotionReplayState
// VBT Motion Replay PoC Phase 3: 再生状態の保持と純粋ロジック。
// 内部設計書: .docs/07_vbt_motion_replay_internal_design.md §9
//
// SRP: 「再生状態（series / currentTime / isPlaying）の保持と純粋な状態遷移」のみ。
// Timer / SwiftUI / SceneKit / UIKit 非依存。`@MainActor` ガード不要、
// `Sendable Equatable` 値型として扱う。
//
// 不変条件:
//   - 0 <= currentTime <= series.duration（advance / seek でクランプ）
//   - series.isEmpty のとき currentOrientation == identity（AttitudeSeries に委譲）
public struct MotionReplayState: Sendable, Equatable {

    public var series: AttitudeSeries
    /// series.startTime からのオフセット秒
    public var currentTime: TimeInterval
    public var isPlaying: Bool

    public init(
        series: AttitudeSeries = AttitudeSeries(samples: []),
        currentTime: TimeInterval = 0,
        isPlaying: Bool = false
    ) {
        self.series = series
        self.currentTime = currentTime
        self.isPlaying = isPlaying
    }

    /// `series.startTime + currentTime` に該当するクォータニオン。
    /// series 空時は AttitudeSeries の仕様により identity が返る。
    public var currentOrientation: AttitudeQuaternion {
        series.orientation(at: series.startTime + currentTime)
    }

    /// 時刻進行（Timer 駆動）。currentTime を dt だけ進め、
    /// series.duration を超えたらクランプして isPlaying = false。
    ///
    /// 仕様:
    ///   - dt <= 0: 何もしない（前進方向のみ）
    ///   - duration <= 0（空・単一サンプル）: isPlaying = false へ強制（再生対象なし）
    ///   - currentTime + dt >= duration: currentTime = duration, isPlaying = false
    ///   - それ以外: currentTime += dt
    public mutating func advance(by dt: TimeInterval) {
        guard dt > 0 else { return }
        let duration = series.duration
        // 🟡-4: duration <= 0 は再生対象なし。外部から isPlaying=true を作為注入された場合の防御。
        guard duration > 0 else {
            isPlaying = false
            return
        }
        let next = currentTime + dt
        if next >= duration {
            currentTime = duration
            isPlaying = false
        } else {
            currentTime = next
        }
    }

    /// 時刻シーク。currentTime = clamp(time, 0, series.duration)。
    /// NaN/Inf は無視（state 変更なし）。
    public mutating func seek(to time: TimeInterval) {
        guard time.isFinite else { return }
        let duration = series.duration
        if time < 0 {
            currentTime = 0
        } else if time > duration {
            currentTime = duration
        } else {
            currentTime = time
        }
    }

    /// 再生開始。series が空 / 終端到達済みの場合は無視。
    public mutating func play() {
        guard !series.isEmpty else { return }
        guard currentTime < series.duration else { return }
        isPlaying = true
    }

    /// 一時停止。
    public mutating func pause() {
        isPlaying = false
    }
}
