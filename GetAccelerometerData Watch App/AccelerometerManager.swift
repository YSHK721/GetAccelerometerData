// AccelerometerManager.swift
import CoreMotion
import Combine
import Foundation
import WatchConnectivity
import WatchKit
import SensorDataKit

/**
 * 加速度センサーから取得されるデータの構造体
 * 
 * Apple Watch上での慣性センサーデータを表現し、
 * 時系列データとして3軸方向の加速度値を保持します。
 * 
 * - Note: timestampはCFAbsoluteTimeBase（2001/1/1基準）を使用
 * - Parameters:
 *   - timestamp: データ取得時刻（TimeInterval形式）
 *   - x: X軸方向の加速度（m/s²）
 *   - y: Y軸方向の加速度（m/s²）
 *   - z: Z軸方向の加速度（m/s²）
 */
struct AccelerationData {
    let timestamp: TimeInterval
    let x: Double
    let y: Double
    let z: Double
}

/**
 * ジャイロスコープセンサーから取得される回転率データの構造体
 * 
 * Apple Watch上での角速度センサーデータを表現し、
 * 時系列データとして3軸方向の角速度値を保持します。
 * 
 * - Note: timestampはCFAbsoluteTimeBase（2001/1/1基準）を使用
 * - Parameters:
 *   - timestamp: データ取得時刻（TimeInterval形式）
 *   - x: X軸周りの角速度（rad/s）
 *   - y: Y軸周りの角速度（rad/s）
 *   - z: Z軸周りの角速度（rad/s）
 */
struct GyroscopeData {
    let timestamp: TimeInterval
    let x: Double
    let y: Double
    let z: Double
}

@MainActor
class AccelerometerManager: NSObject, ObservableObject, WCSessionDelegate {
    private let motionManager = CMMotionManager()
    private var accelerometerData: [AccelerometerRecord] = []
    private var gyroscopeData: [GyroscopeRecord] = []
    private var timer: Timer?
    private var continuityTimer: Timer?
    private var session: WCSession?
    
    /// HealthKit ワークアウトセッション管理を委譲する Gateway
    private var workoutGateway: WorkoutSessionGateway!

    /// CSV 永続化を担う Repository
    private let sensorDataRepository = SensorDataRepository()

    override init() {
        super.init()

        // Gateway は self の @Published 更新クロージャを必要とするため super.init() 後に生成
        self.workoutGateway = WorkoutSessionGateway { [weak self] newState in
            self?.workoutSessionState = newState
        }

        // センサーの利用可能状態をチェック
        checkSensorAvailability()

        setupWCSession()
        workoutGateway.requestAuthorization()
    }
    
    @Published var acceleration: (x: Double, y: Double, z: Double) = (0, 0, 0)
    @Published var gyroscope: (x: Double, y: Double, z: Double) = (0, 0, 0)
    @Published var transferStatus: String = ""
    @Published var isTransferring: Bool = false
    @Published var isRecording: Bool = false
    @Published var lastDataGapTime: Date?
    @Published var workoutSessionState: String = "未開始"
    @Published var isGyroAvailable: Bool = false
    @Published var isDeviceMotionAvailable: Bool = false

    // 実測サンプリングレート（Hz）
    @Published var accelerometerSamplingRate: Double = 0.0
    @Published var gyroscopeSamplingRate: Double = 0.0

    private var accelerometerSampleCount: Int = 0
    private var gyroscopeSampleCount: Int = 0
    private var samplingRateTimer: Timer?
    private var lastSamplingRateUpdate: Date = Date()

    /// `CMLogItem.timestamp`（systemUptime基準）→ UNIX時刻 への変換用オフセット。
    /// 記録セッション開始時に一度だけ算出してキャッシュする。毎サンプルで `Date()` を
    /// 呼び直すと、その計算自体に壁時計取得の遅延が混入してジッターが残るため。
    private var bootTimeUnix: TimeInterval = 0
    
    // センサーレコード型は `SensorRecords.swift` に分離した（AccelerometerRecord / GyroscopeRecord / CombinedSensorData）。

    // MARK: - Sensor Availability Check
    
