// ContentView.swift
import SwiftUI
import WatchConnectivity

struct ContentView: View {
    @StateObject private var accelerometerManager = AccelerometerManager()
    @State private var isMeasuring = false
    @State private var isRecording = false
    @State private var savedFilePath: URL? = nil
    @State private var showingSaveSuccess = false
    @State private var showingTransferStatus = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Text("加速度センサーデータ")
                        .font(.headline)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("X軸: \(accelerometerManager.acceleration.x, specifier: "%.4f")")
                        Text("Y軸: \(accelerometerManager.acceleration.y, specifier: "%.4f")")
                        Text("Z軸: \(accelerometerManager.acceleration.z, specifier: "%.4f")")
                        Text("サンプリングレート: \(accelerometerManager.accelerometerSamplingRate, specifier: "%.1f") Hz")
                            .foregroundColor(.secondary)
                    }
                    .font(.system(.body, design: .monospaced))

                    Text("ジャイロスコープデータ")
                        .font(.headline)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("X軸: \(accelerometerManager.gyroscope.x, specifier: "%.4f") rad/s")
                        Text("Y軸: \(accelerometerManager.gyroscope.y, specifier: "%.4f") rad/s")
                        Text("Z軸: \(accelerometerManager.gyroscope.z, specifier: "%.4f") rad/s")
                        Text("サンプリングレート: \(accelerometerManager.gyroscopeSamplingRate, specifier: "%.1f") Hz")
                            .foregroundColor(.secondary)
                    }
                    .font(.system(.body, design: .monospaced))
                    
                    // 加速度の視覚的な表現
                    Text("加速度")
                            .font(.caption)
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 2) {
                            Rectangle()
                                .fill(Color.red)
                                .frame(width: CGFloat(50 + accelerometerManager.acceleration.x * 20), height: 15)
                            
                            Rectangle()
                                .fill(Color.green)
                                .frame(width: CGFloat(50 + accelerometerManager.acceleration.y * 20), height: 15)
                            
                            Rectangle()
                                .fill(Color.blue)
                                .frame(width: CGFloat(50 + accelerometerManager.acceleration.z * 20), height: 15)
                        }
                    }
                    
                    // ジャイロスコープの視覚的な表現
                    Text("ジャイロスコープ")
                            .font(.caption)
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 2) {
                            Rectangle()
                                .fill(Color.orange)
                                .frame(width: CGFloat(50 + accelerometerManager.gyroscope.x * 10), height: 15)
                            
                            Rectangle()
                                .fill(Color.purple)
                                .frame(width: CGFloat(50 + accelerometerManager.gyroscope.y * 10), height: 15)
                            
                            Rectangle()
                                .fill(Color.cyan)
                                .frame(width: CGFloat(50 + accelerometerManager.gyroscope.z * 10), height: 15)
                        }
                    }
                    
                    // 測定状態
                    Button(action: {
                        if isMeasuring {
                            // 測定停止時に記録も停止
                            if isRecording {
                                stopRecording()
                                // 記録したデータを自動的に保存する
                                saveData()
                                // iPhoneにデータを自動転送
                                transferDataToiPhone()
                                showingTransferStatus = true
                            }
                            accelerometerManager.stopUpdates()
                        } else {
                            // 測定開始時に記録も開始
                            accelerometerManager.startUpdates()
                            startRecording()
                        }
                        isMeasuring.toggle()
                    }) {
                        Text(isMeasuring ? "測定停止" : "測定開始")
                            .font(.headline)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(isMeasuring ? Color.red : Color.green)
                    .cornerRadius(100)
                    
                    // 記録状態
                    if showingSaveSuccess {
                        Text("データを保存しました！")
                            .foregroundColor(.green)
                            .font(.footnote)
                            .padding()
                            .onAppear {
                                // 3秒後に非表示
                                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                    showingSaveSuccess = false
                                }
                            }
                    }
                    
                    // 転送状態の表示
                    if !accelerometerManager.transferStatus.isEmpty {
                        VStack {
                            Text(accelerometerManager.transferStatus)
                                .foregroundColor(accelerometerManager.transferStatus.contains("エラー") || 
                                                accelerometerManager.transferStatus.contains("接続できません") ? 
                                                .red : .green)
                                .font(.footnote)
                                .multilineTextAlignment(.center)
                                .padding(.top, 4)
                            
                            if accelerometerManager.isTransferring {
                                ProgressView()
                                    .padding(.top, 4)
                            }
                        }
                        .padding()
                        .onAppear {
                            // 転送完了か5秒後に非表示
                            if accelerometerManager.transferStatus.contains("転送完了") {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                                    showingTransferStatus = false
                                }
                                
                            }
                        }
                    }
                    
                    // ファイル一覧ビューへのナビゲーションリンク
                    NavigationLink(destination: FileBrowserView()) {
                        Text("保存済みファイルを表示")
                            .font(.headline)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .buttonStyle(PlainButtonStyle())

                    // VBT Ground Truth Tool (Phase A)
                    NavigationLink(destination: VBTRecordingView()) {
                        Text("VBT 記録 (Phase A)")
                            .font(.headline)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.purple)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding()
            .navigationTitle("加速度データ")
        }
    }
}

