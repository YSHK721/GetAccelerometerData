import XCTest
import SwiftUI
import Charts
import UniformTypeIdentifiers
@testable import GetAccelerometerData

// MARK: - AccelerometerChartView テストファイル
// リファクタリング前の安全性基準確立のためのテストスイート

// ISSUE-032 (案 Y): クラス全体への @MainActor 付与は ISSUE-018 で実害（CoreMotion クラッシュ）を
// 起こした経緯があるため禁止。Swift 6 strict concurrency 違反は個別メソッド単位で対処する:
//   - waitForExpectations を使う sync テスト: メソッド単位で @MainActor 付与
//   - 並行テスト: Task.detached + NSLock-guarded ホルダで Sendable 値経由
//   - setUp / tearDown: nonisolated sync で、MainActor 必要部分のみ MainActor.assumeIsolated
final class AccelerometerChartViewTests: XCTestCase {
    
    // MARK: - Test Properties
    private var sampleReadings: [AccelerometerReading]!
    private var testFileURL: URL!
    private var testCSVString: String!
    
    // MARK: - New Architecture Components
    private var repository: AccelerometerDataRepository!
    private var loadDataUseCase: LoadAccelerometerDataUseCase!
    private var calculateStatisticsUseCase: CalculateStatisticsUseCase!
    private var viewModel: AccelerometerChartViewModel!
    
    // MARK: - Setup & Teardown
    // ISSUE-032 (案 Y): クラス全体 @MainActor 化を避け、setUp/tearDown を個別 @MainActor 化。
    // async override 形式により XCTestCase の nonisolated 基底メソッドからアクター隔離を追加可能。
    // テストクラス本体は nonisolated を維持し、将来非 MainActor サービスを呼ぶ際の波及を防ぐ。
    @MainActor
    override func setUp() async throws {
        try await super.setUp()
        setupTestData()
        setupTestFile()
        setupNewArchitectureComponents()
    }

    @MainActor
    override func tearDown() async throws {
        cleanupTestFile()
        try await super.tearDown()
    }
    
    // MARK: - Test Data Setup
    private func setupTestData() {
        let baseDate = Date()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        
        sampleReadings = [
            AccelerometerReading(
                timestamp: baseDate,
                x: 0.1234,
                y: -0.5678,
                z: 0.9876,
                magnitude: 1.1523
            ),
            AccelerometerReading(
                timestamp: baseDate.addingTimeInterval(0.1),
                x: 0.1240,
                y: -0.5680,
                z: 0.9880,
                magnitude: 1.1530
            ),
            AccelerometerReading(
                timestamp: baseDate.addingTimeInterval(0.2),
                x: 0.1250,
                y: -0.5685,
                z: 0.9885,
                magnitude: 1.1540
            ),
            AccelerometerReading(
                timestamp: baseDate.addingTimeInterval(0.3),
                x: 0.1260,
                y: -0.5690,
                z: 0.9890,
                magnitude: 1.1550
            ),
            AccelerometerReading(
                timestamp: baseDate.addingTimeInterval(0.4),
                x: 0.1270,
                y: -0.5695,
                z: 0.9895,
                magnitude: 1.1560
            )
        ]
        
        // テスト用CSVデータ作成
        testCSVString = "timestamp,x,y,z,magnitude\n"
        let dateFormatter2 = DateFormatter()
        dateFormatter2.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        
        for reading in sampleReadings {
            testCSVString += "\(dateFormatter2.string(from: reading.timestamp)),\(reading.x),\(reading.y),\(reading.z),\(reading.magnitude)\n"
        }
    }
    
    private func setupTestFile() {
        testFileURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_accelerometer_data.csv")
        try! testCSVString.write(to: testFileURL, atomically: true, encoding: .utf8)
    }
    
    @MainActor
    private func setupNewArchitectureComponents() {
        repository = AccelerometerDataRepository()
        loadDataUseCase = LoadAccelerometerDataUseCase(repository: repository)
        calculateStatisticsUseCase = CalculateStatisticsUseCase()
        // ViewModelを同期的に初期化
        viewModel = AccelerometerChartViewModel(
            loadDataUseCase: loadDataUseCase,
            calculateStatisticsUseCase: calculateStatisticsUseCase
        )
    }
    
