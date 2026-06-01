import Foundation

// MARK: - VBT Recording Output Ports
// 仕様書: .docs/VBT_GroundTruth_Tool_Spec.md §6 / §9
// Clean Architecture:
//   - Use Case 層（VBTRecordingUseCase）が依存する Output Boundary 群
//   - 実装は Watch App 側の Infrastructure 層に隔離（CoreMotion / WatchConnectivity）
//   - 内側（Use Case）は外側（CoreMotion / WCSession）を import しない
//
// ISP: クライアント（Use Case）が必要とする最小機能ごとに分割。
//   - IMURecorderPort: IMU 記録の開始・停止
//   - WatchConnectivityVBTPort: 録画開始信号送信・ファイル転送・接続状態監視
//   - RecordingFailureNotifierPort: ユーザー通知

/// IMU 記録のポート（CoreMotion 抽象化）
public protocol IMURecorderPort: AnyObject, Sendable {
    /// IMU 記録を開始する。サンプル受信ごとに `onSample` が呼ばれる。
    /// `onSample(timestamp)` は `motion.timestamp`（systemUptime 基準秒）。
    func startRecording(onSample: @escaping @Sendable (TimeInterval) -> Void)

    /// IMU 記録を停止する。
    func stopRecording()

    /// 記録した IMU データを CSV ファイルとして書き出し、URL を返す。
    /// データがなければ `nil`。
    func exportCSV() -> URL?

    /// 記録データを破棄する（エラー時のクリーンアップ）。
    func discardRecording()
}

/// 録画開始 ACK の受信結果
public enum StartRecordingAck: Sendable, Equatable {
    case acknowledged
    case timedOut
    case failed(reason: String)
}

/// ファイル転送 ACK の受信結果
public enum TransferAck: Sendable, Equatable {
    case acknowledged
    case timedOut
    case failed(reason: String)
}

/// WatchConnectivity の VBT 用ポート
public protocol WatchConnectivityVBTPort: AnyObject, Sendable {
    /// 録画開始信号を iPhone へ送信し、ACK を待機する。
    /// - Parameter timeout: ACK 受信待機タイムアウト（秒）。仕様書 §6 step 5 / §9 = 3 秒
    func sendStartRecordingSignal(timeout: TimeInterval) async -> StartRecordingAck

    /// 録画停止信号を iPhone へ送信する（ACK 待機なし）。
    func sendStopRecordingSignal()

    /// IMU CSV ファイルを iPhone へ転送し、ACK を待機する。
    /// - Parameter timeout: ACK 受信待機タイムアウト（秒）。仕様書 §6 step 12 / §9 = 60 秒
    func transferIMUFile(at url: URL, timeout: TimeInterval) async -> TransferAck

    /// iPhone との接続状態（`WCSession.isReachable` 相当）。
    var isReachable: Bool { get }
}

/// ユーザー通知のポート（仕様書 §9 異常系一覧の通知文言）
public protocol RecordingFailureNotifierPort: AnyObject, Sendable {
    func notify(_ failure: VBTRecordingFailure)
}

/// 仕様書 §9 異常系一覧に対応する記録失敗種別
public enum VBTRecordingFailure: Sendable, Equatable {
    case imuGap(intervalSeconds: TimeInterval)
    case startRecordingAckTimeout
    case reachabilityLost
    case transferTimeout
    case startBlockedByPrerequisite(missing: [String])

    /// 仕様書 §9 のユーザー通知文言
    public var userMessage: String {
        switch self {
        case .imuGap:
            return "記録失敗：IMU途絶"
        case .startRecordingAckTimeout:
            return "記録失敗：録画開始失敗"
        case .reachabilityLost:
            return "記録失敗：接続喪失"
        case .transferTimeout:
            return "記録失敗：IMU 転送タイムアウト"
        case .startBlockedByPrerequisite(let missing):
            return "開始不可：\(missing.joined(separator: ", "))"
        }
    }
}
