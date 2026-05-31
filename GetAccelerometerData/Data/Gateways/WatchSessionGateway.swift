import Foundation
import SwiftUI
import WatchConnectivity
import SensorDataKit

// MARK: - WatchSessionGateway
// iOS 側で Apple Watch からのファイル / メッセージ受信を担う Adapter。
// 旧 `ContentView.swift` 内に同居していた `WatchSessionManager` を Data/Gateways レイヤーに分離（ISSUE-003 対応）。
// 公開 API（プロパティ・メソッド）は変更せず、型名のみ移送先に追随。
//
// CombinedSensorData / AccelerometerRecord 等は SensorDataKit パッケージ（ISSUE-015）の
// 公開型を再利用する。

@MainActor
class WatchSessionManager: NSObject, ObservableObject, WCSessionDelegate {
    @Published var isSessionReachable = false
    @Published var receivedFiles: [URL] = []
    @Published var isTransferring = false
    @Published var lastMessage = ""
    @Published var receivedDataFiles: [URL] = []

    private var fileReceivedDates: [String: Date] = [:]
    // メタデータの受信（ファイル名など）
    private var lastReceivedMetadata: [String: String] = [:]

    var allReceivedFiles: [URL] {
        let combined = receivedFiles + receivedDataFiles
        // Sort by date, newest first
        return combined.sorted { (file1, file2) -> Bool in
            let date1 = fileReceivedDates[file1.lastPathComponent] ?? Date.distantPast
            let date2 = fileReceivedDates[file2.lastPathComponent] ?? Date.distantPast
            return date1 > date2
        }
    }
    
