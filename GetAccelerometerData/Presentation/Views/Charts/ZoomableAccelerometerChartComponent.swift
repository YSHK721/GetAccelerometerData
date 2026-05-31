import Charts
import SwiftUI

// MARK: - ズーム機能付きチャートコンポーネント
// MARK: ZoomableAccelerometerChartComponent
struct ZoomableAccelerometerChartComponent: View {
  let readings: [AccelerometerReading]
  let selectedDataType: DataType

  @State private var selectedReading: AccelerometerReading?
  @State private var selectedPosition: CGPoint = .zero

  // Zoom and panning state
  @State private var scale: CGFloat = 1.0
  @State private var lastScale: CGFloat = 1.0
  @State private var offset: CGFloat = 0
  @State private var lastOffset: CGFloat = 0
  @State private var visibleTimeRange: ClosedRange<Double>?
  @State private var isPanning: Bool = false

  // X軸エリアの割合
  private let xAxisAreaRatio: CGFloat = 0.3

  // データポインタのタップ可能領域
  private let dataTapAreaRatio: CGFloat = 0.4

  @Environment(\.colorScheme) private var colorScheme

  // 開始時間を保持するプロパティ
  private var startTime: Date {
    readings.first?.timestamp ?? Date()
  }

  // データの全時間範囲
  private var totalDuration: TimeInterval {
    guard let endDate = readings.last?.timestamp else { return 10 }
    return endDate.timeIntervalSince(startTime)
  }

  // 現在の表示範囲
  private var currentTimeRange: ClosedRange<Double> {
    if let visibleRange = visibleTimeRange {
      return visibleRange
    } else {
      return 0...totalDuration
    }
  }

  // 表示範囲内のデータポイント
  private var visibleReadings: [AccelerometerReading] {
    readings.filter { reading in
      let timePoint = reading.timestamp.timeIntervalSince(startTime)
      return currentTimeRange.contains(timePoint)
    }
  }

  var body: some View {
    ZStack {
      // メインのチャートコンテンツ
      mainChartContent

      // ズーム操作ガイド
      zoomGuideOverlay

      // リセットボタン
      resetButtonOverlay

      // X軸エリアのインジケーター
      xAxisAreaIndicator

      // 選択データの情報表示
      selectedDataPopover
    }
  }

  // メインのチャートコンテンツ
  private var mainChartContent: some View {
    chartContent
      .chartXScale(domain: currentTimeRange)
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
      .chartOverlay { proxy in
        GeometryReader { geometry in
          Color.clear
            .contentShape(Rectangle())
            .gesture(
              DragGesture(minimumDistance: 0)
                .onChanged { value in
                  handleDragChange(value: value, geometry: geometry, proxy: proxy)
                }
                .onEnded { value in
                  handleDragEnd(value: value, geometry: geometry)
                }
            )
            .gesture(
              MagnificationGesture()
                .onChanged { value in
                  handleMagnificationChange(value: value, geometry: geometry)
                }
                .onEnded { value in
                  handleMagnificationEnd(value: value)
                }
            )
        }
      }
  }

  // ズーム操作ガイドのオーバーレイ
  private var zoomGuideOverlay: some View {
    VStack {
      Spacer()
      HStack {
        Image(systemName: "hand.draw")
        Text("ピンチでズーム・X軸エリアをスワイプして移動")
          .font(.caption2)
          .foregroundColor(.secondary)
      }
      .padding(8)
      .background(Color.secondary.opacity(0.1))
      .cornerRadius(8)
    }
    .padding(.bottom, 4)
    .opacity(scale > 1.0 ? 0.6 : 0.8)
  }

  // リセットボタンのオーバーレイ
  @ViewBuilder
  private var resetButtonOverlay: some View {
    if scale > 1.0 {
      VStack {
        HStack {
          Spacer()
          Button(action: resetZoom) {
            Image(systemName: "arrow.counterclockwise")
              .foregroundColor(.white)
              .padding(8)
              .background(Color.accentColor)
              .clipShape(Circle())
          }
        }
        Spacer()
      }
      .padding(.top, 8)
      .padding(.trailing, 8)
    }
  }

  // X軸エリアのインジケーター
  @ViewBuilder
  private var xAxisAreaIndicator: some View {
    if scale > 1.01 {
      GeometryReader { geometry in
        Rectangle()
          .fill(Color.accentColor.opacity(0.05))
          .frame(height: geometry.size.height * xAxisAreaRatio)
          .position(
            x: geometry.size.width / 2,
            y: geometry.size.height * (1.0 - xAxisAreaRatio / 2)
          )
          .allowsHitTesting(false)
      }
    }
  }

