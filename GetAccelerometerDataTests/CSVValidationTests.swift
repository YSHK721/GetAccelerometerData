import XCTest
@testable import GetAccelerometerData

final class CSVValidationTests: XCTestCase {
    
    // テスト: 有効なCSVフォーマットを検証
    func testValidCSVFormat() {
        // 準備: 正常なCSVデータ
        let validCSV = """
        timestamp,x,y,z,magnitude
        2025-04-22 10:00:00.000,0.1,0.2,0.3,0.4
        2025-04-22 10:00:01.000,0.5,0.6,0.7,0.8
        """
        
        // 実行
        let isValid = ValidateSensorCSVUseCase().execute(csvString: validCSV)
        
        // 検証
        XCTAssertTrue(isValid, "正常なCSVデータは有効と判断されるべきです")
    }
    
    // テスト: タブや空白が含まれるヘッダーでも正しく検証
    func testCSVFormatWithWhitespaceInHeader() {
        // 準備: ヘッダーに空白を含むCSVデータ
        let csvWithWhitespace = """
        timestamp, x , y,z ,magnitude
        2025-04-22 10:00:00.000,0.1,0.2,0.3,0.4
        """
        
        // 実行
        let isValid = ValidateSensorCSVUseCase().execute(csvString: csvWithWhitespace)
        
        // 検証
        XCTAssertTrue(isValid, "ヘッダーに空白を含むCSVデータも有効と判断されるべきです")
    }
    
    // テスト: 大文字小文字が混在するヘッダーでも正しく検証
    func testCSVFormatWithMixedCaseHeader() {
        // 準備: 大文字小文字が混在するヘッダー
        let csvWithMixedCase = """
        TimeStamp,X,y,Z,Magnitude
        2025-04-22 10:00:00.000,0.1,0.2,0.3,0.4
        """
        
        // 実行
        let isValid = ValidateSensorCSVUseCase().execute(csvString: csvWithMixedCase)
        
        // 検証
        XCTAssertTrue(isValid, "大文字小文字が混在するヘッダーも有効と判断されるべきです")
    }
    
    // テスト: 必要なカラムが足りないCSVデータ
    func testCSVFormatWithMissingColumns() {
        // 準備: 必要なカラム（magnitude）が欠けているCSVデータ
        let csvWithMissingColumn = """
        timestamp,x,y,z
        2025-04-22 10:00:00.000,0.1,0.2,0.3
        """
        
        // 実行
        let isValid = ValidateSensorCSVUseCase().execute(csvString: csvWithMissingColumn)
        
        // 検証
        XCTAssertFalse(isValid, "必要なカラムが欠けているCSVデータは無効と判断されるべきです")
    }
    
    // テスト: 列数が一致しない行を含むCSVデータ
    func testCSVFormatWithInconsistentColumnCount() {
        // 準備: 2行目の列数が足りないCSVデータ
        let csvWithInconsistentColumns = """
        timestamp,x,y,z,magnitude
        2025-04-22 10:00:00.000,0.1,0.2,0.3,0.4
        2025-04-22 10:00:01.000,0.5,0.6,0.7
        """
        
        // 実行
        let isValid = ValidateSensorCSVUseCase().execute(csvString: csvWithInconsistentColumns)
        
        // 検証
        XCTAssertFalse(isValid, "列数が一致しない行を含むCSVデータは無効と判断されるべきです")
    }
    
    // テスト: 数値として解析できない値を含むCSVデータ
    func testCSVFormatWithInvalidNumericValues() {
        // 準備: x列に数値ではない値（NaN）を含むCSVデータ
        let csvWithInvalidNumbers = """
        timestamp,x,y,z,magnitude
        2025-04-22 10:00:00.000,NaN,0.2,0.3,0.4
        """
        
        // 実行
        let isValid = ValidateSensorCSVUseCase().execute(csvString: csvWithInvalidNumbers)
        
        // 検証
        XCTAssertFalse(isValid, "数値として解析できない値を含むCSVデータは無効と判断されるべきです")
    }
    
    // テスト: 複雑な検証ケース - カラム順序がデフォルトと異なる場合
    func testCSVFormatWithDifferentColumnOrder() {
        // 準備: カラムの順序が異なるCSVデータ
        let csvWithDifferentOrder = """
        x,y,z,timestamp,magnitude
        0.1,0.2,0.3,2025-04-22 10:00:00.000,0.4
        """
        
        // 実行
        let isValid = ValidateSensorCSVUseCase().execute(csvString: csvWithDifferentOrder)
        
        // 検証
        XCTAssertTrue(isValid, "カラムの順序が異なるCSVデータも有効と判断されるべきです")
    }
    
    // テスト: 空のCSVデータ
    func testEmptyCSVFormat() {
        // 準備: 空のCSVデータ
        let emptyCSV = ""
        
        // 実行
        let isValid = ValidateSensorCSVUseCase().execute(csvString: emptyCSV)
        
        // 検証
        XCTAssertFalse(isValid, "空のCSVデータは無効と判断されるべきです")
    }
    
    // テスト: 余分なカラムを含むCSVデータ
    func testCSVFormatWithExtraColumns() {
        // 準備: 必要なカラムに加えて余分なカラムを含むCSVデータ
        let csvWithExtraColumns = """
        timestamp,x,y,z,magnitude,extra1,extra2
        2025-04-22 10:00:00.000,0.1,0.2,0.3,0.4,extraData1,extraData2
        """
        
        // 実行
        let isValid = ValidateSensorCSVUseCase().execute(csvString: csvWithExtraColumns)
        
        // 検証
        XCTAssertTrue(isValid, "必要なカラムに加えて余分なカラムを含むCSVデータも有効と判断されるべきです")
    }
}