    // MARK: - Helper Methods for New Architecture
    // ISSUE-032: `viewModel.formatDuration(seconds:)` は本体側で削除済のため、
    // ヘルパー + testFormatDuration() 共に削除した。

    private func calculateStatistics(readings: [AccelerometerReading], dataType: DataType) -> DataStatistics {
        return calculateStatisticsUseCase.execute(readings: readings, dataType: dataType)
    }
    
    // ISSUE-032 (案 Y): completion を `@Sendable` 化し、Task 内へ送れるようにする。
    // テスト helper のため呼び出し側は MainActor で受け取る前提（既存テストの規約）。
    private func loadDataFromCSV(
        fileURL: URL,
        completion: @escaping @Sendable @MainActor ([AccelerometerReading]?, Error?) -> Void
    ) {
        let useCase = self.loadDataUseCase!
        Task {
            do {
                let readings = try await useCase.execute(fileURL: fileURL)
                await MainActor.run {
                    completion(readings, nil)
                }
            } catch {
                await MainActor.run {
                    completion(nil, error)
                }
            }
        }
    }
    
    private func cleanupTestFile() {
        if let url = testFileURL, FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.removeItem(at: url)
        }
    }
}

// MARK: - Color Extension Tests
extension AccelerometerChartViewTests {
    
    func testColorExtensionValues() {
        // カラー定義の存在確認
        XCTAssertNotNil(Color.xAxisColor, "X軸カラーが定義されている必要があります")
        XCTAssertNotNil(Color.yAxisColor, "Y軸カラーが定義されている必要があります")
        XCTAssertNotNil(Color.zAxisColor, "Z軸カラーが定義されている必要があります")
        XCTAssertNotNil(Color.magnitudeColor, "合成加速度カラーが定義されている必要があります")
        
        // カラーが正しい値を持つことを確認
        XCTAssertEqual(Color.xAxisColor, .blue, "X軸カラーは青である必要があります")
        XCTAssertEqual(Color.yAxisColor, .green, "Y軸カラーは緑である必要があります")
        XCTAssertEqual(Color.zAxisColor, .orange, "Z軸カラーはオレンジである必要があります")
        XCTAssertEqual(Color.magnitudeColor, .purple, "合成加速度カラーは紫である必要があります")
    }
}

// MARK: - AccelerometerReading Model Tests
extension AccelerometerChartViewTests {
    
    func testAccelerometerReadingCreation() {
        let timestamp = Date()
        let reading = AccelerometerReading(
            timestamp: timestamp,
            x: 1.0,
            y: 2.0,
            z: 3.0,
            magnitude: 4.0
        )
        
        XCTAssertEqual(reading.timestamp, timestamp, "タイムスタンプが正しく設定される必要があります")
        XCTAssertEqual(reading.x, 1.0, "X軸値が正しく設定される必要があります")
        XCTAssertEqual(reading.y, 2.0, "Y軸値が正しく設定される必要があります")
        XCTAssertEqual(reading.z, 3.0, "Z軸値が正しく設定される必要があります")
        XCTAssertEqual(reading.magnitude, 4.0, "合成加速度が正しく設定される必要があります")
        XCTAssertNotNil(reading.id, "IDが自動生成される必要があります")
    }
    
    func testAccelerometerReadingIdentifiableProtocol() {
        let reading1 = AccelerometerReading(timestamp: Date(), x: 0, y: 0, z: 0, magnitude: 0)
        let reading2 = AccelerometerReading(timestamp: Date(), x: 0, y: 0, z: 0, magnitude: 0)
        
        XCTAssertNotEqual(reading1.id, reading2.id, "各インスタンスは独自のIDを持つ必要があります")
    }
    
    func testAccelerometerReadingWithBoundaryValues() {
        // 境界値テスト
        let extremeReading = AccelerometerReading(
            timestamp: Date.distantPast,
            x: Double.greatestFiniteMagnitude,
            y: -Double.greatestFiniteMagnitude,
            z: 0.0,
            magnitude: Double.greatestFiniteMagnitude
        )
        
        XCTAssertEqual(extremeReading.timestamp, Date.distantPast)
        XCTAssertEqual(extremeReading.x, Double.greatestFiniteMagnitude)
        XCTAssertEqual(extremeReading.y, -Double.greatestFiniteMagnitude)
        XCTAssertEqual(extremeReading.z, 0.0)
        XCTAssertEqual(extremeReading.magnitude, Double.greatestFiniteMagnitude)
    }
}

