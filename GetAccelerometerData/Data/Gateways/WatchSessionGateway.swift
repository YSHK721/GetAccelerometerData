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

    /// VBT Ground Truth Tool 用ルーター（Phase B）。
    /// VBT 専用メッセージ（vbt.startRecording / vbt.imuCSV）を Use Case に振分ける。
    /// 既存転送経路（CombinedSensorData JSON / 汎用 CSV）と排他化する。
    var vbtRouter: VBTWatchMessageRouter?

    private var fileReceivedDates: [String: Date] = [:]

    // メタデータの受信（ファイル名など）。WCSession デリゲートはバックグラウンドキューから
    // コールバックされるため、MainActor 隔離プロパティへの直接アクセスは
    // `_dispatch_assert_queue_fail` を起こす。NSLock 保護下の `nonisolated(unsafe)` 変数で
    // 同期アクセスを実現し、ISSUE-016 残課題 (b) を解消する。
    private let metadataLock = NSLock()
    nonisolated(unsafe) private var _lastReceivedMetadata: [String: String] = [:]

    nonisolated private func readMetadata() -> [String: String] {
        metadataLock.lock()
        defer { metadataLock.unlock() }
        return _lastReceivedMetadata
    }

    nonisolated private func writeMetadata(_ value: [String: String]) {
        metadataLock.lock()
        defer { metadataLock.unlock() }
        _lastReceivedMetadata = value
    }

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
    
    @objc nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
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

    @objc nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        let reachable = session.isReachable
        DispatchQueue.main.async {
            self.isSessionReachable = reachable
            self.lastMessage = "接続状態が変更されました: \(reachable ? "接続中" : "未接続")"
            print("WCSession reachability changed: \(reachable)")
        }
    }
    
    @objc nonisolated func session(_ session: WCSession, didReceive file: WCSessionFile) {
        // VBT 経路の振分け（Phase B / 仕様書 §6 step 12）。VBT IMU CSV は専用ルーターへ流す。
        if VBTWatchMessageRouter.isVBTIMUFile(metadata: file.metadata) {
            let router: VBTWatchMessageRouter? = DispatchQueue.main.sync { self.vbtRouter }
            if let router = router {
                let originURL = file.fileURL
                let metadata = file.metadata

                // ISSUE-023: WCSession の仕様上、本 delegate メソッドが return した瞬間に
                // `file.fileURL` が指す一時ファイルは iOS により削除される。
                // 後続の async Task（Use Case）が `importIMUFile` を呼ぶ時点で
                // 元ファイルが消失しており "no such file" で失敗していた。
                // delegate スコープ内で同期コピーし、安定 URL を Task へ受け渡す。
                let fileManager = FileManager.default
                let stableURL = fileManager.temporaryDirectory
                    .appendingPathComponent("vbt_imu_inbox_\(UUID().uuidString)_\(originURL.lastPathComponent)")
                do {
                    if fileManager.fileExists(atPath: stableURL.path) {
                        try fileManager.removeItem(at: stableURL)
                    }
                    try fileManager.copyItem(at: originURL, to: stableURL)
                } catch {
                    print("[WatchSessionGateway] VBT IMU 一時保存失敗: \(error.localizedDescription)")
                    if WCSession.isSupported() {
                        WCSession.default.sendMessage(
                            ["status": "error", "reason": "inbox copy failed: \(error.localizedDescription)"],
                            replyHandler: nil,
                            errorHandler: { _ in }
                        )
                    }
                    DispatchQueue.main.async {
                        self.isTransferring = false
                        self.lastMessage = "VBT IMU 一時保存失敗: \(error.localizedDescription)"
                    }
                    return
                }

                DispatchQueue.main.async {
                    self.isTransferring = true
                    self.lastMessage = "VBT IMU 受信中..."
                }
                router.handleIMUFileReceived(sourceURL: stableURL, metadata: metadata) { [weak self] ok, reason in
                    // ISSUE-023: 安定コピーは Use Case が importIMUFile で copyItem しただけなので
                    // この時点で削除して問題ない（成功・失敗いずれでも掃除する）。
                    try? FileManager.default.removeItem(at: stableURL)

                    // 完了通知を Watch 側に送る（仕様書 §6 step 12 ACK）
                    // ISSUE-022: 失敗時は reason を Watch 側にも返し、診断可能にする
                    var reply: [String: Any] = ok ? ["status": "ack"] : ["status": "error"]
                    if !ok, let reason = reason {
                        reply["reason"] = reason
                        print("[WatchSessionGateway] VBT IMU 受信失敗 reason=\(reason)")
                    }
                    // WCSession は Sendable ではないため、コールバック時点で再取得する。
                    if WCSession.isSupported() {
                        WCSession.default.sendMessage(reply, replyHandler: nil, errorHandler: { err in
                            print("[WatchSessionGateway] ACK sendMessage error: \(err.localizedDescription)")
                        })
                    }
                    DispatchQueue.main.async {
                        self?.isTransferring = false
                        if ok {
                            self?.lastMessage = "VBT セッション保存完了"
                        } else {
                            self?.lastMessage = "VBT IMU 受信エラー: \(reason ?? "unknown")"
                        }
                    }
                }
                return
            }
        }

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
    
    // 停止メッセージ等の replyHandler なし受信。Watch 側 sendStopRecordingSignal() が
    // replyHandler:nil で送るため、本変種が未実装だと VBTWatchMessageRouter にルーティングされない。
    @objc nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        // 仕様書 §6 step 10: 停止メッセージは replyHandler なしで送られる
        if VBTWatchMessageRouter.isStopRecordingMessage(message) {
            let router: VBTWatchMessageRouter? = DispatchQueue.main.sync { self.vbtRouter }
            router?.handleStopRecording { _ in }
            return
        }
        // それ以外の no-reply メッセージは現状ハンドルしない（既存メッセージ系は別 delegate 経路で処理）
    }

    // 即時転送のメタデータ受信
    @objc nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        // VBT メッセージの振分け（Phase B / 仕様書 §6 step 5）
        // replyHandler は WCSession delegate の制約上 non-Sendable だが、後段 Task で唯一回呼ぶため
        // SendableBox でラップして渡す（同期到達時点で他から触られないことが保証されている）。
        if VBTWatchMessageRouter.isStartRecordingMessage(message) {
            let router: VBTWatchMessageRouter? = DispatchQueue.main.sync { self.vbtRouter }
            if let router = router {
                let bridge = SendableReplyHandler(replyHandler)
                router.handleStartRecording { reply in bridge.handler(reply) }
                return
            } else {
                replyHandler(["status": "error", "reason": "VBT router not attached"])
                return
            }
        }
        if VBTWatchMessageRouter.isStopRecordingMessage(message) {
            let router: VBTWatchMessageRouter? = DispatchQueue.main.sync { self.vbtRouter }
            if let router = router {
                let bridge = SendableReplyHandler(replyHandler)
                router.handleStopRecording { reply in bridge.handler(reply) }
                return
            } else {
                replyHandler(["status": "ack"])
                return
            }
        }

        // メタデータを保存（nonisolated + NSLock 保護で同期書き込み）
        if let transferType = message["transferType"] as? String, transferType == "immediate" {
            var captured: [String: String] = ["transferType": "immediate"]
            if let fileName = message["fileName"] as? String { captured["fileName"] = fileName }
            writeMetadata(captured)
            print("Watch から受信準備完了: \(message)")
        }

        // Watchアプリに準備完了を通知
        replyHandler(["status": "ready"])
    }

    // 即時転送のデータ受信
    @objc nonisolated func session(_ session: WCSession, didReceiveMessageData messageData: Data, replyHandler: @escaping (Data) -> Void) {
        // 最後に受信したメタデータからファイル名を取得（nonisolated + NSLock 保護の同期読み出し）
        let metadata = readMetadata()
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
    @objc nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any]) {
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
    @objc nonisolated func session(_ session: WCSession, didFinish fileTransfer: WCSessionFileTransfer, error: Error?) {
        DispatchQueue.main.async {
            if let error = error {
                self.lastMessage = "ファイル転送エラー: \(error.localizedDescription)"
                print("File transfer failed: \(error.localizedDescription)")
            }
        }
    }
    
    // iOS必須メソッド
    @objc nonisolated func sessionDidBecomeInactive(_ session: WCSession) {
        print("WCSession became inactive")
    }

    @objc nonisolated func sessionDidDeactivate(_ session: WCSession) {
        print("WCSession deactivated")
        // iOSでは新しいWatchとペアリングした場合などに再アクティベートが必要
        WCSession.default.activate()
    }
}

// MARK: - SendableReplyHandler
// WCSessionDelegate の replyHandler は non-Sendable だが、本ファイルでは Task 経由で
// 1 回のみ呼ぶ用途に限定される。Swift 6 strict concurrency 下で Task に渡すため、
// `@unchecked Sendable` でラップする最小ヘルパ。同期到達のため race condition は生じない。
private final class SendableReplyHandler: @unchecked Sendable {
    let handler: ([String: Any]) -> Void
    init(_ handler: @escaping ([String: Any]) -> Void) {
        self.handler = handler
    }
}
