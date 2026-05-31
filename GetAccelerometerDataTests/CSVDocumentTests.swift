import XCTest
import UniformTypeIdentifiers
@testable import GetAccelerometerData

final class CSVDocumentTests: XCTestCase {
    
    // 基本的なデータでの初期化をテスト
    func testInitWithData() {
        // 準備
        let testString = "timestamp,x,y,z,magnitude\n2025-04-22 10:00:00.000,0.1,0.2,0.3,0.4"
        let testData = testString.data(using: .utf8)!
        
        // 実行
        let document = CSVDocument(data: testData)
        
        // 検証
        XCTAssertEqual(document.data, testData, "ドキュメントは初期化時に与えられたデータを正しく格納する必要があります")
    }
    
    // 空のデータでの初期化をテスト
    func testInitWithEmptyData() {
        // 準備
        let emptyData = Data()
        
        // 実行
        let document = CSVDocument(data: emptyData)
        
        // 検証
        XCTAssertEqual(document.data, emptyData, "ドキュメントは空のデータを正しく処理する必要があります")
    }
    
    // サポートされているコンテンツタイプをテスト
    func testSupportedContentTypes() {
        // 検証
        XCTAssertTrue(CSVDocument.readableContentTypes.contains(UTType.commaSeparatedText),
                     "CSVDocumentはカンマ区切りテキストのコンテンツタイプをサポートする必要があります")
    }
    
    // 実際のCSVデータを使用したテスト
    func testWithRealCSVData() {
        // 準備 - アプリが生成するようなサンプル加速度データを作成
        let csvString = """
        timestamp,x,y,z,magnitude
        2025-04-22 10:00:00.000,0.5678,-0.1234,0.9876,1.1523
        2025-04-22 10:00:00.100,0.5680,-0.1240,0.9880,1.1530
        2025-04-22 10:00:00.200,0.5690,-0.1245,0.9885,1.1540
        """
        
        let csvData = csvString.data(using: .utf8)!
        
        // 実行 - ドキュメントを作成
        let document = CSVDocument(data: csvData)
        
        // 検証 - ドキュメントが正しいデータを含んでいるか確認
        let recoveredString = String(data: document.data, encoding: .utf8)
        XCTAssertEqual(recoveredString, csvString, "ドキュメントはCSVデータを正確に保持する必要があります")
    }
    
    // データの整合性テスト - データが変更されないことを確認
    func testDataIntegrity() {
        // 準備
        let originalCSV = "timestamp,x,y,z,magnitude\n2025-04-22 10:00:00.000,0.1,0.2,0.3,0.4"
        let originalData = originalCSV.data(using: .utf8)!
        
        // 実行
        let document = CSVDocument(data: originalData)
        
        // 検証 - データが変更されていないことを確認
        XCTAssertEqual(document.data, originalData, "ドキュメントはデータを変更せずに格納する必要があります")
        
        // データを文字列に変換して内容を確認
        let recoveredCSV = String(data: document.data, encoding: .utf8)
        XCTAssertEqual(recoveredCSV, originalCSV, "データの内容が正確に保持されている必要があります")
    }
    
    // DataExportServiceとの統合テスト
    func testWithDataExportService() {
        // 準備 - テスト用のCSVデータを作成
        let testCSV = "timestamp,x,y,z,magnitude\n2025-04-22 10:00:00.000,0.1,0.2,0.3,0.4"
        let testData = testCSV.data(using: .utf8)!
        
        // 一時的なファイルURLを作成
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("test_accelerometer.csv")
        
        // ファイルに書き込み
        try? testData.write(to: fileURL)
        
        // 実行 - DataExportServiceのメソッドを使用
        let exportData = DataExportService.prepareCSVForExport(fileURL: fileURL)
        
        // 検証
        XCTAssertNotNil(exportData, "エクスポートデータはnilであってはなりません")
        if let data = exportData {
            let document = CSVDocument(data: data)
            let recoveredCSV = String(data: document.data, encoding: .utf8)
            XCTAssertEqual(recoveredCSV, testCSV, "エクスポートされたデータは元のCSVと一致する必要があります")
        }
        
        // クリーンアップ - 一時ファイルを削除
        try? FileManager.default.removeItem(at: fileURL)
    }
}
