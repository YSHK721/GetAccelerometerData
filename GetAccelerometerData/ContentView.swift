//
//  ContentView.swift
//  GetAccelerometerData
//
//  Created by i on 2025/04/22.
//


import SwiftUI
import WatchConnectivity
import UIKit
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var sessionManager = WatchSessionManager()
    @State private var selectedFileURL: URL?
    @State private var showingFilePicker = false
    @State private var isNavigatingToChart = false
    
    private func showFilePicker() {
        showingFilePicker = true
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Image(systemName: "applewatch")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 100, height: 100)
                        .padding()
                    
                    Text("接続状態: \(sessionManager.isSessionReachable ? "接続中" : "未接続")")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .foregroundColor(sessionManager.isSessionReachable ? .green : .red)
                        .background(sessionManager.isSessionReachable ? Color.green.opacity(0.2) : Color.red.opacity(0.2))
                        .cornerRadius(10)
                        .padding(.horizontal)
                        .animation(.easeIn, value: sessionManager.isSessionReachable)
                    
                    if !sessionManager.allReceivedFiles.isEmpty {
                        Text("受信したファイル: \(sessionManager.allReceivedFiles.count)件")
                        
                        List {
                            ForEach(sessionManager.allReceivedFiles, id: \.lastPathComponent) { fileURL in
                                NavigationLink(destination: FileDetailView(fileURL: fileURL)) {
                                    VStack(alignment: .leading) {
                                        Text(fileURL.lastPathComponent)
                                            .font(.headline)
                                        
                                        Text("受信日時: \(sessionManager.getFileDate(for: fileURL))")
                                            .font(.subheadline)
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                        }
                        .frame(minHeight: 100, maxHeight: .infinity)
                        .listStyle(PlainListStyle())
                    } else {
                        Text("Apple Watchからファイルを受信していません")
                            .foregroundColor(.secondary)
                            .padding()
                    }
                    
                    if sessionManager.isTransferring {
                        ProgressView()
                            .padding()
                        Text("ファイル受信中...")
                    }
                    
                    if !sessionManager.lastMessage.isEmpty {
                        Text(sessionManager.lastMessage)
                            .padding()
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(8)
                    }
                }
                .padding()
            }
            .navigationTitle("加速度データ受信")
            .navigationBarTitleDisplayMode(.inline)
            .textFieldStyle(RoundedBorderTextFieldStyle())
            
            Button {
                showFilePicker()
            } label: {
                Label("詳細データ分析", systemImage: "chart.xyaxis.line")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.horizontal)
            
            // 明示的なナビゲーションリンク
            .navigationDestination(isPresented: $isNavigatingToChart) {
                if let url = selectedFileURL {
                    UnifiedAccelerometerChartView(fileURL: url)
                } else {
                    Text("ファイルが選択されていません")
                }
            }

        }
        .onAppear {
            sessionManager.activateSession()
            
            // 初期表示時に既存のファイルがあれば最初のファイルを選択
            if let firstFile = sessionManager.allReceivedFiles.first {
                selectedFileURL = firstFile
            }
        }
        .sheet(isPresented: $showingFilePicker) {
            DocumentPicker(selectedFileURL: $selectedFileURL, isNavigatingToChart: $isNavigatingToChart)
        }
    }
}

