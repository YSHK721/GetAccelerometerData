// VBT Motion Replay PoC Phase 2: AttitudeIMUSource のテスト
// 内部設計書: .docs/07_vbt_motion_replay_internal_design.md §6 Step 1-6
//
// 各テストは tempDir に imu.csv を Write して読み取りを検証し、tearDown で削除する。
import XCTest
@testable import SensorDataKit

final class AttitudeIMUSourceTests: XCTestCase {

    private var tempFolderURL: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempFolderURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempFolderURL, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let url = tempFolderURL,
           FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.removeItem(at: url)
        }
        tempFolderURL = nil
        try super.tearDownWithError()
    }

    private func writeIMUCSV(_ content: String) throws -> URL {
        let fileURL = tempFolderURL.appendingPathComponent("imu.csv")
        try content.write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }

    // MARK: - 1. 正常系（CSVTimestampFormatter 文字列形式）

    func test_load_acceptsDateStringTimestamp_extractsGyroColumns() throws {
        let csv = """
        timestamp,accel_x,accel_y,accel_z,accel_magnitude,gyro_x,gyro_y,gyro_z,gyro_magnitude
        2026-06-02 10:00:00.000000,0.1,0.2,0.3,0.374,0.01,0.02,0.03,0.037
        2026-06-02 10:00:00.010000,0.2,0.3,0.4,0.539,0.02,0.03,0.04,0.054
        """
        _ = try writeIMUCSV(csv)

        let samples = try AttitudeIMUSource.load(folderURL: tempFolderURL)
        XCTAssertEqual(samples.count, 2)
        XCTAssertEqual(samples[0].x, 0.01, accuracy: 1e-9)
        XCTAssertEqual(samples[0].y, 0.02, accuracy: 1e-9)
        XCTAssertEqual(samples[0].z, 0.03, accuracy: 1e-9)
        XCTAssertEqual(samples[1].x, 0.02, accuracy: 1e-9)
        XCTAssertEqual(samples[1].y, 0.03, accuracy: 1e-9)
        XCTAssertEqual(samples[1].z, 0.04, accuracy: 1e-9)
        // 隣接行 10ms 差
        XCTAssertEqual(samples[1].timestamp - samples[0].timestamp, 0.010, accuracy: 1e-3)
    }

    // MARK: - 2. 正常系（UNIX 秒 Double 形式 fallback）

    func test_load_acceptsUnixDoubleTimestamp_fallbackParses() throws {
        let csv = """
        timestamp,gyro_x,gyro_y,gyro_z
        1780402247.123,0.1,0.2,0.3
        1780402247.133,0.4,0.5,0.6
        """
        _ = try writeIMUCSV(csv)

        let samples = try AttitudeIMUSource.load(folderURL: tempFolderURL)
        XCTAssertEqual(samples.count, 2)
        XCTAssertEqual(samples[0].timestamp, 1780402247.123, accuracy: 1e-6)
        XCTAssertEqual(samples[1].timestamp, 1780402247.133, accuracy: 1e-6)
        XCTAssertEqual(samples[0].x, 0.1, accuracy: 1e-12)
        XCTAssertEqual(samples[1].z, 0.6, accuracy: 1e-12)
    }

    // MARK: - 3. timestamp 列欠落

    func test_load_missingTimestampColumn_throws() throws {
        let csv = """
        gyro_x,gyro_y,gyro_z
        0.1,0.2,0.3
        """
        _ = try writeIMUCSV(csv)

        XCTAssertThrowsError(try AttitudeIMUSource.load(folderURL: tempFolderURL)) { error in
            XCTAssertEqual(error as? AttitudeIMUSourceError, .missingRequiredColumn(name: "timestamp"))
        }
    }

    // MARK: - 4. gyro_x 列欠落

    func test_load_missingGyroXColumn_throws() throws {
        let csv = """
        timestamp,gyro_y,gyro_z
        1000.0,0.2,0.3
        """
        _ = try writeIMUCSV(csv)

        XCTAssertThrowsError(try AttitudeIMUSource.load(folderURL: tempFolderURL)) { error in
            XCTAssertEqual(error as? AttitudeIMUSourceError, .missingRequiredColumn(name: "gyro_x"))
        }
    }

    // MARK: - 5. timestamp 逆順

    func test_load_timestampNotMonotonic_throwsAtSecondDataLine() throws {
        // 1 行目（ヘッダ）= line 1
        // 2 行目（1 件目データ）= line 2 → ts=1000.020
        // 3 行目（2 件目データ）= line 3 → ts=1000.010 < 1000.020（逆順）
        let csv = """
        timestamp,gyro_x,gyro_y,gyro_z
        1000.020,0.0,0.0,0.0
        1000.010,0.0,0.0,0.0
        """
        _ = try writeIMUCSV(csv)

        XCTAssertThrowsError(try AttitudeIMUSource.load(folderURL: tempFolderURL)) { error in
            XCTAssertEqual(error as? AttitudeIMUSourceError, .timestampNotMonotonic(line: 3))
        }
    }

    // MARK: - 6. データ行 0 件

    func test_load_emptyData_throws() throws {
        let csv = "timestamp,gyro_x,gyro_y,gyro_z\n"
        _ = try writeIMUCSV(csv)

        XCTAssertThrowsError(try AttitudeIMUSource.load(folderURL: tempFolderURL)) { error in
            XCTAssertEqual(error as? AttitudeIMUSourceError, .emptyData)
        }
    }

    // MARK: - 7. 列数不足行

    func test_load_malformedRow_throwsWithLineNumber() throws {
        // 1 行目（ヘッダ）= line 1
        // 2 行目（1 件目）= line 2 → 正常
        // 3 行目（2 件目）= line 3 → 列数不足
        let csv = """
        timestamp,gyro_x,gyro_y,gyro_z
        1000.0,0.1,0.2,0.3
        1000.010,0.4
        """
        _ = try writeIMUCSV(csv)

        XCTAssertThrowsError(try AttitudeIMUSource.load(folderURL: tempFolderURL)) { error in
            XCTAssertEqual(error as? AttitudeIMUSourceError, .malformedRow(line: 3))
        }
    }

    // MARK: - 8. ファイル不存在

    func test_load_fileNotFound_throws() throws {
        // imu.csv を作らない
        let expectedPath = tempFolderURL.appendingPathComponent("imu.csv").path
        XCTAssertThrowsError(try AttitudeIMUSource.load(folderURL: tempFolderURL)) { error in
            XCTAssertEqual(error as? AttitudeIMUSourceError, .fileNotFound(path: expectedPath))
        }
    }
}
