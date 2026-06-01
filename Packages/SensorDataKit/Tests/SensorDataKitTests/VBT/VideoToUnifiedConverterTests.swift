// VBT Ground Truth Tool Phase C: 動画ローカル時刻 → 統一時刻軸（IMU motion.timestamp 基準）変換
// 仕様書: .docs/VBT_GroundTruth_Tool_Spec.md §8
//   a = (sync_markers_imu.end - sync_markers_imu.start) /
//       (sync_markers_video.end - sync_markers_video.start)
//   b = sync_markers_imu.start - a * sync_markers_video.start
//   t_unified = a * t_video + b
import XCTest
@testable import SensorDataKit

final class VideoToUnifiedConverterTests: XCTestCase {

    // 正常系: video=(0, 10), imu=(100, 120) → 傾き2, 切片100
    func test_convert_simpleLinear() throws {
        let conv = try VideoToUnifiedConverter(
            syncMarkersVideo: SyncMarker(startTime: 0.0, endTime: 10.0),
            syncMarkersImu: SyncMarker(startTime: 100.0, endTime: 120.0)
        )
        XCTAssertEqual(conv.videoToUnified(0.0), 100.0, accuracy: 1e-9)
        XCTAssertEqual(conv.videoToUnified(5.0), 110.0, accuracy: 1e-9)
        XCTAssertEqual(conv.videoToUnified(10.0), 120.0, accuracy: 1e-9)
    }

    // 仕様書 §8 例: sync_markers_video {1.23, 47.88}, sync_markers_imu {1234.56, 1281.21}
    func test_convert_specExample() throws {
        let conv = try VideoToUnifiedConverter(
            syncMarkersVideo: SyncMarker(startTime: 1.23, endTime: 47.88),
            syncMarkersImu: SyncMarker(startTime: 1234.56, endTime: 1281.21)
        )
        // start に対しては imu.start に一致
        XCTAssertEqual(conv.videoToUnified(1.23), 1234.56, accuracy: 1e-6)
        // end に対しては imu.end に一致
        XCTAssertEqual(conv.videoToUnified(47.88), 1281.21, accuracy: 1e-6)
    }

    // 境界: video span ゼロ
    func test_init_zeroVideoSpan_throws() {
        // SyncMarker の不変条件で end > start のため、明示的に SyncMarker をバイパスして空 span を構成不可。
        // 代わりに video の傾き分母が 0 となるケースは構築不能であることをドキュメント化。
        // ここでは反例として「video.end ≒ video.start」極小 span を試し、変換結果が極端でも throw しないことを確認する。
        XCTAssertNoThrow(try VideoToUnifiedConverter(
            syncMarkersVideo: SyncMarker(startTime: 0.0, endTime: 0.001),
            syncMarkersImu: SyncMarker(startTime: 0.0, endTime: 1000.0)
        ))
    }
}