struct DocumentPicker: UIViewControllerRepresentable {
    @Binding var selectedFileURL: URL?
    @Binding var isNavigatingToChart: Bool
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        // ドキュメントディレクトリのURLを取得
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        
        // CSVファイルのみをフィルタリング
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.commaSeparatedText])
        picker.allowsMultipleSelection = false
        picker.delegate = context.coordinator
        
        // 初期ディレクトリを設定
        picker.directoryURL = documentsDirectory
        
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPicker
        
        init(_ parent: DocumentPicker) {
            self.parent = parent
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            
            let securityScoped = url.startAccessingSecurityScopedResource()
            
            do {
                let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                let destinationURL = documentsDirectory.appendingPathComponent(url.lastPathComponent)
                
                // ファイルが既にドキュメントディレクトリにあるかチェック
                let isFileAlreadyInDocuments = url.path.contains(documentsDirectory.path)
                
                // 外部から選択されたファイルの場合のみコピー処理を実行
                if !isFileAlreadyInDocuments {
                    // 同名ファイルがあれば削除
                    if FileManager.default.fileExists(atPath: destinationURL.path) {
                        try FileManager.default.removeItem(at: destinationURL)
                    }
                    
                    // ファイルをコピー
                    try FileManager.default.copyItem(at: url, to: destinationURL)
                }
                
                // 使用するURLを決定（ドキュメント内ならそのまま、外部なら新しいパス）
                let fileURLToUse = isFileAlreadyInDocuments ? url : destinationURL
                
                DispatchQueue.main.async {
                    self.parent.selectedFileURL = fileURLToUse
                    DispatchQueue.main.asyncAfter(deadline: .now()) {
                        self.parent.isNavigatingToChart = true
                    }
                }
            } catch {
                print("ファイルの操作に失敗: \(error.localizedDescription)")
            }
            
            if securityScoped {
                url.stopAccessingSecurityScopedResource()
            }
        }
        
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            // ユーザーがキャンセルした場合の処理
            print("Document picker was cancelled")
        }
    }
    
}

struct FileDetailView: View {
    let fileURL: URL
    @State private var fileContent: String = ""
    @State private var isLoading: Bool = true
    @State private var showingShareSheet = false
    
    var body: some View {
        VStack {
            if isLoading {
                ProgressView("ファイルを読み込み中...")
                    .padding()
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 15) {
                        // File info section
                        VStack(alignment: .leading, spacing: 8) {
                            Text("ファイル情報")
                                .font(.headline)
                            
                            Text("名前: \(fileURL.lastPathComponent)")
                                .font(.subheadline)
                            
                            Text("作成日時: \(FileManager.getFileDate(for: fileURL))")
                                .font(.subheadline)
                            
                            Text("サイズ: \(FileManager.getFileSize(for: fileURL))")
                                .font(.subheadline)
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(10)
                        
                        // Action buttons
                        VStack(spacing: 12) {
                            // Graph view button
                            NavigationLink {
                                UnifiedAccelerometerChartView(fileURL: fileURL)
                            } label: {
                                Label("グラフで表示", systemImage: "chart.xyaxis.line")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            // Share button
                            Button {
                                showingShareSheet = true
                            } label: {
                                Label("共有", systemImage: "square.and.arrow.up")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.green)
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                            }
                        }
                        
                        // Export section - now only for CSV
                        FileExportView(fileURL: fileURL)
                            .padding(.vertical)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(10)
                        
                        // File content preview
                        VStack(alignment: .leading, spacing: 8) {
                            Text("プレビュー")
                                .font(.headline)
                            
                            Text(previewContent)
                                .font(.system(.body, design: .monospaced))
                                .padding()
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(8)
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("ファイル詳細")
        .onAppear {
            loadFileContent()
        }
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(items: [fileURL])
        }
    }
    
    // Show only first 15 lines for preview
    private var previewContent: String {
        let lines = fileContent.components(separatedBy: "\n")
        let previewLines = Array(lines.prefix(15))
        
        if lines.count > 15 {
            return previewLines.joined(separator: "\n") + "\n...(残り \(lines.count - 15) 行)"
        } else {
            return previewLines.joined(separator: "\n")
        }
    }
    
    private func loadFileContent() {
        isLoading = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let content = try String(contentsOf: fileURL, encoding: .utf8)
                DispatchQueue.main.async {
                    fileContent = content
                    isLoading = false
                }
            } catch {
                DispatchQueue.main.async {
                    fileContent = "ファイルの読み込みに失敗しました: \(error.localizedDescription)"
                    isLoading = false
                }
            }
        }
    }
}

// ShareSheet implementation
struct ShareSheet: UIViewControllerRepresentable {
    var items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

#Preview {
    ContentView()
}