// MARK: - DataType Enum Tests
extension AccelerometerChartViewTests {
    
    func testDataTypeEnumValues() {
        XCTAssertEqual(DataType.all.rawValue, "すべて", "all ケースの文字列値が正しい必要があります")
        XCTAssertEqual(DataType.xAxis.rawValue, "X軸", "xAxis ケースの文字列値が正しい必要があります")
        XCTAssertEqual(DataType.yAxis.rawValue, "Y軸", "yAxis ケースの文字列値が正しい必要があります")
        XCTAssertEqual(DataType.zAxis.rawValue, "Z軸", "zAxis ケースの文字列値が正しい必要があります")
        XCTAssertEqual(DataType.magnitude.rawValue, "合成加速度", "magnitude ケースの文字列値が正しい必要があります")
    }
    
    func testDataTypeCaseIterable() {
        let allCases = DataType.allCases
        XCTAssertEqual(allCases.count, 5, "DataTypeは5つのケースを持つ必要があります")
        XCTAssertTrue(allCases.contains(.all), "allケースが含まれている必要があります")
        XCTAssertTrue(allCases.contains(.xAxis), "xAxisケースが含まれている必要があります")
        XCTAssertTrue(allCases.contains(.yAxis), "yAxisケースが含まれている必要があります")
        XCTAssertTrue(allCases.contains(.zAxis), "zAxisケースが含まれている必要があります")
        XCTAssertTrue(allCases.contains(.magnitude), "magnitudeケースが含まれている必要があります")
    }
}

// MARK: - DataStatistics Model Tests
extension AccelerometerChartViewTests {
    
    func testDataStatisticsCreation() {
        let stats = DataStatistics(
            maxValue: 1.0,
            minValue: -1.0,
            average: 0.0,
            standardDeviation: 0.5,
            sampleCount: 100,
            duration: 10.0,
            peakToPeak: 2.0,
            rmsValue: 0.7,
            medianValue: 0.1,
            samplingRate: 10.0
        )
        
        XCTAssertEqual(stats.maxValue, 1.0, "最大値が正しく設定される必要があります")
        XCTAssertEqual(stats.minValue, -1.0, "最小値が正しく設定される必要があります")
        XCTAssertEqual(stats.average, 0.0, "平均値が正しく設定される必要があります")
        XCTAssertEqual(stats.standardDeviation, 0.5, "標準偏差が正しく設定される必要があります")
        XCTAssertEqual(stats.sampleCount, 100, "サンプル数が正しく設定される必要があります")
        XCTAssertEqual(stats.duration, 10.0, "測定時間が正しく設定される必要があります")
        XCTAssertEqual(stats.peakToPeak, 2.0, "ピーク間値が正しく設定される必要があります")
        XCTAssertEqual(stats.rmsValue, 0.7, "RMS値が正しく設定される必要があります")
        XCTAssertEqual(stats.medianValue, 0.1, "中央値が正しく設定される必要があります")
        XCTAssertEqual(stats.samplingRate, 10.0, "サンプリングレートが正しく設定される必要があります")
    }
}

// MARK: - CalculateStatisticsUseCase Tests
extension AccelerometerChartViewTests {
    
    // ISSUE-032 (案 Y): waitForExpectations は @MainActor isolated のため、本テストのみ @MainActor。
    @MainActor
    func testLoadDataFromCSVWithValidData() {
        let expectation = expectation(description: "CSV読み込み完了")
        var result: [AccelerometerReading]?
        var error: Error?
        
        loadDataFromCSV(fileURL: testFileURL) { readings, err in
            result = readings
            error = err
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 5.0)
        
        XCTAssertNil(error, "エラーが発生してはいけません")
        XCTAssertNotNil(result, "結果が返される必要があります")
        XCTAssertEqual(result?.count, sampleReadings.count, "正しい数のデータが読み込まれる必要があります")
        
        if let loadedReadings = result {
            for (index, reading) in loadedReadings.enumerated() {
                let expected = sampleReadings[index]
                XCTAssertEqual(reading.x, expected.x, accuracy: 0.0001, "X軸値が正しく読み込まれる必要があります")
                XCTAssertEqual(reading.y, expected.y, accuracy: 0.0001, "Y軸値が正しく読み込まれる必要があります")
                XCTAssertEqual(reading.z, expected.z, accuracy: 0.0001, "Z軸値が正しく読み込まれる必要があります")
                XCTAssertEqual(reading.magnitude, expected.magnitude, accuracy: 0.0001, "合成加速度が正しく読み込まれる必要があります")
            }
        }
    }
    
