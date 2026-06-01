import Foundation

// MARK: - IMUSampleGapDetector
// 仕様書: .docs/VBT_GroundTruth_Tool_Spec.md §9 「IMU途絶」
//   検出条件: `motion.timestamp` の連続サンプル間隔が 0.5 秒以上
//
// SRP: 連続サンプル間隔の監視と「ギャップ検出」判定のみを担う純粋計算ロジック。
//      時刻取得・記録停止・通知は呼び出し側（Use Case）の責務。
// LSP: 値型として置換可能。状態は前回観測タイムスタンプのみ。
// DIP: 外部依存なし（テストで時刻を任意注入可能）。
public struct IMUSampleGapDetector: Sendable {

    public struct GapDetected: Sendable, Equatable {
        public let previousTimestamp: TimeInterval
        public let currentTimestamp: TimeInterval
        public var interval: TimeInterval { currentTimestamp - previousTimestamp }

        public init(previousTimestamp: TimeInterval, currentTimestamp: TimeInterval) {
            self.previousTimestamp = previousTimestamp
            self.currentTimestamp = currentTimestamp
        }
    }

    public let maxIntervalSeconds: TimeInterval
    private var lastTimestamp: TimeInterval?

    public init(maxIntervalSeconds: TimeInterval) {
        self.maxIntervalSeconds = maxIntervalSeconds
    }

    /// サンプルを 1 件観測し、しきい値以上の間隔ならギャップを返す。
    /// - Returns: ギャップ検出時のみ `GapDetected`、それ以外は `nil`
    public mutating func observe(timestamp: TimeInterval) -> GapDetected? {
        defer { lastTimestamp = timestamp }
        guard let previous = lastTimestamp else { return nil }
        let interval = timestamp - previous
        if interval >= maxIntervalSeconds {
            return GapDetected(previousTimestamp: previous, currentTimestamp: timestamp)
        }
        return nil
    }

    /// 内部状態を初期化（次の `observe` は最初のサンプルとして扱われる）
    public mutating func reset() {
        lastTimestamp = nil
    }
}
