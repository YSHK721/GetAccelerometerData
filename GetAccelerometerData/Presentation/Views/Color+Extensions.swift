import Foundation
import SwiftUI

// MARK: - Color Extension
// カラー定義の統一（グラフとポップアップで同じ色を使用）
extension Color {
    static let xAxisColor: Color = .blue
    static let yAxisColor: Color = .green
    static let zAxisColor: Color = .orange
    static let magnitudeColor: Color = .purple
}

// MARK: - Chart 凡例キー → Color マップ
extension Color {
    /// `chartForegroundStyleScale` 用に DataType ラベル文字列 → Color を返す単一情報源。
    /// `KeyValuePairs` 型は順序を保証し、Swift Charts API が要求する `KeyValuePairs<DataValue, S>` に直接渡せる。
    static let accelerometerLegendColors: KeyValuePairs<String, Color> = [
        DataType.xAxis.rawValue: .xAxisColor,
        DataType.yAxis.rawValue: .yAxisColor,
        DataType.zAxis.rawValue: .zAxisColor,
        DataType.magnitude.rawValue: .magnitudeColor,
    ]
}

// MARK: - TimeInterval Extension
// グラフ・統計表示で共通利用する所要時間フォーマット
extension TimeInterval {
    /// 「分・秒」を省略表記した日本語ローカル文字列を返す（例: "1分20秒"）
    var formattedDuration: String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: self) ?? "0秒"
    }
}