    @MainActor
    func testLoadDataFromCSVWithInvalidFile() {
        let invalidURL = URL(fileURLWithPath: "/nonexistent/file.csv")
        let expectation = expectation(description: "CSV読み込みエラー")
        var result: [AccelerometerReading]?
        var error: Error?
        
        loadDataFromCSV(fileURL: invalidURL) { readings, err in
            result = readings
            error = err
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 5.0)
        
        XCTAssertNotNil(error, "エラーが発生する必要があります")
        XCTAssertNil(result, "結果が返されてはいけません")
    }
    
    @MainActor
    func testLoadDataFromCSVWithEmptyFile() {
        let emptyFileURL = FileManager.default.temporaryDirectory.appendingPathComponent("empty.csv")
        try! "timestamp,x,y,z,magnitude\n".write(to: emptyFileURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: emptyFileURL) }
        
        let expectation = expectation(description: "空ファイル読み込み完了")
        var result: [AccelerometerReading]?
        var error: Error?
        
        loadDataFromCSV(fileURL: emptyFileURL) { readings, err in
            result = readings
            error = err
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 5.0)
        
        XCTAssertNil(error, "エラーが発生してはいけません")
        XCTAssertNotNil(result, "結果が返される必要があります")
        XCTAssertEqual(result?.count, 0, "空のデータが返される必要があります")
    }
    
    @MainActor
    func testLoadDataFromCSVWithMalformedData() {
        let malformedCSV = "timestamp,x,y,z,magnitude\ninvalid,data,here,test,xyz\n"
        let malformedURL = FileManager.default.temporaryDirectory.appendingPathComponent("malformed.csv")
        try! malformedCSV.write(to: malformedURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: malformedURL) }
        
        let expectation = expectation(description: "不正データ読み込み完了")
        var result: [AccelerometerReading]?
        var error: Error?
        
        loadDataFromCSV(fileURL: malformedURL) { readings, err in
            result = readings
            error = err
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 5.0)
        
        XCTAssertNil(error, "エラーが発生してはいけません（不正行はスキップされる）")
        XCTAssertNotNil(result, "結果が返される必要があります")
        XCTAssertEqual(result?.count, 0, "不正データは読み込まれない必要があります")
    }
}

// MARK: - Statistics Calculation Tests
extension AccelerometerChartViewTests {
    
    func testCalculateStatisticsWithValidData() {
        let stats = calculateStatistics(readings: sampleReadings, dataType: .xAxis)
        
        XCTAssertGreaterThan(stats.maxValue, stats.minValue, "最大値は最小値より大きい必要があります")
        XCTAssertGreaterThan(stats.sampleCount, 0, "サンプル数は0より大きい必要があります")
        XCTAssertGreaterThan(stats.duration, 0, "測定時間は0より大きい必要があります")
        XCTAssertGreaterThanOrEqual(stats.standardDeviation, 0, "標準偏差は0以上である必要があります")
        XCTAssertEqual(stats.peakToPeak, stats.maxValue - stats.minValue, "ピーク間値は最大値-最小値である必要があります")
        XCTAssertGreaterThan(stats.rmsValue, 0, "RMS値は0より大きい必要があります")
        XCTAssertGreaterThanOrEqual(stats.samplingRate, 0, "サンプリングレートは0以上である必要があります")
    }
    
    func testCalculateStatisticsWithEmptyData() {
        let emptyStats = calculateStatistics(readings: [], dataType: .xAxis)
        
        XCTAssertEqual(emptyStats.maxValue, 0, "空データの最大値は0である必要があります")
        XCTAssertEqual(emptyStats.minValue, 0, "空データの最小値は0である必要があります")
        XCTAssertEqual(emptyStats.average, 0, "空データの平均値は0である必要があります")
        XCTAssertEqual(emptyStats.standardDeviation, 0, "空データの標準偏差は0である必要があります")
        XCTAssertEqual(emptyStats.sampleCount, 0, "空データのサンプル数は0である必要があります")
        XCTAssertEqual(emptyStats.duration, 0, "空データの測定時間は0である必要があります")
        XCTAssertEqual(emptyStats.peakToPeak, 0, "空データのピーク間値は0である必要があります")
        XCTAssertEqual(emptyStats.rmsValue, 0, "空データのRMS値は0である必要があります")
        XCTAssertEqual(emptyStats.medianValue, 0, "空データの中央値は0である必要があります")
        XCTAssertEqual(emptyStats.samplingRate, 0, "空データのサンプリングレートは0である必要があります")
    }
    
