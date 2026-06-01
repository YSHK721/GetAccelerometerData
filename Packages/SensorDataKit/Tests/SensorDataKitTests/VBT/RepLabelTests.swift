// VBT Ground Truth Tool: RepLabel（Item8 labels.json の reps[]）
// 仕様書: .docs/VBT_GroundTruth_Tool_Spec.md §8
import XCTest
@testable import SensorDataKit

final class RepLabelTests: XCTestCase {

    // MARK: 正常系: bottom のみ必須
    func test_init_withBottomOnly_succeeds() throws {
        let rep = try RepLabel(repIndex: 1, bottomTime: 12.34, startTime: nil, endTime: nil)
        XCTAssertEqual(rep.repIndex, 1)
        XCTAssertEqual(rep.bottomTime, 12.34, accuracy: 1e-9)
        XCTAssertNil(rep.startTime)
        XCTAssertNil(rep.endTime)
    }

    // MARK: 正常系: 任意項目を含む
    func test_init_withAllFields_succeeds() throws {
        let rep = try RepLabel(repIndex: 1, bottomTime: 12.34, startTime: 11.10, endTime: 13.50)
        XCTAssertEqual(rep.startTime, 11.10)
        XCTAssertEqual(rep.endTime, 13.50)
    }

    // MARK: 境界値: rep_index = 1（最小）
    func test_init_withRepIndexOne_succeeds() throws {
        let rep = try RepLabel(repIndex: 1, bottomTime: 0.0, startTime: nil, endTime: nil)
        XCTAssertEqual(rep.repIndex, 1)
    }

    // MARK: 異常系: rep_index = 0
    func test_init_withRepIndexZero_throws() {
        XCTAssertThrowsError(try RepLabel(repIndex: 0, bottomTime: 12.34, startTime: nil, endTime: nil)) { error in
            XCTAssertEqual(error as? RepLabel.ValidationError, .invalidRepIndex)
        }
    }

    // MARK: 異常系: rep_index 負
    func test_init_withNegativeRepIndex_throws() {
        XCTAssertThrowsError(try RepLabel(repIndex: -1, bottomTime: 12.34, startTime: nil, endTime: nil)) { error in
            XCTAssertEqual(error as? RepLabel.ValidationError, .invalidRepIndex)
        }
    }

    // MARK: 異常系: startTime > bottomTime（時系列違反）
    func test_init_withStartAfterBottom_throws() {
        XCTAssertThrowsError(try RepLabel(repIndex: 1, bottomTime: 10.0, startTime: 12.0, endTime: 13.0)) { error in
            XCTAssertEqual(error as? RepLabel.ValidationError, .nonMonotonicTimes)
        }
    }

    // MARK: 異常系: endTime < bottomTime（時系列違反）
    func test_init_withEndBeforeBottom_throws() {
        XCTAssertThrowsError(try RepLabel(repIndex: 1, bottomTime: 10.0, startTime: 9.0, endTime: 9.5)) { error in
            XCTAssertEqual(error as? RepLabel.ValidationError, .nonMonotonicTimes)
        }
    }

    // MARK: 境界値: start == bottom は許容（境界等号）
    func test_init_withStartEqualBottom_succeeds() throws {
        let rep = try RepLabel(repIndex: 1, bottomTime: 10.0, startTime: 10.0, endTime: 11.0)
        XCTAssertEqual(rep.startTime, 10.0)
    }

    // MARK: 境界値: end == bottom は許容
    func test_init_withEndEqualBottom_succeeds() throws {
        let rep = try RepLabel(repIndex: 1, bottomTime: 10.0, startTime: 9.0, endTime: 10.0)
        XCTAssertEqual(rep.endTime, 10.0)
    }

    // MARK: JSON 往復
    func test_jsonRoundTrip() throws {
        let original = try RepLabel(repIndex: 1, bottomTime: 12.34, startTime: 11.1, endTime: 13.5)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(RepLabel.self, from: data)
        XCTAssertEqual(decoded, original)
    }
}
