// Phase H1/H2: AttitudeIMUCSVParser の純粋関数テスト。
// 既存 AttitudeIMUSourceTests は file I/O + parser を一体で検証していたが、
// パーサ部分を独立に検証することで FileManager 依存を排除しテスト速度・再現性を向上させる。
import XCTest
@testable import SensorDataKit

final class AttitudeIMUCSVParserTests: XCTestCase {

    // MARK: 正常系: datetime 形式 timestamp + gyro 列抽出
    func test_parse_datetimeTimestamp_extractsGyroColumns() throws {
        let csv = """
        timestamp,accel_x,accel_y,accel_z,accel_magnitude,gyro_x,gyro_y,gyro_z,gyro_magnitude
        2026-06-02 10:00:00.000000,0.1,0.2,0.3,0.374,0.01,0.02,0.03,0.037
        2026-06-02 10:00:00.010000,0.2,0.3,0.4,0.539,0.04,0.05,0.06,0.087
        """
        let samples = try AttitudeIMUCSVParser.parse(csvText: csv)
        XCTAssertEqual(samples.count, 2)
        XCTAssertEqual(samples[0].x, 0.01, accuracy: 1e-9)
        XCTAssertEqual(samples[0].y, 0.02, accuracy: 1e-9)
        XCTAssertEqual(samples[0].z, 0.03, accuracy: 1e-9)
        XCTAssertEqual(samples[1].x, 0.04, accuracy: 1e-9)
    }

    // MARK: 正常系: UNIX double timestamp（fallback parse）
    func test_parse_unixDoubleTimestamp_fallbackParses() throws {
        let csv = """
        timestamp,gyro_x,gyro_y,gyro_z
        1780402247.123,0.1,0.2,0.3
        1780402247.133,0.4,0.5,0.6
        """
        let samples = try AttitudeIMUCSVParser.parse(csvText: csv)
        XCTAssertEqual(samples.count, 2)
        XCTAssertEqual(samples[0].timestamp, 1780402247.123, accuracy: 1e-9)
    }

    // MARK: 異常系: timestamp 列欠落
    func test_parse_missingTimestampColumn_throws() {
        let csv = "gyro_x,gyro_y,gyro_z\n0.1,0.2,0.3"
        XCTAssertThrowsError(try AttitudeIMUCSVParser.parse(csvText: csv)) { error in
            XCTAssertEqual(
                error as? AttitudeIMUSourceError,
                .missingRequiredColumn(name: "timestamp")
            )
        }
    }

    // MARK: 異常系: gyro_x 列欠落
    func test_parse_missingGyroXColumn_throws() {
        let csv = "timestamp,gyro_y,gyro_z\n1.0,0.2,0.3"
        XCTAssertThrowsError(try AttitudeIMUCSVParser.parse(csvText: csv)) { error in
            XCTAssertEqual(
                error as? AttitudeIMUSourceError,
                .missingRequiredColumn(name: "gyro_x")
            )
        }
    }

    // MARK: 異常系: timestamp 単調性違反
    func test_parse_timestampNotMonotonic_throws() {
        let csv = """
        timestamp,gyro_x,gyro_y,gyro_z
        1000.0,0.1,0.2,0.3
        999.0,0.4,0.5,0.6
        """
        XCTAssertThrowsError(try AttitudeIMUCSVParser.parse(csvText: csv)) { error in
            XCTAssertEqual(error as? AttitudeIMUSourceError, .timestampNotMonotonic(line: 3))
        }
    }

    // MARK: 異常系: データ行 0
    func test_parse_emptyData_throws() {
        let csv = "timestamp,gyro_x,gyro_y,gyro_z"
        XCTAssertThrowsError(try AttitudeIMUCSVParser.parse(csvText: csv)) { error in
            XCTAssertEqual(error as? AttitudeIMUSourceError, .emptyData)
        }
    }

    // MARK: 異常系: 列数不足
    func test_parse_malformedRow_throwsWithLineNumber() {
        let csv = """
        timestamp,gyro_x,gyro_y,gyro_z
        1000.0,0.1,0.2,0.3
        1001.0,0.4
        """
        XCTAssertThrowsError(try AttitudeIMUCSVParser.parse(csvText: csv)) { error in
            XCTAssertEqual(error as? AttitudeIMUSourceError, .malformedRow(line: 3))
        }
    }

    // MARK: 異常系: missingHeader（完全空文字列）
    func test_parse_emptyString_throwsMissingHeader() {
        XCTAssertThrowsError(try AttitudeIMUCSVParser.parse(csvText: "")) { error in
            XCTAssertEqual(error as? AttitudeIMUSourceError, .missingHeader)
        }
    }

    // MARK: 既存テストの fileNotFound は本パーサ範囲外（I/O 層）
    // → AttitudeIMUSourceTests で引き続き検証する
}