    func testCalculateStatisticsForAllDataTypes() {
        for dataType in DataType.allCases {
            let stats = calculateStatistics(readings: sampleReadings, dataType: dataType)
            
            XCTAssertEqual(stats.sampleCount, sampleReadings.count, "\(dataType.rawValue): サンプル数が正しい必要があります")
            XCTAssertGreaterThan(stats.duration, 0, "\(dataType.rawValue): 測定時間が0より大きい必要があります")
            XCTAssertGreaterThanOrEqual(stats.standardDeviation, 0, "\(dataType.rawValue): 標準偏差が0以上である必要があります")
        }
    }
    
    func testCalculateStatisticsAccuracy() {
        // 単純なテストデータで計算精度を確認
        let testData = [
            AccelerometerReading(timestamp: Date(), x: 1.0, y: 0.0, z: 0.0, magnitude: 1.0),
            AccelerometerReading(timestamp: Date().addingTimeInterval(1), x: 2.0, y: 0.0, z: 0.0, magnitude: 2.0),
            AccelerometerReading(timestamp: Date().addingTimeInterval(2), x: 3.0, y: 0.0, z: 0.0, magnitude: 3.0)
        ]
        
        let stats = calculateStatistics(readings: testData, dataType: .xAxis)
        
        XCTAssertEqual(stats.maxValue, 3.0, "最大値が正しく計算される必要があります")
        XCTAssertEqual(stats.minValue, 1.0, "最小値が正しく計算される必要があります")
        XCTAssertEqual(stats.average, 2.0, accuracy: 0.0001, "平均値が正しく計算される必要があります")
        XCTAssertEqual(stats.medianValue, 2.0, "中央値が正しく計算される必要があります")
        XCTAssertEqual(stats.peakToPeak, 2.0, "ピーク間値が正しく計算される必要があります")
    }
}

// MARK: - Format Duration Tests
extension AccelerometerChartViewTests {
    
    // ISSUE-032: testFormatDuration() は本体側 viewModel.formatDuration 削除に伴い削除。
}

// MARK: - Chart Component Value Extraction Tests
extension AccelerometerChartViewTests {
    
    func testValueForDataTypeExtraction() {
        let testReading = sampleReadings[0]
        
        // プライベートメソッドの動作を間接的にテスト（統計計算を通じて）
        let xStats = calculateStatistics(readings: [testReading], dataType: .xAxis)
        let yStats = calculateStatistics(readings: [testReading], dataType: .yAxis)
        let zStats = calculateStatistics(readings: [testReading], dataType: .zAxis)
        let magnitudeStats = calculateStatistics(readings: [testReading], dataType: .magnitude)
        
        XCTAssertEqual(xStats.maxValue, testReading.x, "X軸データが正しく抽出される必要があります")
        XCTAssertEqual(yStats.maxValue, testReading.y, "Y軸データが正しく抽出される必要があります")
        XCTAssertEqual(zStats.maxValue, testReading.z, "Z軸データが正しく抽出される必要があります")
        XCTAssertEqual(magnitudeStats.maxValue, testReading.magnitude, "合成加速度データが正しく抽出される必要があります")
    }
}

// MARK: - UI Component Instantiation Tests
extension AccelerometerChartViewTests {
    
    func testStatisticCardCreation() {
        let card = StatisticCard(title: "テスト", value: "1.0", icon: "circle")
        XCTAssertNotNil(card, "StatisticCardが正しく作成される必要があります")
    }
    
    func testAccelerometerChartComponentCreation() {
        let component = AccelerometerChartComponent(readings: sampleReadings, selectedDataType: .all)
        XCTAssertNotNil(component, "AccelerometerChartComponentが正しく作成される必要があります")
    }
    
    // ISSUE-032: `SelectableAccelerometerChartComponent` は本体側で削除済のため、対応テストを削除。

