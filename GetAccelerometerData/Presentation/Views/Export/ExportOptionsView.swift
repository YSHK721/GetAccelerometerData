import SwiftUI
import UniformTypeIdentifiers

// MARK: ExportStatusView
// ステータス表示コンポーネントを分離
struct ExportStatusView: View {
  let status: ExportOptionsView.ExportStatus

  var body: some View {
    HStack {
      Image(systemName: status.isSuccess ? "checkmark.circle" : "exclamationmark.circle")
        .foregroundColor(status.isSuccess ? .green : .red)

      Text(status.message)
        .font(.footnote)
        .foregroundColor(status.isSuccess ? .green : .red)
    }
    .padding(.vertical, 8)
  }
}

// MARK: ExportButtonView
// エクスポートボタンを分離
struct ExportButtonView: View {
  let title: String
  let icon: String
  let color: Color
  let action: () -> Void

  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    Button(action: action) {
      VStack {
        Image(systemName: icon)
          .font(.system(size: 24))
          .padding(.bottom, 4)
        Text(title)
          .font(.caption)
      }
      .frame(maxWidth: .infinity)
      .padding()
      .background(colorScheme == .dark ? color.opacity(0.8) : color)
      .foregroundColor(.white)
      .cornerRadius(10)
    }
  }
}

// MARK: ExportOptionsView
// メインのエクスポートビュー
struct ExportOptionsView: View {
    let fileURL: URL
    @State private var showingShareSheet = false
    @State private var isExportingCSV = false
    @State private var csvDocument: CSVDocument?
    @State private var exportStatus: ExportStatus?

    @Environment(\.colorScheme) private var colorScheme

    enum ExportStatus {
        case success(String)
        case failure(String)

        var message: String {
            switch self {
            case .success(let msg):
                return msg
            case .failure(let msg):
                return msg
            }
        }

        var isSuccess: Bool {
            if case .success = self {
                return true
            }
            return false
        }
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("エクスポートオプション")
                .font(.headline)
                .foregroundColor(colorScheme == .dark ? .white : .primary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack(spacing: 12) {
                ExportButtonView(
                    title: "CSVとして保存",
                    icon: "doc.text",
                    color: .blue,
                    action: prepareCSVExport
                )

                ExportButtonView(
                    title: "共有",
                    icon: "square.and.arrow.up",
                    color: .green,
                    action: { showingShareSheet = true }
                )
            }
            
            if let status = exportStatus {
                ExportStatusView(status: status)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                            withAnimation {
                                exportStatus = nil
                            }
                        }
                    }
            }
        }
        .padding()
        .background(colorScheme == .dark ? Color.black.opacity(0.3) : Color.white)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(
                    colorScheme == .dark ? Color.gray.opacity(0.3) : Color.gray.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: colorScheme == .dark ? Color.clear : Color.black.opacity(0.05), radius: 5)
        .fileExporter(
            isPresented: $isExportingCSV,
            document: csvDocument,
            contentType: UTType.commaSeparatedText,
            defaultFilename: fileURL.lastPathComponent
        ) { result in
            switch result {
            case .success(let url):
                print("CSVファイルを保存しました: \(url)")
                exportStatus = .success("CSVファイルを保存しました")
            case .failure(let error):
                print("CSVファイルの保存に失敗しました: \(error)")
                exportStatus = .failure("保存に失敗しました: \(error.localizedDescription)")
            }
        }
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(items: [fileURL])
        }
    }

    // MARK: prepareCSVExport
    // CSVのエクスポート準備
    private func prepareCSVExport() {
        if let data = DataExportService.prepareCSVForExport(fileURL: fileURL) {
            csvDocument = CSVDocument(data: data)
            isExportingCSV = true
        } else {
            exportStatus = .failure("CSVデータの準備に失敗しました")
        }
    }
}

