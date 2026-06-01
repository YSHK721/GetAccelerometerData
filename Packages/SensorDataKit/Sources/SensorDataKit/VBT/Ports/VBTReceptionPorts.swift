import Foundation

// MARK: - VBT Reception Ports
// 仕様書: .docs/VBT_GroundTruth_Tool_Spec.md §6 / §7
// Clean Architecture: iPhone 側 Use Case の Output Boundary 群。
//   実装は iOS app の Infrastructure（AVFoundation / FileManager / Clock）に隔離する。
//
// ISP: クライアントごとに最小機能。
//   - VideoRecorderPort: AVFoundation 隔離
//   - SessionStorePort: FileManager 隔離（セッションフォルダ・meta.json 書き出し・PENDING フォルダ削除）
//   - ClockPort: 現在時刻取得（テスト時固定可）

// MARK: - VideoRecorderPort

public struct VideoStartContext: Sendable, Equatable {
    public let videoStartIso8601: String
    public init(videoStartIso8601: String) {
        self.videoStartIso8601 = videoStartIso8601
    }
}

public enum VideoRecorderError: Error, Equatable, Sendable {
    /// 60fps 設定が端末で未サポート。仕様書 §4 「同期精度を最優先」のため自動降格しない。
    case unsupported60fps
    /// 1080p 解像度が未サポート
    case unsupported1080p
    /// カメラ権限が未許可
    case permissionDenied
    /// メタ入力が完了していない（メタ入力前に開始要求が来た等）
    case notReadyForMetaInput
    /// AVFoundation 初期化エラー（汎用）
    case sessionSetupFailed(String)
}

public enum VideoStopOutcome: Sendable, Equatable {
    case success(videoURL: URL)
    case failure(reason: String)
}

public protocol VideoRecorderPort: AnyObject, Sendable {
    /// 録画を開始する。1080p/60fps が確保できない場合は failure を返す。
    func startRecording() async -> Result<VideoStartContext, VideoRecorderError>

    /// 録画を停止し、保存先の URL を返す。
    func stopRecording() async -> VideoStopOutcome
}

// MARK: - SessionStorePort

public protocol SessionStorePort: AnyObject, Sendable {
    /// セッションフォルダを作成する。
    func createFolder(name: String) throws -> URL

    /// 受信した IMU CSV をフォルダへ配置し、最終 URL を返す。
    func importIMUFile(from source: URL, to folder: URL) throws -> URL

    /// 録画ファイルをフォルダへ配置し、最終 URL を返す。
    func importVideoFile(from source: URL, to folder: URL) throws -> URL

    /// meta.json を `FileManager.replaceItemAt` 経由でアトミック書き込み。
    func writeMetaJSON(_ payload: MetaJSONPayload, to folder: URL) throws

    /// すべての成果物が揃ったタイミングで呼ぶ最終化（必要なら inode flush 等）。
    func finalize(folder: URL) throws

    /// 欠落時のフォルダ削除（PENDING のまま残さない）。
    func delete(folder: URL)
}

// MARK: - ClockPort

public protocol ClockPort: AnyObject, Sendable {
    func currentDate() -> Date
}