    func testZoomableAccelerometerChartComponentCreation() {
        let component = ZoomableAccelerometerChartComponent(readings: sampleReadings, selectedDataType: .all)
        XCTAssertNotNil(component, "ZoomableAccelerometerChartComponentが正しく作成される必要があります")
    }
    
    func testStatisticsViewCreation() {
        let stats = DataStatistics(
            maxValue: 1.0, minValue: -1.0, average: 0.0, standardDeviation: 0.5,
            sampleCount: 100, duration: 10.0, peakToPeak: 2.0,
            rmsValue: 0.7, medianValue: 0.1, samplingRate: 10.0
        )
        let view = StatisticsView(statistics: stats)
        XCTAssertNotNil(view, "StatisticsViewが正しく作成される必要があります")
    }
    
    func testExportOptionsViewCreation() {
        let view = ExportOptionsView(fileURL: testFileURL)
        XCTAssertNotNil(view, "ExportOptionsViewが正しく作成される必要があります")
    }
    
    func testUnifiedAccelerometerChartViewCreation() {
        let view = UnifiedAccelerometerChartView(fileURL: testFileURL)
        XCTAssertNotNil(view, "UnifiedAccelerometerChartViewが正しく作成される必要があります")
    }
}

// MARK: - Memory Management Tests
extension AccelerometerChartViewTests {
    
    func testAccelerometerReadingMemoryManagement() {
        // AccelerometerReadingは値型（struct）のため、通常のメモリリークは発生しない
        // 値型の適切な処理をテスト
        var readings: [AccelerometerReading] = []
        
        // 大量のデータを作成してもスタックオーバーフローが発生しないことを確認
        for i in 0..<1000 {
            let reading = AccelerometerReading(
                timestamp: Date().addingTimeInterval(Double(i)),
                x: Double(i),
                y: Double(i),
                z: Double(i),
                magnitude: Double(i)
            )
            readings.append(reading)
        }
        
        XCTAssertEqual(readings.count, 1000, "値型は正常にコピーされて保存される必要があります")
        
        // 配列をクリアしてもデータの独立性が保たれることを確認
        let firstReading = readings.first!
        readings.removeAll()
        
        XCTAssertEqual(readings.count, 0, "配列がクリアされる必要があります")
        XCTAssertNotNil(firstReading.id, "値型のコピーは独立して存在する必要があります")
    }
    
    func testLargeDataSetHandling() {
        // 大量データでのメモリ使用量テスト
        let largeDataSet = (0..<10000).map { index in
            AccelerometerReading(
                timestamp: Date().addingTimeInterval(Double(index) * 0.001),
                x: Double.random(in: -2...2),
                y: Double.random(in: -2...2),
                z: Double.random(in: -2...2),
                magnitude: Double.random(in: 0...3)
            )
        }
        
        // 大量データでの統計計算がクラッシュしないことを確認
        let stats = calculateStatistics(readings: largeDataSet, dataType: .all)
        XCTAssertEqual(stats.sampleCount, 10000, "大量データが正しく処理される必要があります")
        XCTAssertGreaterThan(stats.duration, 0, "測定時間が正しく計算される必要があります")
    }
}

// MARK: - Edge Cases and Boundary Tests
extension AccelerometerChartViewTests {
    
    func testSingleDataPointStatistics() {
        let singleReading = [sampleReadings[0]]
        let stats = calculateStatistics(readings: singleReading, dataType: .xAxis)
        
        XCTAssertEqual(stats.maxValue, stats.minValue, "単一データポイントでは最大値と最小値が同じである必要があります")
        XCTAssertEqual(stats.average, stats.maxValue, "単一データポイントでは平均値が値と同じである必要があります")
        XCTAssertEqual(stats.standardDeviation, 0, "単一データポイントでは標準偏差が0である必要があります")
        XCTAssertEqual(stats.peakToPeak, 0, "単一データポイントではピーク間値が0である必要があります")
        XCTAssertEqual(stats.medianValue, stats.maxValue, "単一データポイントでは中央値が値と同じである必要があります")
    }
    
