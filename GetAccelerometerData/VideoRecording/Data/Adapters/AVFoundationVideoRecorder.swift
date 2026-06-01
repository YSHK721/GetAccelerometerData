import Foundation
import AVFoundation
import SensorDataKit

// MARK: - AVFoundationVideoRecorder
// VBT Ground Truth Tool Phase B: iPhone 側 AVFoundation 録画アダプタ。
// 仕様書: .docs/VBT_GroundTruth_Tool_Spec.md §4 動画フォーマット = 1080p / 60fps / H.264 / .mp4
//   仕様書 §4「同期精度を最優先」のため、60fps 確保失敗時は自動降格せず error 返却。
//
// Clean Architecture:
//   - Infrastructure 層: AVCaptureSession / AVCaptureMovieFileOutput 隔離
//   - Use Case（VBTReceptionUseCase）から `VideoRecorderPort` 経由でのみ参照される
//
// SRP: AVFoundation の 1080p / 60fps セッション構築・録画開始・停止のみ。
//       メタ入力やセッションフォルダ管理は本クラスの責務外。
final class AVFoundationVideoRecorder: NSObject, VideoRecorderPort, @unchecked Sendable {

    private let lock = NSLock()
    private var captureSession: AVCaptureSession?
    private var movieFileOutput: AVCaptureMovieFileOutput?
    private var currentRecordingURL: URL?
    private var stopContinuation: CheckedContinuation<VideoStopOutcome, Never>?

    // MARK: - VideoRecorderPort

    func startRecording() async -> Result<VideoStartContext, VideoRecorderError> {
        // 1) 権限確認
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            break
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            if !granted { return .failure(.permissionDenied) }
        case .denied, .restricted:
            return .failure(.permissionDenied)
        @unknown default:
            return .failure(.permissionDenied)
        }

        // 2) セッション構築
        let session = AVCaptureSession()
        session.beginConfiguration()
        session.sessionPreset = .hd1920x1080

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            session.commitConfiguration()
            return .failure(.sessionSetupFailed("no back camera"))
        }

        // 3) 1080p / 60fps 対応フォーマット選択
        let target = Self.find1080p60Format(for: device)
        guard let format = target else {
            session.commitConfiguration()
            // 仕様書 §4「同期精度を最優先」: 自動降格しない
            return .failure(.unsupported60fps)
        }

        do {
            try device.lockForConfiguration()
            device.activeFormat = format
            device.activeVideoMinFrameDuration = CMTime(value: 1, timescale: 60)
            device.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: 60)
            device.unlockForConfiguration()
        } catch {
            session.commitConfiguration()
            return .failure(.sessionSetupFailed("device configuration: \(error.localizedDescription)"))
        }

        // 4) 入力
        do {
            let videoInput = try AVCaptureDeviceInput(device: device)
            if session.canAddInput(videoInput) {
                session.addInput(videoInput)
            } else {
                session.commitConfiguration()
                return .failure(.sessionSetupFailed("cannot add video input"))
            }
        } catch {
            session.commitConfiguration()
            return .failure(.sessionSetupFailed("video input init: \(error.localizedDescription)"))
        }

        // マイク（クラップ同期マーカー音録音のため）
        if let mic = AVCaptureDevice.default(for: .audio) {
            if let audioInput = try? AVCaptureDeviceInput(device: mic), session.canAddInput(audioInput) {
                session.addInput(audioInput)
            }
        }

        // 5) 出力（H.264/MP4）
        let output = AVCaptureMovieFileOutput()
        if session.canAddOutput(output) {
            session.addOutput(output)
        } else {
            session.commitConfiguration()
            return .failure(.sessionSetupFailed("cannot add movie file output"))
        }
        if let connection = output.connection(with: .video),
           output.availableVideoCodecTypes.contains(.h264) {
            output.setOutputSettings([AVVideoCodecKey: AVVideoCodecType.h264], for: connection)
        }

        session.commitConfiguration()
        session.startRunning()

        // 録画ファイル URL（一時ディレクトリ。完了後 SessionStorePort が最終フォルダへ import）
        let tempDir = FileManager.default.temporaryDirectory
        let url = tempDir.appendingPathComponent("vbt_video_\(UUID().uuidString).mp4")

        // ISO8601 録画開始時刻
        let iso = Self.iso8601Formatter.string(from: Date())

        withLock {
            captureSession = session
            movieFileOutput = output
            currentRecordingURL = url
        }

        output.startRecording(to: url, recordingDelegate: self)
        return .success(VideoStartContext(videoStartIso8601: iso))
    }

    func stopRecording() async -> VideoStopOutcome {
        let output: AVCaptureMovieFileOutput? = withLock { movieFileOutput }
        guard let output = output, output.isRecording else {
            return .failure(reason: "recorder not running")
        }
        return await withCheckedContinuation { (cont: CheckedContinuation<VideoStopOutcome, Never>) in
            withLock { stopContinuation = cont }
            output.stopRecording()
        }
    }

    private func withLock<T>(_ body: () -> T) -> T {
        lock.lock(); defer { lock.unlock() }
        return body()
    }

    // MARK: - Helpers

    nonisolated(unsafe) private static let iso8601Formatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static func find1080p60Format(for device: AVCaptureDevice) -> AVCaptureDevice.Format? {
        let target = CMVideoDimensions(width: 1920, height: 1080)
        for fmt in device.formats {
            let dims = CMVideoFormatDescriptionGetDimensions(fmt.formatDescription)
            guard dims.width == target.width && dims.height == target.height else { continue }
            for range in fmt.videoSupportedFrameRateRanges {
                if range.maxFrameRate >= 60.0 && range.minFrameRate <= 60.0 {
                    return fmt
                }
            }
        }
        return nil
    }

    private func teardownSession() {
        lock.lock()
        captureSession?.stopRunning()
        captureSession = nil
        movieFileOutput = nil
        lock.unlock()
    }
}

// MARK: - AVCaptureFileOutputRecordingDelegate

extension AVFoundationVideoRecorder: AVCaptureFileOutputRecordingDelegate {

    func fileOutput(
        _ output: AVCaptureFileOutput,
        didFinishRecordingTo outputFileURL: URL,
        from connections: [AVCaptureConnection],
        error: Error?
    ) {
        let cont: CheckedContinuation<VideoStopOutcome, Never>? = {
            lock.lock(); defer { lock.unlock() }
            let c = stopContinuation
            stopContinuation = nil
            return c
        }()
        teardownSession()

        if let error = error {
            cont?.resume(returning: .failure(reason: error.localizedDescription))
        } else {
            cont?.resume(returning: .success(videoURL: outputFileURL))
        }
    }
}
