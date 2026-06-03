import Foundation
import WatchConnectivity
import SensorDataKit

// MARK: - VBTWatchMessageRouter
// VBT Ground Truth Tool Phase B: Watch → iPhone の VBT メッセージ振分け。
// 仕様書: .docs/VBT_GroundTruth_Tool_Spec.md §6 step 5 / step 12
//   - "vbt.startRecording" メッセージを受信 → 録画開始要求として Use Case に流す
//   - "vbt.imuCSV" メタ付きの transferFile を受信 → IMU CSV として Use Case に流す
//
// SRP: メッセージ識別と Use Case 起動のみを担う。AVFoundation / FileManager 詳細は本クラスに含めない。
//
// Reentrancy: WCSessionDelegate のコールバックは背景キューで呼ばれるため、
//   Use Case 呼び出しは Task 経由で非同期化し、ハンドラ自体は即座に返す。
//   replyHandler は同期的に呼ぶ必要があるため、ack/error 判定は await 完了後に確定する。
final class VBTWatchMessageRouter: @unchecked Sendable {

    static let startMessageKey = "vbt.startRecording"
    static let stopMessageKey = "vbt.stopRecording"
    static let transferFileType = "vbt.imuCSV"

    // metadata key for `imu_start_timestamp`（Watch 側 transferFile metadata 経由）
    static let imuStartTimestampKey = "imu_start_timestamp"
    static let fileTypeKey = "fileType"
    static let fileNameKey = "fileName"

    /// ISSUE-021: Use Case 状態遷移を Presentation 層へ広報するための Notification。
    /// `VBTReceptionUseCase.state` は `@Published` ではないため、本通知が
    /// View Model 側の `refreshStatus()` 再実行トリガとして機能する。
    static let stateDidChangeNotification = Notification.Name("VBTWatchMessageRouter.stateDidChange")

    private let useCase: VBTReceptionUseCase

    init(useCase: VBTReceptionUseCase) {
        self.useCase = useCase
    }

    /// ISSUE-021: Use Case の await 完了直後に呼ぶ。NotificationCenter は thread-safe で
    /// あり、購読側（View Model）が `@MainActor` で `refreshStatus()` を実行する。
    ///
    /// ISSUE-022: 失敗時の `reason` を userInfo に載せて View Model 側へ伝搬する。
    /// 仕様書の `.failed` 表示「再試行してください」だけでは原因不明のため診断不能だった。
    private func notifyStateDidChange(reason: String? = nil) {
        var userInfo: [AnyHashable: Any] = [:]
        if let reason = reason {
            userInfo["reason"] = reason
        }
        NotificationCenter.default.post(
            name: Self.stateDidChangeNotification,
            object: nil,
            userInfo: userInfo.isEmpty ? nil : userInfo
        )
    }

    /// `vbt.startRecording` のメッセージか判定
    static func isStartRecordingMessage(_ message: [String: Any]) -> Bool {
        return message[startMessageKey] as? Bool == true
    }

    /// `vbt.stopRecording` のメッセージか判定
    static func isStopRecordingMessage(_ message: [String: Any]) -> Bool {
        return message[stopMessageKey] as? Bool == true
    }

    /// `transferFile` の metadata が VBT IMU CSV か判定
    static func isVBTIMUFile(metadata: [String: Any]?) -> Bool {
        guard let metadata = metadata else { return false }
        return (metadata[fileTypeKey] as? String) == transferFileType
    }

    /// `vbt.startRecording` のハンドリング。reply は Use Case の応答に基づく。
    /// replyHandler は WCSession が `@Sendable` 引数として要求するため、Task 経由で非同期化する。
    func handleStartRecording(replyHandler: @escaping @Sendable ([String: Any]) -> Void) {
        Task { [useCase] in
            let result = await useCase.handleStartRecordingRequest()
            switch result {
            case .acknowledged:
                self.notifyStateDidChange()
                replyHandler(["status": "ack"])
            case .error(let reason):
                print("[VBTWatchMessageRouter] start error: \(reason)")
                self.notifyStateDidChange(reason: reason)
                replyHandler(["status": "error", "reason": reason])
            }
        }
    }

    /// `vbt.stopRecording` のハンドリング（ACK のみ即座に返す）。
    func handleStopRecording(replyHandler: @escaping @Sendable ([String: Any]) -> Void) {
        Task { [useCase] in
            await useCase.handleStopRecordingRequest()
            self.notifyStateDidChange()
            replyHandler(["status": "ack"])
        }
    }

    /// IMU CSV ファイル受信完了時のハンドリング。
    /// metadata["imu_start_timestamp"] が無い場合は 0 として扱う（後段で labels.json 生成時にエラー検知）。
    func handleIMUFileReceived(sourceURL: URL, metadata: [String: Any]?, completion: @escaping @Sendable (Bool, String?) -> Void) {
        let imuStart: TimeInterval = (metadata?[Self.imuStartTimestampKey] as? Double) ?? 0
        Task { [useCase] in
            let result = await useCase.handleIMUFileReceived(source: sourceURL, imuStartTimestamp: imuStart)
            switch result {
            case .acknowledged:
                self.notifyStateDidChange()
                completion(true, nil)
            case .error(let reason):
                print("[VBTWatchMessageRouter] IMU receive error: \(reason)")
                self.notifyStateDidChange(reason: reason)
                completion(false, reason)
            }
        }
    }
}
