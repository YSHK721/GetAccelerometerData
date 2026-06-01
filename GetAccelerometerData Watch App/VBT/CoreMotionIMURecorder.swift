import Foundation
import CoreMotion
import SensorDataKit

// MARK: - CoreMotionIMURecorder
// 仕様書: .docs/VBT_GroundTruth_Tool_Spec.md §6 step 4
//   deviceMotionUpdateInterval = 0.01（100Hz）
//   timestamp = motion.timestamp（systemUptime 基準秒）
//
// Clean Architecture:
//   - Infrastructure 層: CoreMotion 隔離アダプタ
//   - SensorDataKit の `IMURecorderPort` を実装し、Use Case から DIP で参照される
//
// ISSUE-017 対応: CoreMotion コールバックは背景 OperationQueue で呼ばれる。
//   Sendable 値（timestamp / Double）のみ抽出してメインキューへ橋渡しする。
final class CoreMotionIMURecorder: NSObject, IMURecorderPort, @unchecked Sendable {

    private let motionManager = CMMotionManager()
    private let queue: OperationQueue
    private let lock = NSLock()

    // 記録データ（背景 OperationQueue から書き込まれるため NSLock 保護）
    private var accelerometerData: [AccelerometerRecord] = []
    private var gyroscopeData: [GyroscopeRecord] = []

    /// `motion.timestamp` の最初の値（meta.json 用）
    private(set) var firstSampleTimestamp: TimeInterval?

    /// systemUptime → UNIX 時刻 変換用オフセット
    private var bootTimeUnix: TimeInterval = 0

    override init() {
        let q = OperationQueue()
        q.qualityOfService = .userInitiated
        q.name = "CoreMotionIMURecorder.queue"
        self.queue = q
        super.init()
    }

    func startRecording(onSample: @escaping @Sendable (TimeInterval) -> Void) {
        lock.lock()
        accelerometerData.removeAll()
        gyroscopeData.removeAll()
        firstSampleTimestamp = nil
        bootTimeUnix = Date().timeIntervalSince1970 - ProcessInfo.processInfo.systemUptime
        lock.unlock()

        guard motionManager.isDeviceMotionAvailable else {
            // Use Case 側が前提検証で弾く想定だが、念のため何もしない
            print("[CoreMotionIMURecorder] deviceMotion is not available")
            return
        }

        motionManager.deviceMotionUpdateInterval = 0.01
        motionManager.startDeviceMotionUpdates(to: queue) { [weak self] (motion, error) in
            guard let self = self, let motion = motion else {
                if let error = error {
                    print("[CoreMotionIMURecorder] motion error: \(error.localizedDescription)")
                }
                return
            }

            // Sendable 値だけ抽出
            let sampleTimestamp = motion.timestamp
            let ax = motion.userAcceleration.x
            let ay = motion.userAcceleration.y
            let az = motion.userAcceleration.z
            let gx = motion.rotationRate.x
            let gy = motion.rotationRate.y
            let gz = motion.rotationRate.z

            self.lock.lock()
            if self.firstSampleTimestamp == nil {
                self.firstSampleTimestamp = sampleTimestamp
            }
            let unixTimestamp = self.bootTimeUnix + sampleTimestamp
            self.accelerometerData.append(AccelerometerRecord(timestamp: unixTimestamp, x: ax, y: ay, z: az))
            self.gyroscopeData.append(GyroscopeRecord(timestamp: unixTimestamp, x: gx, y: gy, z: gz))
            self.lock.unlock()

            // Use Case にサンプルを通知（IMU 途絶検出のため `motion.timestamp` を渡す）
            onSample(sampleTimestamp)
        }
    }

    func stopRecording() {
        if motionManager.isDeviceMotionActive {
            motionManager.stopDeviceMotionUpdates()
        }
    }

    func exportCSV() -> URL? {
        lock.lock()
        let accel = accelerometerData
        let gyro = gyroscopeData
        lock.unlock()

        guard !accel.isEmpty || !gyro.isEmpty else { return nil }

        let combined = Self.combine(accel: accel, gyro: gyro)
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        let fileName = "vbt_imu_\(formatter.string(from: Date())).csv"
        let url = documentsDirectory.appendingPathComponent(fileName)

        // 仕様書 §7 注: timestamp は `CMDeviceMotion.timestamp` を そのまま記録（systemUptime 基準秒）
        // しかし既存パイプライン互換のため UNIX 時刻でも書ける CSV を維持する。
        // Phase A では「imu.csv」相当を作る最小実装として既存 CSV ヘッダを踏襲。
        var csvString = "timestamp,accel_x,accel_y,accel_z,accel_magnitude,gyro_x,gyro_y,gyro_z,gyro_magnitude\n"
        for data in combined {
            let timeString = CSVTimestampFormatter.format(data.timestamp)
            csvString.append("\(timeString),\(data.accelX),\(data.accelY),\(data.accelZ),\(data.accelMagnitude),\(data.gyroX),\(data.gyroY),\(data.gyroZ),\(data.gyroMagnitude)\n")
        }

        do {
            try csvString.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            print("[CoreMotionIMURecorder] CSV write failed: \(error.localizedDescription)")
            return nil
        }
    }

    func discardRecording() {
        lock.lock()
        accelerometerData.removeAll()
        gyroscopeData.removeAll()
        firstSampleTimestamp = nil
        lock.unlock()
    }

    // MARK: - Private

    /// 加速度・ジャイロを同じタイムスタンプで結合（既存 AccelerometerManager の combineSensorData ロジックを簡略化）
    private static func combine(accel: [AccelerometerRecord], gyro: [GyroscopeRecord]) -> [CombinedSensorData] {
        let sortedAccel = accel.sorted { $0.timestamp < $1.timestamp }
        let sortedGyro = gyro.sorted { $0.timestamp < $1.timestamp }
        var ai = 0
        var gi = 0
        var result: [CombinedSensorData] = []
        result.reserveCapacity(max(sortedAccel.count, sortedGyro.count))

        while ai < sortedAccel.count && gi < sortedGyro.count {
            let a = sortedAccel[ai]
            let g = sortedGyro[gi]
            let dt = abs(a.timestamp - g.timestamp)
            if dt <= 0.05 {
                let am = (a.x * a.x + a.y * a.y + a.z * a.z).squareRoot()
                let gm = (g.x * g.x + g.y * g.y + g.z * g.z).squareRoot()
                result.append(CombinedSensorData(
                    timestamp: a.timestamp,
                    accelX: a.x, accelY: a.y, accelZ: a.z, accelMagnitude: am,
                    gyroX: g.x, gyroY: g.y, gyroZ: g.z, gyroMagnitude: gm
                ))
                ai += 1
                gi += 1
            } else if a.timestamp < g.timestamp {
                let am = (a.x * a.x + a.y * a.y + a.z * a.z).squareRoot()
                result.append(CombinedSensorData(
                    timestamp: a.timestamp,
                    accelX: a.x, accelY: a.y, accelZ: a.z, accelMagnitude: am,
                    gyroX: 0, gyroY: 0, gyroZ: 0, gyroMagnitude: 0
                ))
                ai += 1
            } else {
                let gm = (g.x * g.x + g.y * g.y + g.z * g.z).squareRoot()
                result.append(CombinedSensorData(
                    timestamp: g.timestamp,
                    accelX: 0, accelY: 0, accelZ: 0, accelMagnitude: 0,
                    gyroX: g.x, gyroY: g.y, gyroZ: g.z, gyroMagnitude: gm
                ))
                gi += 1
            }
        }
        return result
    }
}
