// VBT Ground Truth Tool Phase B: セッションフォルダ命名規則
// 仕様書: .docs/VBT_GroundTruth_Tool_Spec.md §7
//   フォルダ名: session_YYYYMMDD_HHMMSS_<exercise>_<weight_kg>kg_set<set_index>
import XCTest
@testable import SensorDataKit

final class SessionFolderNamingTests: XCTestCase {

    // MARK: 仕様書 §7 例の再現
    func test_folderName_matchesSpecExample() throws {
        var components = DateComponents()
        components.year = 2026; components.month = 5; components.day = 31
        components.hour = 16; components.minute = 26; components.second = 1
        components.timeZone = TimeZone(identifier: "UTC")
        let date = Calendar(identifier: .gregorian).date(from: components)!

        let name = SessionFolderNaming.makeFolderName(
            startedAt: date,
            exercise: "back_squat",
            weightKg: 80,
            setIndex: 1,
            timeZone: TimeZone(identifier: "UTC")!
        )
        XCTAssertEqual(name, "session_20260531_162601_back_squat_80kg_set1")
    }

    // MARK: 整数 weight は小数なし
    func test_folderName_integerWeight_noDecimal() throws {
        var components = DateComponents()
        components.year = 2026; components.month = 1; components.day = 1
        components.hour = 0; components.minute = 0; components.second = 0
        components.timeZone = TimeZone(identifier: "UTC")
        let date = Calendar(identifier: .gregorian).date(from: components)!
        let name = SessionFolderNaming.makeFolderName(
            startedAt: date,
            exercise: "squat",
            weightKg: 100,
            setIndex: 0,
            timeZone: TimeZone(identifier: "UTC")!
        )
        XCTAssertEqual(name, "session_20260101_000000_squat_100kg_set0")
    }

    // MARK: 小数 weight は保持
    func test_folderName_fractionalWeight_preserved() throws {
        var components = DateComponents()
        components.year = 2026; components.month = 1; components.day = 1
        components.hour = 0; components.minute = 0; components.second = 0
        components.timeZone = TimeZone(identifier: "UTC")
        let date = Calendar(identifier: .gregorian).date(from: components)!
        let name = SessionFolderNaming.makeFolderName(
            startedAt: date,
            exercise: "squat",
            weightKg: 80.5,
            setIndex: 2,
            timeZone: TimeZone(identifier: "UTC")!
        )
        XCTAssertEqual(name, "session_20260101_000000_squat_80.5kg_set2")
    }
}
