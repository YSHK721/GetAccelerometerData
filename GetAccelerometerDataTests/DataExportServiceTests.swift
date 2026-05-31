import XCTest
import UniformTypeIdentifiers
@testable import GetAccelerometerData

final class DataExportServiceTests: XCTestCase {
    
    // 有効なCSVファイルからデータを正しく読み込めることをテスト
    func testPrepareCSVForExportWithValidFile() throws {
        // 準備: テスト用のCSVデータと一時ファイルを作成
        let testCSV = "timestamp,x,y,z,magnitude\n2025-04-22 10:00:00.000,0.1,0.2,0.3,0.4"
        let testData = testCSV.data(using: .utf8)!
        
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("test_valid.csv")
        
        try testData.write(to: fileURL)
        
        // 実行: テスト対象の関数を呼び出す
        let exportedData = DataExportService.prepareCSVForExport(fileURL: fileURL)
        
        // 検証: 返されたデータが元のデータと同じであることを確認
        XCTAssertNotNil(exportedData, "有効なファイルからデータを読み込めるはずです")
        XCTAssertEqual(exportedData, testData, "エクスポートされたデータは元のデータと一致するはずです")
        
        // クリーンアップ: 一時ファイルを削除
        try FileManager.default.removeItem(at: fileURL)
    }
    
    // 存在しないファイルパスを与えた場合にnilが返されることをテスト
    func testPrepareCSVForExportWithNonExistentFile() {
        // 準備: 存在しないファイルへのURLを作成
        let nonExistentFileURL = FileManager.default.temporaryDirectory.appendingPathComponent("non_existent_file.csv")
        
        // 実行: テスト対象の関数を呼び出す
        let exportedData = DataExportService.prepareCSVForExport(fileURL: nonExistentFileURL)
        
        // 検証: ファイルが存在しない場合、nilが返されるはず
        XCTAssertNil(exportedData, "存在しないファイルに対してnilが返されるべきです")
    }
    
    // 大きなCSVファイルを処理できることをテスト
    func testPrepareCSVForExportWithLargeFile() throws {
        // 準備: 大きなCSVデータを生成
        var largeCSV = "timestamp,x,y,z,magnitude\n"
        for i in 0..<1000 { // 1000行のデータ
            largeCSV += "2025-04-22 10:00:\(String(format: "%02d", i % 60)).000,\(Double.random(in: -1...1)),\(Double.random(in: -1...1)),\(Double.random(in: -1...1)),\(Double.random(in: 0...2))\n"
        }
        
        let largeData = largeCSV.data(using: .utf8)!
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_large.csv")
        try largeData.write(to: fileURL)
        
        // 実行: テスト対象の関数を呼び出す
        let exportedData = DataExportService.prepareCSVForExport(fileURL: fileURL)
        
        // 検証: 大きなファイルでも正しく処理されること
        XCTAssertNotNil(exportedData, "大きなファイルからもデータを読み込めるはずです")
        XCTAssertEqual(exportedData, largeData, "大きなファイルのデータも正確に保持されるべきです")
        
        // クリーンアップ: 一時ファイルを削除
        try FileManager.default.removeItem(at: fileURL)
    }
    
    // アクセス権限のないファイルを処理した場合の挙動をテスト
    func testPrepareCSVForExportWithInaccessibleFile() throws {
        // 注: このテストはシミュレータ/デバイスの権限設定に依存します
        // 権限のないファイルを作成するための簡略化されたアプローチ
        
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("inaccessible.csv")
        
        // ファイルを作成
        let testData = "test,data".data(using: .utf8)!
        try testData.write(to: fileURL)
        
        // ファイルへの読み取り権限を削除（注: これはシミュレータでは機能しない場合があります）
        // このテストの実行環境によっては、このステップをスキップするか条件付きで実行する必要があるかもしれません
        let fileManager = FileManager.default
        try? fileManager.setAttributes([.posixPermissions: 0o000], ofItemAtPath: fileURL.path)
        
        // 実行と検証: 権限設定が機能しなかった場合もあるので、結果に応じて検証
        let exportedData = DataExportService.prepareCSVForExport(fileURL: fileURL)
        
        // 権限設定が機能した場合はnilが返され、そうでない場合はデータが返されるはず
        if fileManager.isReadableFile(atPath: fileURL.path) {
            // 権限設定が機能しなかった場合（シミュレータなど）
            XCTAssertNotNil(exportedData, "ファイルが読み取り可能な場合、データが返されるはずです")
        } else {
            // 権限設定が機能した場合
            XCTAssertNil(exportedData, "読み取り不可能なファイルに対してnilが返されるべきです")
        }
        
        // クリーンアップ: 権限を戻してから削除
        try? fileManager.setAttributes([.posixPermissions: 0o644], ofItemAtPath: fileURL.path)
        try fileManager.removeItem(at: fileURL)
    }
    
    // 破損したファイルを処理した場合の挙動をテスト
    func testPrepareCSVForExportWithCorruptedFile() throws {
        // 準備: 破損したバイナリデータを持つファイルを作成
        let corruptedData = Data([0xFF, 0xD8, 0xFF, 0xE0]) // JPEGヘッダーのような非CSVデータ
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("corrupted.csv")
        try corruptedData.write(to: fileURL)
        
        // 実行: テスト対象の関数を呼び出す
        let exportedData = DataExportService.prepareCSVForExport(fileURL: fileURL)
        
        // 検証: UTF-8として読み取れない破損したファイルに対してはnilが返されるはず
        XCTAssertNil(exportedData, "UTF-8として読み取れない破損したファイルに対してはnilが返されるべきです")
        
        // クリーンアップ: 一時ファイルを削除
        try FileManager.default.removeItem(at: fileURL)
    }
}