    private func checkSensorAvailability() {
        // ジャイロスコープの利用可能状態をチェック
        isGyroAvailable = motionManager.isGyroAvailable
        isDeviceMotionAvailable = motionManager.isDeviceMotionAvailable
        
        print("=== センサー利用可能状態 ===")
        print("加速度計: \(motionManager.isAccelerometerAvailable)")
        print("ジャイロスコープ: \(motionManager.isGyroAvailable)")
        print("デバイスモーション: \(motionManager.isDeviceMotionAvailable)")
        print("磁力計: \(motionManager.isMagnetometerAvailable)")
        
        // Apple Watchの場合、デバイスモーションAPIを使用することを推奨
        if !isGyroAvailable && isDeviceMotionAvailable {
            print("注意: ジャイロスコープは直接利用できませんが、デバイスモーションAPIから回転率データを取得できます")
        }
    }
    
    private func setupWCSession() {
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
            self.session = session
        }
    }
    
    // WCSessionDelegate メソッド
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error = error {
            print("WCSession アクティベーションエラー: \(error.localizedDescription)")
        }
    }

    // ファイル転送完了時のコールバック（transferFileの完了通知）
    nonisolated func session(_ session: WCSession, didFinish fileTransfer: WCSessionFileTransfer, error: Error?) {
        // ISSUE-018 解消: VBT 経路（metadata.fileType == vbt.imuCSV）なら gateway へブリッジ。
        let isVBT = VBTGatewayRegistry.isVBTTransfer(fileTransfer)
        if isVBT {
            _ = VBTGatewayRegistry.shared.bridgeDidFinish(fileTransfer: fileTransfer, error: error)
            // VBT 経路でも一時ファイル削除と UI 状態の更新は行う
        }

        let fileURL = fileTransfer.file.fileURL

        // 転送用に書き出した一時ファイルを削除
        try? FileManager.default.removeItem(at: fileURL)

        DispatchQueue.main.async {
            self.isTransferring = false
            if let error = error {
                print("❌ ファイル転送失敗: \(error.localizedDescription)")
                self.transferStatus = "ファイル転送失敗: \(error.localizedDescription)"
            } else {
                print("✅ ファイル転送完了: \(fileURL.lastPathComponent)")
                self.transferStatus = "ファイル転送が完了しました"
            }
        }
    }

    // iPhone からの sendMessage（ACK メッセージ等）受信。VBT 用 ACK は VBTGatewayRegistry にブリッジ。
    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        if VBTGatewayRegistry.shared.bridgeAckMessage(message) {
            return
        }
    }
    
    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {
        // iOS専用実装
    }
    
    func sessionDidDeactivate(_ session: WCSession) {
        // iOS専用実装
    }
    #endif
    
    // MARK: - Workout Session Facade
    // 互換性のため AccelerometerManager に公開メソッドを残し、内部で Gateway に委譲する。

    /// ワークアウトセッションを開始する（Gateway 委譲）
    func startWorkoutSession() {
        workoutGateway.startSession()
    }

    /// ワークアウトセッションを終了する（Gateway 委譲）
    func endWorkoutSession() {
        workoutGateway.endSession()
    }

    // 加速度センサーとジャイロスコープの更新を開始
    func startUpdates() {
        // Apple Watchの場合、デバイスモーションAPIを優先的に使用
        if motionManager.isDeviceMotionAvailable {
            startDeviceMotionUpdates()
        } else {
            // フォールバック：個別のセンサーを使用
            startAccelerometerUpdates()
            startGyroscopeUpdates()
        }
        startSamplingRateTimer()
    }

    // 実測サンプリングレートを1秒ごとに算出
    private func startSamplingRateTimer() {
        accelerometerSampleCount = 0
        gyroscopeSampleCount = 0
        lastSamplingRateUpdate = Date()
        samplingRateTimer?.invalidate()
        let timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let now = Date()
            let elapsed = now.timeIntervalSince(self.lastSamplingRateUpdate)
            guard elapsed > 0 else { return }
            let accelRate = Double(self.accelerometerSampleCount) / elapsed
            let gyroRate = Double(self.gyroscopeSampleCount) / elapsed
            self.accelerometerSampleCount = 0
            self.gyroscopeSampleCount = 0
            self.lastSamplingRateUpdate = now
            self.accelerometerSamplingRate = accelRate
            self.gyroscopeSamplingRate = gyroRate
        }
        RunLoop.main.add(timer, forMode: .common)
        samplingRateTimer = timer
    }
    
    // デバイスモーションAPIを使用してセンサーデータを取得
    private func startDeviceMotionUpdates() {
        print("デバイスモーションAPIを使用してセンサーデータを取得開始")
        
        motionManager.deviceMotionUpdateInterval = 0.1 / 100
        
        let queue = OperationQueue()
        queue.qualityOfService = .userInitiated
        
        motionManager.startDeviceMotionUpdates(to: queue) { @Sendable [weak self] (motion, error) in
            guard let motion = motion else {
                if let error = error {
                    print("デバイスモーションエラー: \(error.localizedDescription)")
                }
                return
            }

            // ISSUE-017: CoreMotion コールバックは背景 OperationQueue 上で呼ばれる。
            // Swift 6 ランタイムは @MainActor 隔離された self への触れ方を厳格にチェックし、
            // 背景キューで self を触ると _dispatch_assert_queue_fail でクラッシュする。
            // Sendable な値だけを抽出してから MainActor へホップする。
            let accelTuple = (x: motion.userAcceleration.x, y: motion.userAcceleration.y, z: motion.userAcceleration.z)
            let gyroTuple = (x: motion.rotationRate.x, y: motion.rotationRate.y, z: motion.rotationRate.z)
            let sampleTimestamp = motion.timestamp

            DispatchQueue.main.async {
                guard let self = self else { return }
                self.acceleration = accelTuple
                self.gyroscope = gyroTuple
                self.accelerometerSampleCount += 1
                self.gyroscopeSampleCount += 1

                // 記録中であればデータを保存
                if self.isRecording {
                    // motion.timestamp は systemUptime 基準。bootTimeUnix を足して UNIX 時刻に変換。
                    let timestamp = self.bootTimeUnix + sampleTimestamp

                    self.accelerometerData.append(AccelerometerRecord(
                        timestamp: timestamp,
                        x: accelTuple.x,
                        y: accelTuple.y,
                        z: accelTuple.z
                    ))

                    self.gyroscopeData.append(GyroscopeRecord(
                        timestamp: timestamp,
                        x: gyroTuple.x,
                        y: gyroTuple.y,
                        z: gyroTuple.z
                    ))
                }
            }
        }
    }
    
    // 加速度センサーの更新を開始（フォールバック用）
    private func startAccelerometerUpdates() {
        print("加速度センサーの個別更新を開始")
        
        if motionManager.isAccelerometerAvailable {
            motionManager.accelerometerUpdateInterval = 1.0 / 100.0
            
            let queue = OperationQueue()
            queue.qualityOfService = .userInitiated
            
            motionManager.startAccelerometerUpdates(to: queue) { @Sendable [weak self] (data, error) in
                guard let data = data else { return }

                // ISSUE-017: 背景キューで self を触らない。Sendable 値を抽出してから MainActor へホップ。
                let accelTuple = (x: data.acceleration.x, y: data.acceleration.y, z: data.acceleration.z)
                let sampleTimestamp = data.timestamp

                DispatchQueue.main.async {
                    guard let self = self else { return }
                    self.acceleration = accelTuple
                    self.accelerometerSampleCount += 1

                    if self.isRecording {
                        // data.timestamp は CMLogItem 由来で systemUptime 基準。
                        // bootTimeUnix を足して UNIX 時刻に変換する（DeviceMotion経路と同じ変換）。
                        self.accelerometerData.append(AccelerometerRecord(
                            timestamp: self.bootTimeUnix + sampleTimestamp,
                            x: accelTuple.x,
                            y: accelTuple.y,
                            z: accelTuple.z
                        ))
                    }
                }
            }
        }
    }
    
    // ジャイロスコープの更新を開始（フォールバック用）
    private func startGyroscopeUpdates() {
        print("ジャイロスコープの個別更新を試行")
        
        if motionManager.isGyroAvailable {
            motionManager.gyroUpdateInterval = 1.0 / 100.0
            
            let queue = OperationQueue()
            queue.qualityOfService = .userInitiated
            
            motionManager.startGyroUpdates(to: queue) { @Sendable [weak self] (data, error) in
                guard let data = data else { return }

                // ISSUE-017: 背景キューで self を触らない。Sendable 値を抽出してから MainActor へホップ。
                let gyroTuple = (x: data.rotationRate.x, y: data.rotationRate.y, z: data.rotationRate.z)
                let sampleTimestamp = data.timestamp

                DispatchQueue.main.async {
                    guard let self = self else { return }
                    self.gyroscope = gyroTuple
                    self.gyroscopeSampleCount += 1

                    if self.isRecording {
                        // data.timestamp は CMLogItem 由来で systemUptime 基準。
                        // bootTimeUnix を足して UNIX 時刻に変換する（DeviceMotion経路と同じ変換）。
                        self.gyroscopeData.append(GyroscopeRecord(
                            timestamp: self.bootTimeUnix + sampleTimestamp,
                            x: gyroTuple.x,
                            y: gyroTuple.y,
                            z: gyroTuple.z
                        ))
                    }
                }
            }
        } else {
            print("ジャイロスコープが利用できません - デバイスモーションAPIを使用してください")
        }
    }
    
    // センサーの更新を停止
    func stopUpdates() {
        // すべてのモーション更新を停止
        if motionManager.isDeviceMotionActive {
            motionManager.stopDeviceMotionUpdates()
        }
        if motionManager.isAccelerometerActive {
            motionManager.stopAccelerometerUpdates()
        }
        if motionManager.isGyroActive {
            motionManager.stopGyroUpdates()
        }

        samplingRateTimer?.invalidate()
        samplingRateTimer = nil
        accelerometerSampleCount = 0
        gyroscopeSampleCount = 0
        DispatchQueue.main.async {
            self.accelerometerSamplingRate = 0.0
            self.gyroscopeSamplingRate = 0.0
        }
    }
    
    // 記録開始（改良版）
    func startRecording() {
        // データをクリア
        accelerometerData.removeAll()
        gyroscopeData.removeAll()

        // CMLogItem.timestamp → UNIX時刻 変換のためのブート時刻を1回だけ算出。
        // startUpdates() より前に必ず確定させ、初回コールバック時点で利用可能にする。
        bootTimeUnix = Date().timeIntervalSince1970 - ProcessInfo.processInfo.systemUptime

        isRecording = true

        print("センサーデータ記録開始: \(Date())")
        
        // ワークアウトセッションを開始
        startWorkoutSession()
        
        // 加速度センサーとジャイロスコープの更新を開始
        startUpdates()
        
        // 測定データの連続性をチェックするタイマー
        self.continuityTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.checkMeasurementContinuity()
        }
        RunLoop.main.add(self.continuityTimer!, forMode: .common)
        
        print("センサーデータの記録を開始: \(Date())")
    }
    
    // 記録停止
    func stopRecording() {
        isRecording = false
        
        // タイマーを停止
        continuityTimer?.invalidate()
        continuityTimer = nil
        
        // ワークアウトセッションを終了
        endWorkoutSession()
        
        // 最後にセンサー更新を停止
        stopUpdates()
        
        print("センサーデータの記録を停止: \(Date())")
        print("記録されたデータ - 加速度: \(accelerometerData.count), ジャイロ: \(gyroscopeData.count)")
    }
    
    // 測定の連続性確保
    func checkMeasurementContinuity() {
        guard isRecording, (!accelerometerData.isEmpty || !gyroscopeData.isEmpty) else { return }
        
        // 最後のデータポイントから1秒以上経過しているか確認
        let currentTime = Date().timeIntervalSince1970
        var shouldRestart = false
        
        if let lastAccelRecord = accelerometerData.last {
            if currentTime - lastAccelRecord.timestamp > 1.0 {
                shouldRestart = true
            }
        }
        
        if let lastGyroRecord = gyroscopeData.last {
            if currentTime - lastGyroRecord.timestamp > 1.0 {
                shouldRestart = true
            }
        }
        
        if shouldRestart {
            print("測定の中断を検出しました - 測定を再開します: \(Date())")
            self.lastDataGapTime = Date()
            
            // 測定の再開処理
            stopUpdates()
            startUpdates()
        }
    }
    
    /// 加速度・ジャイロデータを統合 CSV としてドキュメントディレクトリに保存する。
    /// 実際の書き出し処理は `SensorDataRepository` に委譲。
    func saveDataToCSV() -> URL? {
        guard !accelerometerData.isEmpty || !gyroscopeData.isEmpty else {
            print("保存するデータがありません")
            return nil
        }
        let combinedData = combineSensorData()
        return sensorDataRepository.saveCSV(combinedData: combinedData)
    }
    
    // iPhoneにデータを転送
    func transferDataToiPhone() {
        guard let session = session else {
            self.transferStatus = "WCSession未初期化"
            return
        }
        
        guard !accelerometerData.isEmpty || !gyroscopeData.isEmpty else {
            print("転送データチェック - 加速度データ数: \(accelerometerData.count), ジャイロデータ数: \(gyroscopeData.count)")
            self.transferStatus = "転送するデータがありません"
            return
        }
        
        print("転送開始 - 加速度データ数: \(accelerometerData.count), ジャイロデータ数: \(gyroscopeData.count)")
        
        // 統合されたセンサーデータをJSON形式で転送
        do {
            let combinedData = combineSensorData()
            
            // JSONエンコーダーでデータを変換
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let jsonData = try encoder.encode(combinedData)
            
            print("JSONデータ作成完了 - サイズ: \(jsonData.count) bytes, データ数: \(combinedData.count)")
            
            // PayloadSizeValidatorを使用して転送方法を決定
            let validator = PayloadSizeValidator()
            validator.logSizeInfo(for: jsonData, label: "センサーデータ")
            
            let recommendedMethod = validator.recommendedTransferMethod(for: jsonData)
            
            self.isTransferring = true
            self.transferStatus = "データを転送中... (\(recommendedMethod.description))"
            
            // ファイル名を生成
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyyMMdd_HHmmss"
            let timeStamp = formatter.string(from: Date())
            let fileName = "sensor_data_\(timeStamp).csv"
            
            // PayloadSizeValidatorの推奨に基づいて転送方法を選択
            switch recommendedMethod {
            case .immediate:
                // 即時転送（64KB制限内かつ接続可能な場合）
                if session.isReachable {
                    performImmediateTransfer(jsonData: jsonData, fileName: fileName, session: session)
                } else {
                    // 接続されていない場合はバックグラウンド転送にフォールバック
                    print("接続されていないため、バックグラウンド転送にフォールバック")
                    performBackgroundTransfer(jsonData: jsonData, fileName: fileName, session: session)
                }
                
            case .background:
                // バックグラウンド転送（大容量データまたは接続状態に関係なく）
                print("大容量データのため、バックグラウンド転送を使用")
                performBackgroundTransfer(jsonData: jsonData, fileName: fileName, session: session)

            case .file:
                // 128KB超のデータはファイル転送（サイズ制限なし）
                print("128KB超のため、ファイル転送を使用")
                performFileTransfer(jsonData: jsonData, fileName: fileName, session: session)
            }
            
        } catch {
            DispatchQueue.main.async {
                self.isTransferring = false
                self.transferStatus = "データの変換エラー: \(error.localizedDescription)"
            }
            print("JSONエンコードエラー: \(error)")
        }
    }
    private func combineSensorData() -> [CombinedSensorData] {
        print("データ統合開始 - 加速度: \(accelerometerData.count), ジャイロ: \(gyroscopeData.count)")
        
        var combinedData: [CombinedSensorData] = []
        
        // タイムスタンプでソートされたデータを作成
        let sortedAccelData = accelerometerData.sorted { $0.timestamp < $1.timestamp }
        let sortedGyroData = gyroscopeData.sorted { $0.timestamp < $1.timestamp }
        
        var accelIndex = 0
        var gyroIndex = 0
        
        while accelIndex < sortedAccelData.count && gyroIndex < sortedGyroData.count {
            let accelRecord = sortedAccelData[accelIndex]
            let gyroRecord = sortedGyroData[gyroIndex]
            
            // タイムスタンプの差が0.05秒以内なら同じデータポイントとして扱う
            let timeDiff = abs(accelRecord.timestamp - gyroRecord.timestamp)
            
            if timeDiff <= 0.05 {
                // 合成値を計算
                let accelMagnitude = sqrt(pow(accelRecord.x, 2) + pow(accelRecord.y, 2) + pow(accelRecord.z, 2))
                let gyroMagnitude = sqrt(pow(gyroRecord.x, 2) + pow(gyroRecord.y, 2) + pow(gyroRecord.z, 2))
                
                let combined = CombinedSensorData(
                    timestamp: accelRecord.timestamp,
                    accelX: accelRecord.x,
                    accelY: accelRecord.y,
                    accelZ: accelRecord.z,
                    accelMagnitude: accelMagnitude,
                    gyroX: gyroRecord.x,
                    gyroY: gyroRecord.y,
                    gyroZ: gyroRecord.z,
                    gyroMagnitude: gyroMagnitude
                )
                
                combinedData.append(combined)
                accelIndex += 1
                gyroIndex += 1
            } else if accelRecord.timestamp < gyroRecord.timestamp {
                // 加速度データのみ（ジャイロスコープデータは0で補填）
                let accelMagnitude = sqrt(pow(accelRecord.x, 2) + pow(accelRecord.y, 2) + pow(accelRecord.z, 2))
                
                let combined = CombinedSensorData(
                    timestamp: accelRecord.timestamp,
                    accelX: accelRecord.x,
                    accelY: accelRecord.y,
                    accelZ: accelRecord.z,
                    accelMagnitude: accelMagnitude,
                    gyroX: 0.0,
                    gyroY: 0.0,
                    gyroZ: 0.0,
                    gyroMagnitude: 0.0
                )
                
                combinedData.append(combined)
                accelIndex += 1
            } else {
                // ジャイロスコープデータのみ（加速度データは0で補填）
                let gyroMagnitude = sqrt(pow(gyroRecord.x, 2) + pow(gyroRecord.y, 2) + pow(gyroRecord.z, 2))
                
                let combined = CombinedSensorData(
                    timestamp: gyroRecord.timestamp,
                    accelX: 0.0,
                    accelY: 0.0,
                    accelZ: 0.0,
                    accelMagnitude: 0.0,
                    gyroX: gyroRecord.x,
                    gyroY: gyroRecord.y,
                    gyroZ: gyroRecord.z,
                    gyroMagnitude: gyroMagnitude
                )
                
                combinedData.append(combined)
                gyroIndex += 1
            }
        }
        
        // 残りのデータを処理
        while accelIndex < sortedAccelData.count {
            let accelRecord = sortedAccelData[accelIndex]
            let accelMagnitude = sqrt(pow(accelRecord.x, 2) + pow(accelRecord.y, 2) + pow(accelRecord.z, 2))
            
            let combined = CombinedSensorData(
                timestamp: accelRecord.timestamp,
                accelX: accelRecord.x,
                accelY: accelRecord.y,
                accelZ: accelRecord.z,
                accelMagnitude: accelMagnitude,
                gyroX: 0.0,
                gyroY: 0.0,
                gyroZ: 0.0,
                gyroMagnitude: 0.0
            )
            
            combinedData.append(combined)
            accelIndex += 1
        }
        
        while gyroIndex < sortedGyroData.count {
            let gyroRecord = sortedGyroData[gyroIndex]
            let gyroMagnitude = sqrt(pow(gyroRecord.x, 2) + pow(gyroRecord.y, 2) + pow(gyroRecord.z, 2))
            
            let combined = CombinedSensorData(
                timestamp: gyroRecord.timestamp,
                accelX: 0.0,
                accelY: 0.0,
                accelZ: 0.0,
                accelMagnitude: 0.0,
                gyroX: gyroRecord.x,
                gyroY: gyroRecord.y,
                gyroZ: gyroRecord.z,
                gyroMagnitude: gyroMagnitude
            )
            
            combinedData.append(combined)
            gyroIndex += 1
        }
        
        let sortedData = combinedData.sorted { $0.timestamp < $1.timestamp }
        print("データ統合完了 - 統合データ数: \(sortedData.count)")
        return sortedData
    }
    
    // MARK: - Private Transfer Methods
    
    /// 即時転送の実行（sendMessageData使用）
    private func performImmediateTransfer(jsonData: Data, fileName: String, session: WCSession) {
        let validator = PayloadSizeValidator()
        
        // 64KB制限のバリデーション
        do {
            try validator.validateImmediateTransfer(jsonData)
        } catch PayloadSizeValidator.PayloadSizeError.exceedsImmediateTransferLimit(let actualSize, let limit) {
            print("⚠️ 即時転送制限超過: \(actualSize) bytes > \(limit) bytes")
            print("バックグラウンド転送にフォールバック")
            performBackgroundTransfer(jsonData: jsonData, fileName: fileName, session: session)
            return
        } catch {
            DispatchQueue.main.async {
                self.isTransferring = false
                self.transferStatus = "転送前バリデーションエラー: \(error.localizedDescription)"
            }
            return
        }
        
        // 1. 最初にメタデータを送信
        session.sendMessage(["transferType": "immediate", "fileName": fileName], replyHandler: { [weak self] reply in
            guard let self = self else { return }
            
            if reply["status"] as? String == "ready" {
                // 2. メタデータの受信が確認できたらJSONデータを送信
                session.sendMessageData(jsonData, replyHandler: { [weak self] _ in
                    guard let self = self else { return }
                    
                    DispatchQueue.main.async {
                        self.isTransferring = false
                        self.transferStatus = "即時転送が完了しました"
                        print("✅ 即時転送成功: \(jsonData.count) bytes")
                    }
                }, errorHandler: { [weak self] error in
                    guard let self = self else { return }
                    
                    print("❌ 即時転送エラー: \(error.localizedDescription)")
                    
                    // "Payload is too large" エラーの場合はバックグラウンド転送にフォールバック
                    if error.localizedDescription.contains("Payload is too large") ||
                       error.localizedDescription.contains("too large") {
                        print("ペイロードサイズエラーによりバックグラウンド転送にフォールバック")
                        self.performBackgroundTransfer(jsonData: jsonData, fileName: fileName, session: session)
                    } else {
                        DispatchQueue.main.async {
                            self.isTransferring = false
                            self.transferStatus = "即時転送エラー: \(error.localizedDescription)"
                        }
                    }
                })
            } else {
                DispatchQueue.main.async {
                    self.isTransferring = false
                    self.transferStatus = "iPhone側の準備が完了していません"
                }
            }
        }, errorHandler: { [weak self] error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.isTransferring = false
                self.transferStatus = "メタデータ送信エラー: \(error.localizedDescription)"
            }
        })
    }
    
    /// バックグラウンド転送の実行（transferUserInfo使用）
    private func performBackgroundTransfer(jsonData: Data, fileName: String, session: WCSession) {
        let validator = PayloadSizeValidator()

        // 128KB制限のバリデーション
        do {
            try validator.validateBackgroundTransfer(jsonData)
        } catch PayloadSizeValidator.PayloadSizeError.exceedsBackgroundTransferLimit(let actualSize, let limit) {
            print("⚠️ バックグラウンド転送制限超過: \(actualSize) bytes > \(limit) bytes - ファイル転送にフォールバック")
            performFileTransfer(jsonData: jsonData, fileName: fileName, session: session)
            return
        } catch {
            DispatchQueue.main.async {
                self.isTransferring = false
                self.transferStatus = "転送前バリデーションエラー: \(error.localizedDescription)"
            }
            return
        }
        
        // バックグラウンド転送（iPhoneが直接接続されていなくても転送可能）
        // デバイスが後で接続された際に自動的に転送される
        let userInfo: [String: Any] = [
            "fileData": jsonData,
            "fileName": fileName,
            "dataType": "json",
            "transferSize": jsonData.count,
            "transferTimestamp": Date().timeIntervalSince1970
        ]
        
        let transferID = session.transferUserInfo(userInfo)
        print("✅ バックグラウンド転送開始: transferID = \(transferID), サイズ = \(jsonData.count) bytes")
        validator.logSizeInfo(for: jsonData, label: "バックグラウンド転送データ")
        
        DispatchQueue.main.async {
            self.isTransferring = false
            self.transferStatus = "データをキューに追加しました（バックグラウンド転送: \(String(format: "%.1f", Double(jsonData.count) / 1024.0)) KB）"
        }
    }

    /// ファイル転送の実行（transferFile使用、サイズ制限なし）
    private func performFileTransfer(jsonData: Data, fileName: String, session: WCSession) {
        // 一時ディレクトリに転送用ファイルを書き出す（転送完了後に削除）
        let tempDirectory = FileManager.default.temporaryDirectory
        let tempURL = tempDirectory.appendingPathComponent("\(UUID().uuidString)_\(fileName)")

        do {
            try jsonData.write(to: tempURL, options: .atomic)
        } catch {
            print("❌ 一時ファイル書き込み失敗: \(error.localizedDescription)")
            DispatchQueue.main.async {
                self.isTransferring = false
                self.transferStatus = "ファイル転送準備エラー: \(error.localizedDescription)"
            }
            return
        }

        let metadata: [String: Any] = [
            "fileName": fileName,
            "dataType": "json",
            "transferSize": jsonData.count,
            "transferTimestamp": Date().timeIntervalSince1970
        ]

        let transfer = session.transferFile(tempURL, metadata: metadata)
        let sizeKB = Double(jsonData.count) / 1024.0
        print("✅ ファイル転送開始: \(jsonData.count) bytes (\(String(format: "%.1f", sizeKB)) KB), file: \(tempURL.lastPathComponent), inProgress: \(transfer.isTransferring)")

        DispatchQueue.main.async {
            self.transferStatus = "ファイル転送中... (\(String(format: "%.1f", sizeKB)) KB)"
        }
    }
}