  // 選択データのポップオーバー
  @ViewBuilder
  private var selectedDataPopover: some View {
    if let selected = selectedReading, !isPanning {
      VStack {
        dataPointPopover(for: selected, startTime: startTime)
          .offset(
            x: getPopoverXOffset(
              selectedPosition.x, width: 150, screenWidth: UIScreen.main.bounds.width),
            y: -5
          )
          .zIndex(-1)
        Spacer()
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
  }

  // MARK: handleDragChange
  // ドラッグジェスチャーの変更ハンドラー
    private func handleDragChange(
    value: DragGesture.Value, geometry: GeometryProxy, proxy: ChartProxy
    ) {
    let isInXAxisArea = value.startLocation.y > geometry.size.height * (1.0 - xAxisAreaRatio)
    let isHorizontalDrag = abs(value.translation.width) > abs(value.translation.height) * 1.5
    let isSignificantDrag = abs(value.translation.width) > 10

    // scale が1.01以上（ズームされている状態）で、ドラッグがX軸エリア内かつ水平方向の場合
    if scale > 1.01 && isInXAxisArea && isHorizontalDrag {
        isPanning = true
        selectedReading = nil

        // ドラッグの感度を調整
        let dragMultiplier = 50.0
        let newOffset = lastOffset + (value.translation.width * dragMultiplier)

        // 可動範囲
        let maxOffset = geometry.size.width * scale  
        offset = min(max(newOffset, -maxOffset), maxOffset)

        updateVisibleTimeRange(geometry: geometry)
    } else if !isPanning && !isSignificantDrag {
        // パン操作が有効でなく、大きなドラッグでもない場合は、データポイント選択モードとして扱う
        handleDataSelection(at: value.location, in: geometry, proxy: proxy)
    } else if isSignificantDrag && !isInXAxisArea && !isPanning {
        // 大きなドラッグで、X軸エリア外、かつパン操作が有効でない場合も、データ選択を試みる
        // これにより素早いドラッグでもデータ選択が可能になる
        handleDataSelection(at: value.location, in: geometry, proxy: proxy)
    }
    }

    // MARK: handleDragEnd
    // ドラッグジェスチャーの終了ハンドラーを改善
    private func handleDragEnd(value: DragGesture.Value, geometry: GeometryProxy) {
    let isInXAxisArea = value.startLocation.y > geometry.size.height * (1.0 - xAxisAreaRatio)
    
    if scale > 1.01 && isInXAxisArea && abs(value.translation.width) > 5 {
        lastOffset = offset
    }
    
    // より短い遅延でパン操作フラグをリセット
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
        isPanning = false
    }
    }

  // MARK: handleMagnificationChange
  // 拡大ジェスチャーの変更ハンドラー
  private func handleMagnificationChange(value: CGFloat, geometry: GeometryProxy) {
    selectedReading = nil

    let delta = value - 1.0
    let factor = 0.8
    let newScale = lastScale * (1.0 + delta * factor)

    scale = min(max(newScale, 1.01), 20.0)

    if scale.isFinite && scale > 1.0 {
      updateVisibleTimeRange(geometry: geometry)
    }
  }

  // MARK: handleMagnificationEnd
  // 拡大ジェスチャーの終了ハンドラー
  private func handleMagnificationEnd(value: CGFloat) {
    lastScale = scale
  }

  // チャートコンテンツ
  private var chartContent: some View {
    Chart {
      if selectedDataType == .all {
        // すべてのデータ軸を表示
        ForEach(visibleReadings) { reading in
          LineMark(
            x: .value("時間", reading.timestamp.timeIntervalSince(startTime)),
            y: .value("X軸", reading.x)
          )
          .foregroundStyle(by: .value("軸", "X軸"))
          .interpolationMethod(.linear)
          .lineStyle(StrokeStyle(lineWidth: 1.0))
        }

        ForEach(visibleReadings) { reading in
          LineMark(
            x: .value("時間", reading.timestamp.timeIntervalSince(startTime)),
            y: .value("Y軸", reading.y)
          )
          .foregroundStyle(by: .value("軸", "Y軸"))
          .interpolationMethod(.linear)
          .lineStyle(StrokeStyle(lineWidth: 1.0))
        }

        ForEach(visibleReadings) { reading in
          LineMark(
            x: .value("時間", reading.timestamp.timeIntervalSince(startTime)),
            y: .value("Z軸", reading.z)
          )
          .foregroundStyle(by: .value("軸", "Z軸"))
          .interpolationMethod(.linear)
          .lineStyle(StrokeStyle(lineWidth: 1.0))
        }

        ForEach(visibleReadings) { reading in
          LineMark(
            x: .value("時間", reading.timestamp.timeIntervalSince(startTime)),
            y: .value("合成加速度", reading.magnitude)
          )
          .foregroundStyle(by: .value("軸", "合成加速度"))
          .interpolationMethod(.linear)
          .lineStyle(StrokeStyle(lineWidth: 1.5))
        }

        // 選択点の表示
        if let selected = selectedReading {
          PointMark(
            x: .value("時間", selected.timestamp.timeIntervalSince(startTime)),
            y: .value("X軸", selected.x)
          )
          .foregroundStyle(Color.xAxisColor)
          .symbolSize(80)

          PointMark(
            x: .value("時間", selected.timestamp.timeIntervalSince(startTime)),
            y: .value("Y軸", selected.y)
          )
          .foregroundStyle(Color.yAxisColor)
          .symbolSize(80)

          PointMark(
            x: .value("時間", selected.timestamp.timeIntervalSince(startTime)),
            y: .value("Z軸", selected.z)
          )
          .foregroundStyle(Color.zAxisColor)
          .symbolSize(80)

          PointMark(
            x: .value("時間", selected.timestamp.timeIntervalSince(startTime)),
            y: .value("合成加速度", selected.magnitude)
          )
          .foregroundStyle(Color.magnitudeColor)
          .symbolSize(80)
        }
      } else {
        // 単一軸表示
        ForEach(visibleReadings) { reading in
          LineMark(
            x: .value("時間", reading.timestamp.timeIntervalSince(startTime)),
            y: .value(
              selectedDataType.rawValue, valueForDataType(reading: reading, type: selectedDataType))
          )
          .foregroundStyle(colorForDataType(type: selectedDataType))
          .interpolationMethod(.linear)
          .lineStyle(StrokeStyle(lineWidth: 1.0))
        }

        if let selected = selectedReading {
          PointMark(
            x: .value("時間", selected.timestamp.timeIntervalSince(startTime)),
            y: .value(
              selectedDataType.rawValue, valueForDataType(reading: selected, type: selectedDataType)
            )
          )
          .foregroundStyle(colorForDataType(type: selectedDataType))
          .symbolSize(80)
        }
      }
    }
  }

  // MARK: resetZoom
  private func resetZoom() {
    withAnimation {
      scale = 1.0
      lastScale = 1.0
      offset = 0
      lastOffset = 0
      visibleTimeRange = nil
    }
  }

  // MARK: updateVisibleTimeRange
  private func updateVisibleTimeRange(geometry: GeometryProxy) {
    let visibleFraction = 1.0 / scale
    let centerTimeRatio = (0.5 - offset / geometry.size.width / scale)
    let centerTime = totalDuration * max(0, min(1, centerTimeRatio))

    let visibleDuration = totalDuration * visibleFraction
    let startTime = max(0, centerTime - visibleDuration / 2)
    let endTime = min(totalDuration, startTime + visibleDuration)

    visibleTimeRange = startTime...endTime
  }

  // MARK: handleDataSelection
  private func handleDataSelection(at location: CGPoint, in geometry: GeometryProxy, proxy: ChartProxy) {
    let x = location.x

    guard !readings.isEmpty else { return }

    // チャート全体の時間範囲と現在表示中の範囲を取得
    let chartWidth = geometry.size.width
    
    // 表示範囲内のX座標から時間を計算
    // 表示範囲の幅に基づいて時間に変換するように改善
    let timeRangeWidth = currentTimeRange.upperBound - currentTimeRange.lowerBound
    let selectedRatio = x / chartWidth
    let selectedTime = currentTimeRange.lowerBound + (timeRangeWidth * selectedRatio)
    let targetDate = startTime.addingTimeInterval(selectedTime)
    
    // 最も近いデータポイントを検索
    if let closest = findClosestReading(to: targetDate) {
        selectedReading = closest
        selectedPosition = location
    }
    }

  // MARK: getPopoverXOffset
  private func getPopoverXOffset(_ x: CGFloat, width: CGFloat, screenWidth: CGFloat) -> CGFloat {
    let halfWidth = width / 2
    if x < halfWidth {
      return x - halfWidth + 25
    } else if x > screenWidth - halfWidth {
      return x - halfWidth - 25
    }
    return x - halfWidth
  }

  // MARK: findClosestReading
  private func findClosestReading(to targetDate: Date) -> AccelerometerReading? {
    guard !readings.isEmpty else { return nil }

    return readings.min(by: {
      abs($0.timestamp.timeIntervalSince(targetDate))
        < abs($1.timestamp.timeIntervalSince(targetDate))
    })
  }

  // MARK: valueForDataType
  private func valueForDataType(reading: AccelerometerReading, type: DataType) -> Double {
    switch type {
    case .xAxis: return reading.x
    case .yAxis: return reading.y
    case .zAxis: return reading.z
    case .magnitude: return reading.magnitude
    case .all: return 0
    }
  }

  // MARK: colorForDataType
  private func colorForDataType(type: DataType) -> Color {
    switch type {
    case .xAxis: return Color.xAxisColor
    case .yAxis: return Color.yAxisColor
    case .zAxis: return Color.zAxisColor
    case .magnitude: return Color.magnitudeColor
    case .all: return .black
    }
  }

  // MARK: dataPointPopover
  private func dataPointPopover(for reading: AccelerometerReading, startTime: Date) -> some View {
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
  private func formatTimeInterval(_ interval: TimeInterval) -> String {
    return String(format: "%.2f秒", interval)
  }
}
