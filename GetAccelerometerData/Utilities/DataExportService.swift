import SwiftUI
import UniformTypeIdentifiers

// Create a data export service
class DataExportService {
    enum ExportFormat {
        case csv
        
        var fileExtension: String {
            return "csv"
        }
        
        var contentType: UTType {
            return UTType.commaSeparatedText
        }
        
        var displayName: String {
            return "CSV"
        }
    }

    /// 業務ルール（必須カラム / 数値妥当性 / 行数）の検証は Domain UseCase へ委譲。
    private static let validateCSVUseCase: ValidateSensorCSVUseCaseProtocol = ValidateSensorCSVUseCase()

    // CSVファイルをエクスポート用に準備し、形式を検証する
    static func prepareCSVForExport(fileURL: URL) -> Data? {
        guard let fileData = try? Data(contentsOf: fileURL) else {
            print("ファイルの読み込みに失敗しました")
            return nil
        }
        guard let csvString = String(data: fileData, encoding: .utf8) else {
            print("ファイルをUTF-8として読み取れませんでした")
            return nil
        }
        guard validateCSVUseCase.execute(csvString: csvString) else {
            print("無効なCSV形式です")
            return nil
        }
        return fileData
    }
}

// Create exportable document type
struct CSVDocument: FileDocument {
    static var readableContentTypes: [UTType] { [UTType.commaSeparatedText] }
    
    var data: Data
    
    init(data: Data) {
        self.data = data
    }
    
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = data
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        return FileWrapper(regularFileWithContents: data)
    }
}

// Create a file export view to be added to the file detail view
struct FileExportView: View {
    let fileURL: URL
    @State private var selectedFormat: DataExportService.ExportFormat = .csv
    @State private var showAlert: Bool = false
    @State private var alertMessage: String = ""
    @State private var isExportingCSV: Bool = false
    @State private var csvDocument: CSVDocument?
    
    var body: some View {
        VStack(spacing: 20) {
            Text("データエクスポート")
                .font(.headline)
            
            Button {
                exportFile()
            } label: {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                    Text("CSVとしてエクスポート")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .padding(.horizontal)
        }
        .padding()
        .alert(alertMessage, isPresented: $showAlert) {
            Button("OK") { }
        }
        // CSVエクスポート状態を管理
        .fileExporter(
            isPresented: $isExportingCSV,
            document: csvDocument,
            contentType: UTType.commaSeparatedText,
            defaultFilename: fileURL.lastPathComponent,
            onCompletion: handleExportResult
        )
    }

    private func exportFile() {
        if let data = DataExportService.prepareCSVForExport(fileURL: fileURL) {
            csvDocument = CSVDocument(data: data)
            isExportingCSV = true  // CSVエクスポートをトリガー
        } else {
            alertMessage = "CSVファイルの準備に失敗しました"
            showAlert = true
        }
    }
    
    private func loadFileData() -> Data? {
        do {
            return try Data(contentsOf: fileURL)
        } catch {
            print("ファイルの読み込みに失敗しました: \(error)")
            return nil
        }
    }
    
    private func handleExportResult(_ result: Result<URL, Error>) {
        switch result {
        case .success:
            alertMessage = "エクスポートが完了しました"
        case .failure(let error):
            alertMessage = "エクスポートに失敗しました: \(error.localizedDescription)"
        }
        showAlert = true
    }
}