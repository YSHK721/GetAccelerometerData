import Foundation

extension FileManager {
    
    // ドキュメントディレクトリにあるCSVファイルを全て取得
    static func getAccelerometerFiles() -> [URL] {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(at: documentsDirectory,
                                                                       includingPropertiesForKeys: nil)
            let csvFiles = fileURLs.filter { $0.pathExtension == "csv" }
            
            // 作成日時の新しい順に並べ替え
            return csvFiles.sorted { (file1, file2) -> Bool in
                let attributes1 = try? FileManager.default.attributesOfItem(atPath: file1.path)
                let attributes2 = try? FileManager.default.attributesOfItem(atPath: file2.path)
                let date1 = attributes1?[.creationDate] as? Date ?? Date.distantPast
                let date2 = attributes2?[.creationDate] as? Date ?? Date.distantPast
                return date1 > date2
            }
        } catch {
            print("ファイル一覧の取得に失敗しました: \(error)")
            return []
        }
    }
    
    // 指定されたURLのファイルを削除
    static func deleteFile(at url: URL) -> Bool {
        do {
            try FileManager.default.removeItem(at: url)
            print("ファイルを削除しました: \(url.lastPathComponent)")
            return true
        } catch {
            print("ファイルの削除に失敗しました: \(error)")
            return false
        }
    }
    
    // ファイルの作成日時を取得して文字列に変換
    static func getFileDate(for url: URL) -> String {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
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
    
    // ファイルサイズを取得して整形
    static func getFileSize(for url: URL) -> String {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            if let fileSize = attributes[.size] as? Int64 {
                let byteCountFormatter = ByteCountFormatter()
                byteCountFormatter.allowedUnits = [.useKB, .useMB]
                byteCountFormatter.countStyle = .file
                return byteCountFormatter.string(fromByteCount: fileSize)
            }
        } catch {
            print("ファイルサイズの取得に失敗しました: \(error)")
        }
        return "サイズ不明"
    }
}