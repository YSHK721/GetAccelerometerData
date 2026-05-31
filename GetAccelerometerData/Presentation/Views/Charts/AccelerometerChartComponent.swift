import Charts
import SwiftUI

// MARK: AccelerometerChartComponent
// グラフ表示コンポーネント
struct AccelerometerChartComponent: View {
  let readings: [AccelerometerReading]
  let selectedDataType: DataType

  @Environment(\.colorScheme) private var colorScheme

  // 開始時間を保持するプロパティを追加
  private var startTime: Date {
    readings.first?.timestamp ?? Date()
  }

  var body: some View {
    Chart {
      if selectedDataType == .all {
        // X軸データ
        ForEach(readings) { reading in
          LineMark(
            x: .value("時間", reading.timestamp.timeIntervalSince(startTime)),
            y: .value("X軸", reading.x)
          )
          .foregroundStyle(by: .value("軸", "X軸"))
          .interpolationMethod(.linear)
          .lineStyle(StrokeStyle(lineWidth: 1.0))
        }

        // Y軸データ
        ForEach(readings) { reading in
          LineMark(
            x: .value("時間", reading.timestamp.timeIntervalSince(startTime)),
            y: .value("Y軸", reading.y)
          )
          .foregroundStyle(by: .value("軸", "Y軸"))
          .interpolationMethod(.linear)
          .lineStyle(StrokeStyle(lineWidth: 1.0))
        }

        // Z軸データ
        ForEach(readings) { reading in
          LineMark(
            x: .value("時間", reading.timestamp.timeIntervalSince(startTime)),
            y: .value("Z軸", reading.z)
          )
          .foregroundStyle(by: .value("軸", "Z軸"))
          .interpolationMethod(.linear)
          .lineStyle(StrokeStyle(lineWidth: 1.0))
        }

        // 合成加速度データを追加
        ForEach(readings) { reading in
          LineMark(
            x: .value("時間", reading.timestamp.timeIntervalSince(startTime)),
            y: .value("合成加速度", reading.magnitude)
          )
          .foregroundStyle(by: .value("軸", "合成加速度"))
          .interpolationMethod(.linear)
          .lineStyle(StrokeStyle(lineWidth: 1.5))
        }
      } else {
        // 単一軸表示
        ForEach(readings) { reading in
          LineMark(
            x: .value("時間", reading.timestamp.timeIntervalSince(startTime)),
            y: .value(
              selectedDataType.rawValue, valueForDataType(reading: reading, type: selectedDataType))
          )
          .foregroundStyle(colorForDataType(type: selectedDataType))
          .interpolationMethod(.linear)
          .lineStyle(StrokeStyle(lineWidth: 1.0))
        }
      }
    }
    .chartYScale(domain: -3...3)
    .chartXAxis {
      AxisMarks(values: .automatic(desiredCount: 5)) { value in
        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3, dash: [2, 2]))
        AxisValueLabel {
          if let seconds = value.as(Double.self) {
            Text(String(format: "%.1f秒", seconds))
          }
        }
      }
    }
    .chartYAxis {
      AxisMarks(position: .leading) { value in
        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3))
        AxisValueLabel()
      }
    }
    .chartLegend(position: .top, alignment: .center)
    .chartForegroundStyleScale(Color.accelerometerLegendColors)
  }

  // MARK: valueForDataType
  // データタイプに応じた値を取得
  private func valueForDataType(reading: AccelerometerReading, type: DataType) -> Double {
    switch type {
    case .xAxis: return reading.x
    case .yAxis: return reading.y
    case .zAxis: return reading.z
    case .magnitude: return reading.magnitude
    case .all: return 0  // この場合は別途処理
    }
  }

  // MARK: colorForDataType
  // データタイプに応じた色を取得
  private func colorForDataType(type: DataType) -> Color {
    switch type {
    case .xAxis: return Color.xAxisColor
    case .yAxis: return Color.yAxisColor
    case .zAxis: return Color.zAxisColor
    case .magnitude: return Color.magnitudeColor
    case .all: return .black  // この場合は別途処理
    }
  }
}

// MARK: - データ選択インタラクション

// データ選択インタラクションのための新しいビュー拡張
extension AccelerometerChartComponent {
  // MARK: dataPointPopover
  // 選択されたデータポイントを表示するためのポップオーバー
  @ViewBuilder
  func dataPointPopover(for reading: AccelerometerReading, startTime: Date) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("時間: \(formatTimeInterval(reading.timestamp.timeIntervalSince(startTime)))")
        .font(.caption)
        .foregroundColor(.secondary)

      if selectedDataType == .all || selectedDataType == .xAxis {
        HStack {
          Circle()
            .fill(Color.xAxisColor)
            .frame(width: 8, height: 8)
          Text("X軸: \(String(format: "%.4f G", reading.x))")
            .font(.caption)
        }
      }

      if selectedDataType == .all || selectedDataType == .yAxis {
        HStack {
          Circle()
            .fill(Color.yAxisColor)
            .frame(width: 8, height: 8)
          Text("Y軸: \(String(format: "%.4f G", reading.y))")
            .font(.caption)
        }
      }

      if selectedDataType == .all || selectedDataType == .zAxis {
        HStack {
          Circle()
            .fill(Color.zAxisColor)
            .frame(width: 8, height: 8)
          Text("Z軸: \(String(format: "%.4f G", reading.z))")
            .font(.caption)
        }
      }

      if selectedDataType == .all || selectedDataType == .magnitude {
        HStack {
          Circle()
            .fill(Color.magnitudeColor)
            .frame(width: 8, height: 8)
          Text("合成: \(String(format: "%.4f G", reading.magnitude))")
            .font(.caption)
        }
      }
    }
    .padding(8)
    .background(
      RoundedRectangle(cornerRadius: 8)
        .fill(Color(UIColor.systemBackground))
        .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
    )
  }

  // MARK: formatTimeInterval
  // 時間間隔のフォーマット
  private func formatTimeInterval(_ interval: TimeInterval) -> String {
    return String(format: "%.2f秒", interval)
  }
}