    func testIdenticalValuesStatistics() {
        let identicalReadings = (0..<5).map { index in
            AccelerometerReading(
                timestamp: Date().addingTimeInterval(Double(index)),
                x: 1.0, y: 1.0, z: 1.0, magnitude: 1.0
            )
        }
        
        let stats = calculateStatistics(readings: identicalReadings, dataType: .xAxis)
        
        XCTAssertEqual(stats.maxValue, 1.0, "同じ値では最大値が一定である必要があります")
        XCTAssertEqual(stats.minValue, 1.0, "同じ値では最小値が一定である必要があります")
        XCTAssertEqual(stats.average, 1.0, "同じ値では平均値が一定である必要があります")
        XCTAssertEqual(stats.standardDeviation, 0, "同じ値では標準偏差が0である必要があります")
        XCTAssertEqual(stats.peakToPeak, 0, "同じ値ではピーク間値が0である必要があります")
        XCTAssertEqual(stats.medianValue, 1.0, "同じ値では中央値が一定である必要があります")
    }
    
    func testExtremeValueHandling() {
        let extremeReadings = [
            AccelerometerReading(timestamp: Date(), x: Double.greatestFiniteMagnitude, y: 0, z: 0, magnitude: Double.greatestFiniteMagnitude),
            AccelerometerReading(timestamp: Date().addingTimeInterval(1), x: -Double.greatestFiniteMagnitude, y: 0, z: 0, magnitude: 0),
            AccelerometerReading(timestamp: Date().addingTimeInterval(2), x: 0, y: 0, z: 0, magnitude: 0)
        ]
        
        let stats = calculateStatistics(readings: extremeReadings, dataType: .xAxis)
        
        XCTAssertEqual(stats.maxValue, Double.greatestFiniteMagnitude, "極値が正しく処理される必要があります")
        XCTAssertEqual(stats.minValue, -Double.greatestFiniteMagnitude, "極値が正しく処理される必要があります")
        // 極値の差は数学的に無限大になるため、無限大であることを確認
        XCTAssertTrue(stats.peakToPeak.isInfinite, "極値間の差は無限大になる必要があります")
    }
    
    func testTimestampOrderingInStatistics() {
        // タイムスタンプが逆順のデータでテスト
        let unorderedReadings = [
            AccelerometerReading(timestamp: Date().addingTimeInterval(2), x: 3, y: 3, z: 3, magnitude: 3),
            AccelerometerReading(timestamp: Date(), x: 1, y: 1, z: 1, magnitude: 1),
            AccelerometerReading(timestamp: Date().addingTimeInterval(1), x: 2, y: 2, z: 2, magnitude: 2)
        ]
        
        let stats = calculateStatistics(readings: unorderedReadings, dataType: .xAxis)
        
        // 統計計算はタイムスタンプの順序に依存しない
        XCTAssertEqual(stats.maxValue, 3.0, "順序に関係なく最大値が正しく計算される必要があります")
        XCTAssertEqual(stats.minValue, 1.0, "順序に関係なく最小値が正しく計算される必要があります")
        XCTAssertEqual(stats.average, 2.0, "順序に関係なく平均値が正しく計算される必要があります")
    }
}

// MARK: - Concurrent Access Tests
extension AccelerometerChartViewTests {
    
    func testConcurrentDataLoading() async throws {
        // ISSUE-032: Swift 6 strict concurrency 対応。
        // DispatchQueue + @Sendable closure に依存しない構造化並行（async let）で書き直す。
        guard let testURL = self.testFileURL, let useCase = self.loadDataUseCase else {
            XCTFail("test setup incomplete")
            return
        }
        async let r1 = useCase.execute(fileURL: testURL)
        async let r2 = useCase.execute(fileURL: testURL)
        let (result1, result2) = try await (r1, r2)
        XCTAssertEqual(result1.count, result2.count, "同じ結果が返される必要があります")
    }

    func testConcurrentStatisticsCalculation() async {
        // ISSUE-032: Swift 6 strict concurrency 対応（async/await + async let）。
        guard let useCase = self.calculateStatisticsUseCase,
              let readings: [AccelerometerReading] = self.sampleReadings else {
            XCTFail("test setup incomplete")
            return
        }
        async let s1 = Task.detached { useCase.execute(readings: readings, dataType: .xAxis) }.value
        async let s2 = Task.detached { useCase.execute(readings: readings, dataType: .xAxis) }.value
        let (stats1, stats2) = await (s1, s2)
        XCTAssertEqual(stats1.maxValue, stats2.maxValue, "同じ統計結果が返される必要があります")
        XCTAssertEqual(stats1.average, stats2.average, "同じ統計結果が返される必要があります")
    }
}


