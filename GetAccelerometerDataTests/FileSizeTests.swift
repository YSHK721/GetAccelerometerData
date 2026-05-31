import XCTest

class FileSizeTests: XCTestCase {
    func testFileSizeExceeds64KB() {
        let data = Data(repeating: 0, count: 65_536) // 64KB + 1 byte
        XCTAssertGreaterThan(data.count, 64_000, "データサイズが64KBを超えていることを確認します。")
    }
}