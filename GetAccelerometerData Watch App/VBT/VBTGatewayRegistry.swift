import Foundation
import WatchConnectivity

// MARK: - VBTGatewayRegistry
// ISSUE-018 解消: Watch 側 `WCSession.delegate` を既存 `AccelerometerManager` が所有しているため、
// `WCSessionVBTGateway` 単体では `didFinish fileTransfer` コールバックを受け取れない。
// 共有 registry を経由して既存 delegate から VBT gateway に転送完了をブリッジする。
//
// SRP: 「VBT 用 gateway のグローバル参照保持 + 完了通知ブリッジ」のみ。
// スレッドセーフ: NSLock 保護。
//
// 仕様書: .docs/VBT_GroundTruth_Tool_Spec.md §6 step 12（IMU 転送 ACK 経路）
final class VBTGatewayRegistry: @unchecked Sendable {

    static let shared = VBTGatewayRegistry()

    private let lock = NSLock()
    private weak var gateway: WCSessionVBTGateway?

    private init() {}

    func register(_ gateway: WCSessionVBTGateway) {
        lock.lock(); defer { lock.unlock() }
        self.gateway = gateway
    }

    func unregister(_ gateway: WCSessionVBTGateway) {
        lock.lock(); defer { lock.unlock() }
        if self.gateway === gateway {
            self.gateway = nil
        }
    }

    /// 指定された fileTransfer が VBT 経路（metadata.fileType == vbt.imuCSV）かを判定。
    static func isVBTTransfer(_ fileTransfer: WCSessionFileTransfer) -> Bool {
        guard let metadata = fileTransfer.file.metadata,
              let fileType = metadata["fileType"] as? String else { return false }
        return fileType == WCSessionVBTGateway.transferFileType
    }

    /// 既存 WCSession delegate から呼ばれるブリッジ。
    /// VBT 転送なら登録済 gateway の continuation を再開する。
    func bridgeDidFinish(fileTransfer: WCSessionFileTransfer, error: Error?) -> Bool {
        guard VBTGatewayRegistry.isVBTTransfer(fileTransfer) else { return false }
        let target: WCSessionVBTGateway? = {
            lock.lock(); defer { lock.unlock() }
            return gateway
        }()
        guard let gateway = target else { return false }
        gateway.notifyTransferDidFinish(error: error)
        return true
    }

    /// 受信した reply メッセージから ACK 状態を gateway に伝える（iPhone 側からの `["status": "ack"]`）。
    /// transferFile の ACK は file transfer の didFinish と iPhone 側 sendMessage 両方で来うる。
    func bridgeAckMessage(_ message: [String: Any]) -> Bool {
        guard let status = message["status"] as? String else { return false }
        let target: WCSessionVBTGateway? = {
            lock.lock(); defer { lock.unlock() }
            return gateway
        }()
        guard let gateway = target else { return false }
        if status == "ack" {
            gateway.notifyTransferAck()
            return true
        } else if status == "error" {
            gateway.notifyTransferFailure(reason: message["reason"] as? String ?? "unknown")
            return true
        }
        return false
    }
}
