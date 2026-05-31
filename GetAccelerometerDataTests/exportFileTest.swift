import XCTest
import SwiftUI
import UniformTypeIdentifiers
@testable import GetAccelerometerData

final class FileExportViewTests: XCTestCase {
    
    // FileExportViewのexportFileメソッドをテストするためのヘルパークラス
    class TestableFileExportView {
        private let fileURL: URL
        private let view: FileExportView
        private var mirror: Mirror
        
        init(fileURL: URL) {
            self.fileURL = fileURL
            self.view = FileExportView(fileURL: fileURL)
            self.mirror = Mirror(reflecting: view)
        }
        
        // ViewModifierのプライベートプロパティにアクセスするための関数
        func getProperty<T>(named name: String) -> T? {
            return mirror.children.first(where: { $0.label == name })?.value as? T
        }
        
        // exportFileメソッドの代わりに、その効果をシミュレートする関数
        func simulateExportFile() -> Bool {
            // CSVエクスポートをシミュレート
            if DataExportService.prepareCSVForExport(fileURL: fileURL) != nil {
                return true
            } else {
                return false
            }
        }
    }
    
    // CSVエクスポートが正しく動作することをテスト
    func testExportFileAsCSV() throws {
        // 準備: テスト用のCSVファイルを作成
        let testCSV = "timestamp,x,y,z,magnitude\n2025-04-22 10:00:00.000,0.1,0.2,0.3,0.4"
        let testData = testCSV.data(using: .utf8)!
        
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("test_export.csv")
        
        try testData.write(to: fileURL)
        
        // テスト用のビューを作成
        let testView = TestableFileExportView(fileURL: fileURL)
        
        // 実行: exportFileのシミュレーション
        let exportSuccess = testView.simulateExportFile()
        
        // 検証: エクスポートが成功することを確認
        XCTAssertTrue(exportSuccess, "CSVエクスポートが成功するはずです")
        
        // クリーンアップ: 一時ファイルを削除
        try FileManager.default.removeItem(at: fileURL)
    }
    
    // 存在しないファイルでのエクスポート処理をテスト
    func testExportNonExistentFile() {
        // 準備: 存在しないファイルへのURLを作成
        let nonExistentFileURL = FileManager.default.temporaryDirectory.appendingPathComponent("non_existent_file.csv")
        
        // テスト用のビューを作成
        let testView = TestableFileExportView(fileURL: nonExistentFileURL)
        
        // 実行: CSV形式でのエクスポートをシミュレート
        let exportSuccess = testView.simulateExportFile()
        
        // 検証: ファイルが存在しない場合、エクスポートは失敗するはず
        XCTAssertFalse(exportSuccess, "存在しないファイルに対してエクスポートは失敗するはずです")
    }
    
    // 無効なCSVファイルのエクスポートをテスト
    func testExportInvalidCSVFile() throws {
        // 準備: 無効なCSVファイル（ヘッダーなし）を作成
        let invalidCSV = "0.1,0.2,0.3,0.4\n0.5,0.6,0.7,0.8" // ヘッダーなしでは正常に変換できない
        let invalidData = invalidCSV.data(using: .utf8)!
        
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("invalid_csv.csv")
        
        try invalidData.write(to: fileURL)
        
        // テスト用のビューを作成
        let testView = TestableFileExportView(fileURL: fileURL)
        
        // 実行: CSVエクスポートをシミュレート
        let exportSuccess = testView.simulateExportFile()
        
        // 検証: 無効なCSVファイルの場合、エクスポートは失敗するはず
        XCTAssertFalse(exportSuccess, "無効なCSVファイルに対してエクスポートは失敗するはずです")
        
        // クリーンアップ: 一時ファイルを削除
        try FileManager.default.removeItem(at: fileURL)
    }
}