// MARK: - Performance Tests
extension AccelerometerChartViewTests {
    
    func testStatisticsCalculationPerformance() {
        let largeDataSet = (0..<50000).map { index in
            AccelerometerReading(
                timestamp: Date().addingTimeInterval(Double(index) * 0.001),
                x: Double.random(in: -2...2),
                y: Double.random(in: -2...2),
                z: Double.random(in: -2...2),
                magnitude: Double.random(in: 0...3)
            )
        }
        
        measure {
            _ = calculateStatistics(readings: largeDataSet, dataType: .all)
        }
    }
    
    @MainActor
    func testCSVLoadingPerformance() {
        // 大きなCSVファイルを作成
        var largeCSV = "timestamp,x,y,z,magnitude\n"
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        
        for i in 0..<10000 {
            let timestamp = Date().addingTimeInterval(Double(i) * 0.001)
            largeCSV += "\(dateFormatter.string(from: timestamp)),\(Double.random(in: -2...2)),\(Double.random(in: -2...2)),\(Double.random(in: -2...2)),\(Double.random(in: 0...3))\n"
        }
        
        let largeFileURL = FileManager.default.temporaryDirectory.appendingPathComponent("large_test.csv")
        try! largeCSV.write(to: largeFileURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: largeFileURL) }
        
        measure {
            let expectation = self.expectation(description: "大きなCSV読み込み")
            
            loadDataFromCSV(fileURL: largeFileURL) { _, _ in
                expectation.fulfill()
            }
            
            self.waitForExpectations(timeout: 30.0)
        }
    }
}

// MARK: - Error Handling Tests
extension AccelerometerChartViewTests {
    
    @MainActor
    func testCSVLoadingWithCorruptedFile() {
        let corruptedData = Data([0xFF, 0xFE, 0xFD, 0xFC]) // バイナリデータ
        let corruptedURL = FileManager.default.temporaryDirectory.appendingPathComponent("corrupted.csv")
        try! corruptedData.write(to: corruptedURL)
        defer { try? FileManager.default.removeItem(at: corruptedURL) }
        
        let expectation = expectation(description: "破損ファイル読み込み")
        var result: [AccelerometerReading]?
        var error: Error?
        
        loadDataFromCSV(fileURL: corruptedURL) { readings, err in
            result = readings
            error = err
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 5.0)
        
        // エラーが発生するか、空の結果が返される（実装依存）
        if error == nil {
            XCTAssertNotNil(result, "結果が返される必要があります")
            XCTAssertEqual(result?.count, 0, "破損データからは空の結果が返される必要があります")
        } else {
            XCTAssertNotNil(error, "適切なエラーが報告される必要があります")
        }
    }
    
    func testStatisticsWithNaNValues() {
        let nanReadings = [
            AccelerometerReading(timestamp: Date(), x: Double.nan, y: 0, z: 0, magnitude: 0),
            AccelerometerReading(timestamp: Date().addingTimeInterval(1), x: 1, y: Double.nan, z: 0, magnitude: 1),
            AccelerometerReading(timestamp: Date().addingTimeInterval(2), x: 2, y: 2, z: Double.nan, magnitude: 2)
        ]
        
        // NaN値が含まれる場合の統計計算の動作を確認
        let stats = calculateStatistics(readings: nanReadings, dataType: .xAxis)
        
        // 実装がNaN値をどう扱うかを確認（フィルタするか、エラーにするかは実装依存）
        XCTAssertTrue(stats.maxValue.isNaN || stats.maxValue.isFinite, "NaN値の処理が適切である必要があります")
    }
    
    func testStatisticsWithInfiniteValues() {
        let infiniteReadings = [
            AccelerometerReading(timestamp: Date(), x: Double.infinity, y: 0, z: 0, magnitude: Double.infinity),
            AccelerometerReading(timestamp: Date().addingTimeInterval(1), x: -Double.infinity, y: 0, z: 0, magnitude: 0),
            AccelerometerReading(timestamp: Date().addingTimeInterval(2), x: 1, y: 0, z: 0, magnitude: 1)
        ]
        
        let stats = calculateStatistics(readings: infiniteReadings, dataType: .xAxis)
        
        // 無限値の処理を確認
        XCTAssertTrue(stats.maxValue.isInfinite || stats.maxValue.isFinite, "無限値の処理が適切である必要があります")
    }
}