// 以下の関数を追加
extension ContentView {
    // 記録開始
    private func startRecording() {
        accelerometerManager.startRecording()
        isRecording = true
    }
    
    // 記録停止
    private func stopRecording() {
        accelerometerManager.stopRecording()
        isRecording = false
    }
    
    // データの保存
    private func saveData() {
        if let savedURL = accelerometerManager.saveDataToCSV() {
            savedFilePath = savedURL
            showingSaveSuccess = true
        }
    }
    
    // iPhoneにデータを転送
    private func transferDataToiPhone() {
        accelerometerManager.transferDataToiPhone()
    }
}

// FileBrowserView.swift
import SwiftUI
import Foundation
import WatchKit

struct FileBrowserView: View {
    @State private var files: [URL] = []
    @State private var selectedFileURL: URL?
    @State private var showingDeleteAlert = false
    
    var body: some View {
        List {
            if files.isEmpty {
                Text("保存されたファイルはありません")
                    .foregroundColor(.secondary)
            } else {
                ForEach(files, id: \.lastPathComponent) { file in
                    NavigationLink {
                        FileDetailView(fileURL: file)
                    } label: {
                        VStack(alignment: .leading) {
                            Text(file.lastPathComponent)
                                .font(.headline)
                            Text(getFileDate(file))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            selectedFileURL = file
                            showingDeleteAlert = true
                        } label: {
                            Label("削除", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .navigationTitle("保存済みファイル")
        .onAppear(perform: loadFiles)
        .alert("ファイルを削除しますか？", isPresented: $showingDeleteAlert) {
            Button("削除", role: .destructive) {
                if let url = selectedFileURL {
                    deleteFile(url: url)
                }
            }
            Button("キャンセル", role: .cancel) {}
        }
    }
    
    // Add function to delete a single file
    private func deleteFile(url: URL) {
        do {
            try FileManager.default.removeItem(at: url)
            print("ファイルを削除しました: \(url.lastPathComponent)")
            // Update file list
            loadFiles()
        } catch {
            print("ファイルの削除に失敗しました: \(error)")
        }
    }
    
    private func loadFiles() {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(at: documentsDirectory,
                                                                     includingPropertiesForKeys: nil)
            files = fileURLs.filter { $0.pathExtension == "csv" }
            // 日付の新しい順に並べ替え
            files.sort { (file1, file2) -> Bool in
                let attributes1 = try? FileManager.default.attributesOfItem(atPath: file1.path)
                let attributes2 = try? FileManager.default.attributesOfItem(atPath: file2.path)
                let date1 = attributes1?[.creationDate] as? Date ?? Date.distantPast
                let date2 = attributes2?[.creationDate] as? Date ?? Date.distantPast
                return date1 > date2
            }
        } catch {
            print("ファイル一覧の取得に失敗しました: \(error)")
        }
    }
    
    private func getFileDate(_ fileURL: URL) -> String {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
            if let creationDate = attributes[.creationDate] as? Date {
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                formatter.timeStyle = .medium
                formatter.locale = Locale(identifier: "ja_JP")
                return formatter.string(from: creationDate)
            }
        } catch {
            print("ファイル日時の取得に失敗しました: \(error)")
        }
        return "日時不明"
    }
    
    private func deleteFiles(at offsets: IndexSet) {
        for index in offsets {
            let fileURL = files[index]
            do {
                try FileManager.default.removeItem(at: fileURL)
                print("ファイルを削除しました: \(fileURL.lastPathComponent)")
            } catch {
                print("ファイルの削除に失敗しました: \(error)")
            }
        }
        // ファイル一覧を更新
        loadFiles()
    }
}

// 新しく追加する詳細ビュー
struct FileDetailView: View {
    let fileURL: URL
    @State private var fileContent: String = ""
    
    var body: some View {
        ScrollView {
            Text(fileContent)
                .font(.system(.body, design: .monospaced))
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle(fileURL.lastPathComponent)
        .onAppear {
            loadFileContent()
        }
    }
    
    private func loadFileContent() {
        do {
            fileContent = try String(contentsOf: fileURL, encoding: .utf8)
        } catch {
            fileContent = "ファイルの読み込みに失敗しました: \(error)"
        }
    }
}

#Preview {
    FileBrowserView()
}

#Preview {
    ContentView()
}
