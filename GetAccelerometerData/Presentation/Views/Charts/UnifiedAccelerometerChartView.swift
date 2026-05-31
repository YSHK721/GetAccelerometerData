import SwiftUI

// MARK: - メインビュー

// MARK: UnifiedAccelerometerChartView
// 統合された加速度グラフビュー（公開ラッパー）。
// Composition Root から UseCase を Environment 経由で受け取り、内部 Content View に Protocol 注入する。
struct UnifiedAccelerometerChartView: View {
  let fileURL: URL
  @Environment(\.appComposition) private var composition

  var body: some View {
    UnifiedAccelerometerChartContent(
      fileURL: fileURL,
      loadDataUseCase: composition.loadDataUseCase,
      calculateStatisticsUseCase: composition.calculateStatisticsUseCase
    )
  }
}

// MARK: UnifiedAccelerometerChartContent
// ViewModel を保持する内部実装。UseCase は Protocol で受け取る。
private struct UnifiedAccelerometerChartContent: View {
  let fileURL: URL
  @StateObject private var viewModel: AccelerometerChartViewModel
  @State private var showStatistics = true

  @Environment(\.colorScheme) private var colorScheme

  init(
    fileURL: URL,
    loadDataUseCase: LoadAccelerometerDataUseCaseProtocol,
    calculateStatisticsUseCase: CalculateStatisticsUseCaseProtocol
  ) {
    self.fileURL = fileURL
    self._viewModel = StateObject(wrappedValue: AccelerometerChartViewModel(
      loadDataUseCase: loadDataUseCase,
      calculateStatisticsUseCase: calculateStatisticsUseCase
    ))
  }

  var body: some View {
    ScrollView {
      VStack(spacing: 20) {
        if viewModel.isLoading {
          ProgressView("データを読み込み中...")
            .progressViewStyle(
              CircularProgressViewStyle(tint: colorScheme == .dark ? .white : .blue)
            )
            .padding(.top, 50)
        } else if let errorMessage = viewModel.errorMessage {
          VStack {
            Image(systemName: "exclamationmark.triangle")
              .font(.system(size: 40))
              .foregroundColor(.red)
              .padding()

            Text("エラー: \(errorMessage)")
              .foregroundColor(.red)
              .multilineTextAlignment(.center)
          }
          .padding()
          .background(colorScheme == .dark ? Color.red.opacity(0.1) : Color.red.opacity(0.05))
          .cornerRadius(10)
          .padding()
        } else if viewModel.readings.isEmpty {
          VStack {
            Image(systemName: "doc.text.magnifyingglass")
              .font(.system(size: 40))
              .foregroundColor(.secondary)
              .padding()

            Text("データがありません")
              .foregroundColor(.secondary)
          }
          .padding()
        } else {
          // ファイル情報
          VStack(alignment: .leading, spacing: 4) {
            Text("ファイル: \(fileURL.lastPathComponent)")
              .font(.subheadline)
              .foregroundColor(.secondary)
              .lineLimit(1)
              .truncationMode(.middle)

            Text("データポイント: \(viewModel.readings.count)個")
              .font(.subheadline)
              .foregroundColor(.secondary)
          }
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.horizontal)

          // グラフ表示
          VStack {
            chartWithSelection
          }
          .frame(maxWidth: .infinity)
          .background(colorScheme == .dark ? Color.black.opacity(0.2) : Color.white)
          .cornerRadius(10)
          .padding(.horizontal)
          .shadow(color: colorScheme == .dark ? Color.clear : Color.black.opacity(0.05), radius: 5)

          // データ表示オプション
          VStack(spacing: 12) {
            HStack {
              Picker("データ", selection: $viewModel.selectedDataType) {
                ForEach(DataType.allCases, id: \.self) { type in
                  Text(type.rawValue).tag(type)
                }
              }
              .pickerStyle(MenuPickerStyle())

              Spacer()

            }

            // 統計情報の表示切り替え
            Toggle("詳細な統計情報を表示", isOn: $showStatistics)
          }
          .padding(.horizontal)
          .padding(.vertical, 8)
          .background(colorScheme == .dark ? Color.black.opacity(0.3) : Color.gray.opacity(0.05))

          // 統計情報
          if showStatistics {
            StatisticsView(statistics: viewModel.statistics)
              .padding(.horizontal)
          }

          // エクスポート機能
          ExportOptionsView(fileURL: fileURL)
            .padding()
        }
      }
      .padding(.vertical)
    }
    .navigationTitle("加速度データ分析")
    .onAppear {
      Task {
        await viewModel.loadData(from: fileURL)
      }
    }
    .background(colorScheme == .dark ? Color.black : Color.gray.opacity(0.03))
  }

  // 時間範囲でフィルタリングしたデータを取得
  var filteredReadings: [AccelerometerReading] {
    return viewModel.readings
  }

  // MARK: calculateStatistics (deprecated - ViewModelで処理)
  // 統計情報を計算（ViewModelで処理されるため非推奨）
  private func calculateStatistics() -> DataStatistics {
    return viewModel.statistics
  }

  // MARK: loadDataFromCSV (deprecated - ViewModelで処理)
  // CSVファイルからデータを読み込む（ViewModelで処理されるため非推奨）
  private func loadDataFromCSV() {
    // 新しいアーキテクチャではViewModelが処理
    Task {
      await viewModel.loadData(from: fileURL)
    }
  }
}

// メインビューの更新
extension UnifiedAccelerometerChartContent {
  // 選択機能とズーム機能付きのチャートコンポーネントを置き換え
  var chartWithSelection: some View {
    VStack {
      ZoomableAccelerometerChartComponent(
        readings: viewModel.readings,
        selectedDataType: viewModel.selectedDataType
      )
      .frame(height: 350)
      .padding(.horizontal)
    }
    .background(colorScheme == .dark ? Color.black.opacity(0.2) : Color.white)
    .cornerRadius(10)
    .padding(.horizontal)
    .shadow(color: colorScheme == .dark ? Color.clear : Color.black.opacity(0.05), radius: 5)
  }
}


#Preview {
  // プレビュー用のダミーデータ
  let dummyURL = FileManager.default.temporaryDirectory.appendingPathComponent("preview.csv")
  return UnifiedAccelerometerChartView(fileURL: dummyURL)
    .environment(\.appComposition, AppComposition())
}
