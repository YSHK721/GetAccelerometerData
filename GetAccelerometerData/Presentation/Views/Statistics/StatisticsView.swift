import SwiftUI

// MARK: StatisticCard
// 統計情報表示用のカードコンポーネント
struct StatisticCard: View {
  let title: String
  let value: String
  let icon: String

  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    HStack {
      Image(systemName: icon)
        .font(.title2)
        .foregroundColor(colorScheme == .dark ? .white : .accentColor)

      VStack(alignment: .leading) {
        Text(title)
          .font(.caption)
          .foregroundColor(.secondary)

        Text(value)
          .font(.headline)
          .foregroundColor(colorScheme == .dark ? .white : .primary)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding()
    .background(colorScheme == .dark ? Color.gray.opacity(0.2) : Color.white)
    .cornerRadius(8)
    .shadow(
      color: colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.1), radius: 2,
      x: 0, y: 1)
  }
}

// MARK: - 統計情報表示コンポーネント

// MARK: StatisticsView
// 統計情報表示コンポーネント
struct StatisticsView: View {
  let statistics: DataStatistics

  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    VStack(alignment: .leading, spacing: 15) {
      Text("統計情報")
        .font(.headline)
        .foregroundColor(colorScheme == .dark ? .white : .primary)

      // 基本統計情報
      HStack {
        StatisticCard(
          title: "最大値",
          value: String(format: "%.4f G", statistics.maxValue),
          icon: "arrow.up.circle"
        )

        StatisticCard(
          title: "最小値",
          value: String(format: "%.4f G", statistics.minValue),
          icon: "arrow.down.circle"
        )
      }

      HStack {
        StatisticCard(
          title: "平均値",
          value: String(format: "%.4f G", statistics.average),
          icon: "equal.circle"
        )

        StatisticCard(
          title: "標準偏差",
          value: String(format: "%.4f G", statistics.standardDeviation),
          icon: "waveform.path"
        )
      }

      // 追加された統計情報
      HStack {
        StatisticCard(
          title: "ピーク間",
          value: String(format: "%.4f G", statistics.peakToPeak),
          icon: "arrow.up.and.down"
        )

        StatisticCard(
          title: "RMS値",
          value: String(format: "%.4f G", statistics.rmsValue),
          icon: "function"
        )
      }

      HStack {
        StatisticCard(
          title: "中央値",
          value: String(format: "%.4f G", statistics.medianValue),
          icon: "chart.bar"
        )

        StatisticCard(
          title: "サンプリングレート",
          value: String(format: "%.1f Hz", statistics.samplingRate),
          icon: "speedometer"
        )
      }

      // サンプル情報
      HStack {
        StatisticCard(
          title: "サンプル数",
          value: "\(statistics.sampleCount)個",
          icon: "number.circle"
        )

        StatisticCard(
          title: "測定時間",
          value: statistics.duration.formattedDuration,
          icon: "clock"
        )
      }
    }
    .padding()
    .background(colorScheme == .dark ? Color.black.opacity(0.3) : Color.gray.opacity(0.1))
    .cornerRadius(10)
    .overlay(
      RoundedRectangle(cornerRadius: 10)
        .stroke(
          colorScheme == .dark ? Color.gray.opacity(0.3) : Color.gray.opacity(0.2), lineWidth: 1)
    )
  }
}