    func activateSession() {
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
            print("WCSession activation started")
        } else {
            print("WCSession is not supported")
        }
    }
    
    func getFileDate(for url: URL) -> String {
        guard let date = fileReceivedDates[url.lastPathComponent] else {
            return "不明"
        }
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: date)
    }
    
    // MARK: - WCSessionDelegate
    
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        let reachable = session.isReachable
        let rawState = activationState.rawValue
        DispatchQueue.main.async {
            if let error = error {
                print("WCSession activation failed with error: \(error.localizedDescription)")
                self.lastMessage = "接続エラー: \(error.localizedDescription)"
                return
            }

            print("WCSession activated with state: \(rawState)")
            self.isSessionReachable = reachable
            self.lastMessage = "WatchConnectivity初期化完了"
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        let reachable = session.isReachable
        DispatchQueue.main.async {
            self.isSessionReachable = reachable
            self.lastMessage = "接続状態が変更されました: \(reachable ? "接続中" : "未接続")"
            print("WCSession reachability changed: \(reachable)")
        }
    }
    
    nonisolated func session(_ session: WCSession, didReceive file: WCSessionFile) {
        DispatchQueue.main.async {
            self.isTransferring = true
            self.lastMessage = "ファイルを受信中..."
        }

        let fileManager = FileManager.default
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]

        // メタデータからファイル名と種別を取得（無ければソースのファイル名）
        let metadata = file.metadata ?? [:]
        let fileName = (metadata["fileName"] as? String) ?? file.fileURL.lastPathComponent
        let dataType = metadata["dataType"] as? String
        let destinationURL = documentsURL.appendingPathComponent(fileName)

        do {
            // 同名ファイルがあれば削除
            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
            }

            if dataType == "json" {
                // Watch側がJSON形式で送ってきたデータをCSVに変換して保存
                let jsonData = try Data(contentsOf: file.fileURL)
                let decoder = JSONDecoder()
                let sensorData = try decoder.decode([CombinedSensorData].self, from: jsonData)
                let csvString = convertCombinedDataToCSV(sensorData)
                try csvString.write(to: destinationURL, atomically: true, encoding: .utf8)
                print("ファイル転送(JSON) → CSV変換して保存: \(destinationURL.path), \(sensorData.count)件")
            } else {
                // CSVなど、そのまま保存する形式
                try fileManager.copyItem(at: file.fileURL, to: destinationURL)
                print("ファイルを保存: \(destinationURL.path)")
            }

            DispatchQueue.main.async {
                self.fileReceivedDates[fileName] = Date()
                self.receivedDataFiles.append(destinationURL)
                self.isTransferring = false
                self.lastMessage = "ファイルを受信しました: \(fileName)"

                NotificationCenter.default.post(
                    name: NSNotification.Name("CSVFileReceived"),
                    object: nil,
                    userInfo: ["fileURL": destinationURL]
                )
            }
        } catch {
            DispatchQueue.main.async {
                self.isTransferring = false
                self.lastMessage = "ファイル保存エラー: \(error.localizedDescription)"
                print("Error processing received file: \(error.localizedDescription)")
            }
        }
    }
    
    // 即時転送のメタデータ受信
    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        // メタデータを保存
        if let transferType = message["transferType"] as? String, transferType == "immediate" {
            let fileName = message["fileName"] as? String
            Task { @MainActor in
                var captured: [String: String] = ["transferType": "immediate"]
                if let fileName { captured["fileName"] = fileName }
                self.lastReceivedMetadata = captured
            }
            print("Watch から受信準備完了: \(message)")
        }

        // Watchアプリに準備完了を通知
        replyHandler(["status": "ready"])
    }

    // 即時転送のデータ受信
    nonisolated func session(_ session: WCSession, didReceiveMessageData messageData: Data, replyHandler: @escaping (Data) -> Void) {
        // 最後に受信したメタデータからファイル名を取得
        let metadata = MainActor.assumeIsolated { self.lastReceivedMetadata }
        if let fileName = metadata["fileName"] {
            do {
                // JSONデータをデコード（CombinedSensorData配列として）
                let decoder = JSONDecoder()
                let sensorData = try decoder.decode([CombinedSensorData].self, from: messageData)
                
                // CSV形式に変換
                let csvString = convertCombinedDataToCSV(sensorData)
                
                // ドキュメントディレクトリに保存
                let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                let fileURL = documentsDirectory.appendingPathComponent(fileName)
                
                try csvString.write(to: fileURL, atomically: true, encoding: .utf8)
                print("CSVファイルを保存しました: \(fileURL.path)")
                
                // メインスレッドで処理（UI更新のため）
                DispatchQueue.main.async {
                    self.fileReceivedDates[fileName] = Date()
                    self.receivedDataFiles.append(fileURL)
                    self.lastMessage = "新しいファイルを受信しました: \(fileName)"
                    
                    // 通知を送信
                    NotificationCenter.default.post(
                        name: NSNotification.Name("CSVFileReceived"), 
                        object: nil, 
                        userInfo: ["fileURL": fileURL]
                    )
                }
            } catch {
                print("ファイルの処理と保存に失敗: \(error.localizedDescription)")
            }
        }
        
        // 受信完了を伝える
        replyHandler(Data())
    }

    // バックグラウンド転送の受信
    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any]) {
        guard let fileData = userInfo["fileData"] as? Data,
            let fileName = userInfo["fileName"] as? String else {
            print("受信したユーザー情報に必要なデータがありません")
            return
        }
        
        do {
            // JSONデータをデコード（CombinedSensorData配列として）
            let decoder = JSONDecoder()
            let sensorData = try decoder.decode([CombinedSensorData].self, from: fileData)
            
            // CSV形式に変換
            let csvString = convertCombinedDataToCSV(sensorData)
            
            // ドキュメントディレクトリに保存
            let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let fileURL = documentsDirectory.appendingPathComponent(fileName)
            
            try csvString.write(to: fileURL, atomically: true, encoding: .utf8)
            print("バックグラウンド転送でCSVファイルを保存しました: \(fileURL.path)")
            
            // ファイル受信日時を記録
            DispatchQueue.main.async {
                self.fileReceivedDates[fileName] = Date()
                self.receivedDataFiles.append(fileURL)
                self.lastMessage = "バックグラウンドでファイルを受信しました: \(fileName)"
                
                // メインスレッドで通知を送信
                NotificationCenter.default.post(
                    name: NSNotification.Name("CSVFileReceived"), 
                    object: nil, 
                    userInfo: ["fileURL": fileURL]
                )
            }
        } catch {
            print("ファイルの処理と保存に失敗: \(error.localizedDescription)")
        }
    }

    // 加速度・ジャイロ統合データを CSV 文字列に変換
    nonisolated private func convertCombinedDataToCSV(_ sensorData: [CombinedSensorData]) -> String {
        var csvString = "timestamp,accel_x,accel_y,accel_z,accel_magnitude,gyro_x,gyro_y,gyro_z,gyro_magnitude\n"

        for data in sensorData {
            let timeString = CSVTimestampFormatter.format(data.timestamp)
            csvString.append("\(timeString),\(data.accelX),\(data.accelY),\(data.accelZ),\(data.accelMagnitude),\(data.gyroX),\(data.gyroY),\(data.gyroZ),\(data.gyroMagnitude)\n")
        }

        return csvString
    }

    // 旧バージョン互換：AccelerometerRecord 配列を CSV 文字列に変換
    nonisolated private func convertRecordsToCSV(_ records: [AccelerometerRecord]) -> String {
        var csvString = "timestamp,x,y,z,magnitude\n"

        for record in records {
            let timeString = CSVTimestampFormatter.format(record.timestamp)
            let magnitude = sqrt(pow(record.x, 2) + pow(record.y, 2) + pow(record.z, 2))
            csvString.append("\(timeString),\(record.x),\(record.y),\(record.z),\(magnitude)\n")
        }

        return csvString
    }

    // 必須メソッド
    nonisolated func session(_ session: WCSession, didFinish fileTransfer: WCSessionFileTransfer, error: Error?) {
        DispatchQueue.main.async {
            if let error = error {
                self.lastMessage = "ファイル転送エラー: \(error.localizedDescription)"
                print("File transfer failed: \(error.localizedDescription)")
            }
        }
    }
    
    // iOS必須メソッド
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {
        print("WCSession became inactive")
    }
    
    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        print("WCSession deactivated")
        // iOSでは新しいWatchとペアリングした場合などに再アクティベートが必要
        WCSession.default.activate()
    }
}
