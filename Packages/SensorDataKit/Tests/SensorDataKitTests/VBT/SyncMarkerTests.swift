// VBT Ground Truth Tool: SyncMarker（Item5 物理マーカー主同期, Item7 meta.json 内マーカー時刻）
// 仕様書: .docs/VBT_GroundTruth_Tool_Spec.md §5 / §7
import XCTest
@testable import SensorDataKit

final class SyncMarkerTests: XCTestCase {

    // MARK: 正常系: 開始 < 終了 で生成可
    func test_init_withStartBeforeEnd_succeeds() throws {
        let marker = try SyncMarker(startTime: 1.23, endTime: 47.88)
        XCTAssertEqual(marker.startTime, 1.23, accuracy: 1e-9)
        XCTAssertEqual(marker.endTime, 47.88, accuracy: 1e-9)
    }

    // MARK: 異常系: 開始 == 終了 は不可（線形補正の傾き未定義）
    func test_init_withStartEqualToEnd_throws() {
        XCTAssertThrowsError(try SyncMarker(startTime: 5.0, endTime: 5.0)) { error in
            XCTAssertEqual(error as? SyncMarker.ValidationError, .endNotAfterStart)
        }
    }

    // MARK: 異常系: 開始 > 終了 は不可
    func test_init_withStartAfterEnd_throws() {
        XCTAssertThrowsError(try SyncMarker(startTime: 10.0, endTime: 5.0)) { error in
            XCTAssertEqual(error as? SyncMarker.ValidationError, .endNotAfterStart)
        }
    }

    // MARK: 境界値: end - start が極小（1ms）でも成立
    func test_init_withMinimalPositiveDuration_succeeds() throws {
        let marker = try SyncMarker(startTime: 0.0, endTime: 0.001)
        XCTAssertGreaterThan(marker.endTime, marker.startTime)
    }
}
