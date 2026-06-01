// VBT Ground Truth Tool: TimeAxisAligner（Item5 物理マーカー2点線形対応, クロックドリフト補正）
// 仕様書: .docs/VBT_GroundTruth_Tool_Spec.md §5
//   「マーカーは記録開始直後と終了直前の計2回必須とし、2点で線形に時刻を対応づける」
import XCTest
@testable import SensorDataKit

final class TimeAxisAlignerTests: XCTestCase {

    // MARK: 正常系: 同一スケールならそのまま
    func test_align_identityMapping() throws {
        // IMU マーカー時刻 = (1.0, 11.0), Video マーカー時刻 = (1.0, 11.0)
        let aligner = try TimeAxisAligner(
            imuMarkerTimes: (start: 1.0, end: 11.0),
            videoMarkerTimes: (start: 1.0, end: 11.0)
        )
        XCTAssertEqual(aligner.imuTimeToUnified(1.0), 1.0, accuracy: 1e-9)
        XCTAssertEqual(aligner.imuTimeToUnified(6.0), 6.0, accuracy: 1e-9)
        XCTAssertEqual(aligner.imuTimeToUnified(11.0), 11.0, accuracy: 1e-9)
    }

    // MARK: 正常系: オフセットあり（線形シフト）
    func test_align_constantOffset() throws {
        // IMU の (1, 11) を Video の (101, 111) にマップ → IMU + 100 = Video
        let aligner = try TimeAxisAligner(
            imuMarkerTimes: (start: 1.0, end: 11.0),
            videoMarkerTimes: (start: 101.0, end: 111.0)
        )
        XCTAssertEqual(aligner.imuTimeToUnified(1.0), 101.0, accuracy: 1e-9)
        XCTAssertEqual(aligner.imuTimeToUnified(6.0), 106.0, accuracy: 1e-9)
    }

    // MARK: 正常系: クロックドリフト補正（傾き != 1）
    func test_align_withClockDrift() throws {
        // IMU (0, 10) → Video (0, 11) : video = imu * 1.1
        let aligner = try TimeAxisAligner(
            imuMarkerTimes: (start: 0.0, end: 10.0),
            videoMarkerTimes: (start: 0.0, end: 11.0)
        )
        XCTAssertEqual(aligner.imuTimeToUnified(0.0), 0.0, accuracy: 1e-9)
        XCTAssertEqual(aligner.imuTimeToUnified(5.0), 5.5, accuracy: 1e-9)
        XCTAssertEqual(aligner.imuTimeToUnified(10.0), 11.0, accuracy: 1e-9)
    }

    // MARK: 境界値: マーカー2点が同一 → ゼロ除算（不正）
    func test_init_withCoincidentMarkers_throws() {
        XCTAssertThrowsError(try TimeAxisAligner(
            imuMarkerTimes: (start: 5.0, end: 5.0),
            videoMarkerTimes: (start: 1.0, end: 11.0)
        )) { error in
            XCTAssertEqual(error as? TimeAxisAligner.ValidationError, .degenerateMarkers)
        }
    }

    // MARK: 境界値: video 側マーカー2点が同一
    func test_init_withCoincidentVideoMarkers_throws() {
        XCTAssertThrowsError(try TimeAxisAligner(
            imuMarkerTimes: (start: 1.0, end: 11.0),
            videoMarkerTimes: (start: 5.0, end: 5.0)
        )) { error in
            XCTAssertEqual(error as? TimeAxisAligner.ValidationError, .degenerateMarkers)
        }
    }

    // MARK: 正常系: 外挿（マーカー範囲外）も線形外挿で許容（後段が判断）
    func test_align_extrapolation_beyondMarkers() throws {
        let aligner = try TimeAxisAligner(
            imuMarkerTimes: (start: 1.0, end: 11.0),
            videoMarkerTimes: (start: 1.0, end: 11.0)
        )
        XCTAssertEqual(aligner.imuTimeToUnified(0.0), 0.0, accuracy: 1e-9)
        XCTAssertEqual(aligner.imuTimeToUnified(20.0), 20.0, accuracy: 1e-9)
    }
}
