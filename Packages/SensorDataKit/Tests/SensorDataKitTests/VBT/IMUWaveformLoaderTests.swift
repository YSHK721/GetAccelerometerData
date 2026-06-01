// VBT Ground Truth Tool Phase C: imu.csv から accel_magnitude 列を抽出する UseCase
// 仕様書: .docs/VBT_GroundTruth_Tool_Spec.md §7 IMU CSV フォーマット
//   列: timestamp, accel_x/y/z, accel_magnitude, gyro_x/y/z, gyro_magnitude
import XCTest
@testable import SensorDataKit

final class IMUWaveformLoaderTests: XCTestCase {

    // MARK: 正常系: ヘッダ + 数行を読んで magnitude 列を抽出
    func test_parse_extractsTimestampAndMagnitude() throws {
        let csv = """
        timestamp,accel_x,accel_y,accel_z,accel_magnitude,gyro_x,gyro_y,gyro_z,gyro_magnitude
        1000.000,0.1,0.2,0.3,1.0,0.0,0.0,0.0,0.0
        1000.010,0.2,0.3,0.4,1.5,0.0,0.0,0.0,0.0
        1000.020,0.3,0.4,0.5,2.0,0.0,0.0,0.0,0.0
        """
        let samples = try IMUWaveformParser.parse(csvString: csv)
        XCTAssertEqual(samples.count, 3)
        XCTAssertEqual(samples[0].timestamp, 1000.0, accuracy: 1e-6)
        XCTAssertEqual(samples[0].accelMagnitude, 1.0, accuracy: 1e-6)
        XCTAssertEqual(samples[1].timestamp, 1000.010, accuracy: 1e-6)
        XCTAssertEqual(samples[1].accelMagnitude, 1.5, accuracy: 1e-6)
        XCTAssertEqual(samples[2].accelMagnitude, 2.0, accuracy: 1e-6)
    }

    // MARK: 異常系: ヘッダ欠落 → 失敗
    func test_parse_missingHeader_throws() {
        let csv = "1000.000,0.1,0.2,0.3,1.0,0.0,0.0,0.0,0.0\n"
        XCTAssertThrowsError(try IMUWaveformParser.parse(csvString: csv))
    }

    // MARK: 異常系: 必須列欠落（accel_magnitude）
    func test_parse_missingMagnitudeColumn_throws() {
        let csv = """
        timestamp,accel_x,accel_y,accel_z
        1000.000,0.1,0.2,0.3
        """
        XCTAssertThrowsError(try IMUWaveformParser.parse(csvString: csv))
    }

    // MARK: 境界: 空行・末尾改行を許容
    func test_parse_emptyTrailingLines_ignored() throws {
        let csv = """
        timestamp,accel_x,accel_y,accel_z,accel_magnitude,gyro_x,gyro_y,gyro_z,gyro_magnitude
        1000.000,0.1,0.2,0.3,1.0,0.0,0.0,0.0,0.0

        """
        let samples = try IMUWaveformParser.parse(csvString: csv)
        XCTAssertEqual(samples.count, 1)
    }
}
