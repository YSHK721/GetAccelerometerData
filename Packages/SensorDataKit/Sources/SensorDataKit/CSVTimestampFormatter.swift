import Foundation

// MARK: - CSVTimestampFormatter
// iOS / watchOS 共通の CSV タイムスタンプ（マイクロ秒精度）フォーマッタ。
// 100Hz 等の高頻度サンプリングで同一ミリ秒に複数サンプルが入る丸め問題を回避する。
public enum CSVTimestampFormatter {

    /// CSV 書き出し/パース用の共通 DateFormatter（秒精度まで）。
    /// 固定設定の参照のみで内部状態を更新しないため Sendable として扱える。
    private static let baseFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    /// `TimeInterval` をマイクロ秒精度の CSV タイムスタンプ文字列に変換する。
    /// 形式: `yyyy-MM-dd HH:mm:ss.SSSSSS`（小数 6 桁）。
    public static func format(_ timestamp: TimeInterval) -> String {
        let wholeSeconds = floor(timestamp)
        var microseconds = Int(round((timestamp - wholeSeconds) * 1_000_000))
        var displayDate = Date(timeIntervalSince1970: wholeSeconds)
        if microseconds >= 1_000_000 {
            microseconds = 0
            displayDate = Date(timeIntervalSince1970: wholeSeconds + 1)
        }
        return "\(baseFormatter.string(from: displayDate)).\(String(format: "%06d", microseconds))"
    }

    /// CSV タイムスタンプ文字列を `TimeInterval` にパースする（小数桁数任意：`.SSS` / `.SSSSSS` 両対応）。
    public static func parseTimeInterval(_ string: String) -> TimeInterval? {
        let parts = string.split(separator: ".", maxSplits: 1)
        guard let baseDate = baseFormatter.date(from: String(parts[0])) else { return nil }
        var fractional: TimeInterval = 0
        if parts.count == 2, let fracInt = Int(parts[1]) {
            let divisor = pow(10.0, Double(parts[1].count))
            fractional = Double(fracInt) / divisor
        }
        return baseDate.timeIntervalSince1970 + fractional
    }

    /// CSV タイムスタンプ文字列を `Date` にパースする。
    public static func parseDate(_ string: String) -> Date? {
        guard let ti = parseTimeInterval(string) else { return nil }
        return Date(timeIntervalSince1970: ti)
    }
}
