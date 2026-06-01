import Foundation
import WatchConnectivity
import SensorDataKit

// MARK: - WCSessionVBTGateway
// 仕様書: .docs/VBT_GroundTruth_Tool_Spec.md §6 step 5 / step 12 / §9
//
// Watch 側 WatchConnectivity アダプタ。`WatchConnectivityVBTPort` を実装する。
//   - sendStartRecordingSignal: `sendMessage` で録画開始信号送信、ACK を 3s 以内に受信
//   - transferIMUFile: `transferFile` でファイル送信、ACK を 60s 以内に受信
//   - isReachable: WCSession.isReachable をそのまま公開
//
// 既存の AccelerometerManager / SessionDelegate との競合を避けるため、本クラスは
//   - 独自に WCSession.delegate を保持しないか、または既存デリゲートと協調する
//   Phase A では最小実装として「activate された default session」を借用し、
//   メッセージ送受信のみを行う。delegate は別途。
//
// Note: 録画開始 ACK / 転送 ACK の受領は WCSession デリゲートのコールバック経由なので、
//   本クラスは外部から `notifyStartRecordingAckReceived` / `notifyTransferAckReceived` を呼ばれる API を公開し、
//   デリゲート実装側（既存 AccelerometerManager 等）から橋渡しを受ける。

final class WCSessionVBTGateway: NSObject, WatchConnectivityVBTPort, @unchecked Sendable {

    static let startMessageKey = "vbt.startRecording"
    static let stopMessageKey = "vbt.stopRecording"
    static let transferFileType = "vbt.imuCSV"

    private let lock = NSLock()
    private var pendingStartContinuation: CheckedContinuation<StartRecordingAck, Never>?
    private var pendingTransferContinuation: CheckedContinuation<TransferAck, Never>?
    private var session: WCSession? { WCSession.isSupported() ? WCSession.default : nil }

    var isReachable: Bool {
        return session?.isReachable ?? false
    }

    // MARK: - WatchConnectivityVBTPort

    func sendStartRecordingSignal(timeout: TimeInterval) async -> StartRecordingAck {
        guard let session = session else {
            return .failed(reason: "WCSession unsupported")
        }
        guard session.isReachable else {
            return .failed(reason: "iPhone not reachable")
        }

        // Continuation を準備
        return await withCheckedContinuation { (continuation: CheckedContinuation<StartRecordingAck, Never>) in
            lock.lock()
            pendingStartContinuation = continuation
            lock.unlock()

            let message: [String: Any] = [
                Self.startMessageKey: true,
                "sentAt": Date().timeIntervalSince1970
            ]

            session.sendMessage(message, replyHandler: { [weak self] reply in
                let ack: StartRecordingAck
                if let status = reply["status"] as? String, status == "ack" {
                    ack = .acknowledged
                } else {
                    ack = .failed(reason: "invalid reply: \(reply)")
                }
                self?.resumeStart(with: ack)
            }, errorHandler: { [weak self] error in
                self?.resumeStart(with: .failed(reason: error.localizedDescription))
            })

            // タイムアウトタスク
            Task { [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                self?.resumeStart(with: .timedOut)
            }
        }
    }

    func sendStopRecordingSignal() {
        guard let session = session, session.isReachable else { return }
        session.sendMessage([Self.stopMessageKey: true], replyHandler: nil, errorHandler: { error in
            print("[WCSessionVBTGateway] stop message error: \(error.localizedDescription)")
        })
    }

    func transferIMUFile(at url: URL, timeout: TimeInterval) async -> TransferAck {
        guard let session = session else {
            return .failed(reason: "WCSession unsupported")
        }

        return await withCheckedContinuation { (continuation: CheckedContinuation<TransferAck, Never>) in
            lock.lock()
            pendingTransferContinuation = continuation
            lock.unlock()

            let metadata: [String: Any] = [
                "fileType": Self.transferFileType,
                "fileName": url.lastPathComponent,
                "sentAt": Date().timeIntervalSince1970
            ]
            _ = session.transferFile(url, metadata: metadata)

            // タイムアウトタスク
            Task { [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                self?.resumeTransfer(with: .timedOut)
            }
        }
    }

    // MARK: - Bridge from WCSessionDelegate (called by AccelerometerManager or similar)

    /// 転送完了コールバックから呼ばれる。エラーなしなら ACK 扱い。
    func notifyTransferDidFinish(error: Error?) {
        if let error = error {
            resumeTransfer(with: .failed(reason: error.localizedDescription))
        } else {
            resumeTransfer(with: .acknowledged)
        }
    }

    // MARK: - Private

    private func resumeStart(with ack: StartRecordingAck) {
        lock.lock()
        let continuation = pendingStartContinuation
        pendingStartContinuation = nil
        lock.unlock()
        continuation?.resume(returning: ack)
    }

    private func resumeTransfer(with ack: TransferAck) {
        lock.lock()
        let continuation = pendingTransferContinuation
        pendingTransferContinuation = nil
        lock.unlock()
        continuation?.resume(returning: ack)
    }
}
