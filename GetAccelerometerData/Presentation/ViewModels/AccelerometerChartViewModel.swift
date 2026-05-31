import Foundation
import SwiftUI

// MARK: - AccelerometerChartViewModel
// グラフ表示のViewModel（Presentation Layer）
@MainActor
class AccelerometerChartViewModel: ObservableObject {
    @Published var readings: [AccelerometerReading] = []
    @Published var selectedDataType: DataType = .all
    @Published var statistics: DataStatistics = DataStatistics.empty
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    private let loadDataUseCase: LoadAccelerometerDataUseCaseProtocol
    private let calculateStatisticsUseCase: CalculateStatisticsUseCaseProtocol
    
    init(
        loadDataUseCase: LoadAccelerometerDataUseCaseProtocol,
        calculateStatisticsUseCase: CalculateStatisticsUseCaseProtocol
    ) {
        self.loadDataUseCase = loadDataUseCase
        self.calculateStatisticsUseCase = calculateStatisticsUseCase
    }
    
    // MARK: - Public Methods
    
    func loadData(from fileURL: URL) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let loadedReadings = try await loadDataUseCase.execute(fileURL: fileURL)
            readings = loadedReadings
            updateStatistics()
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func updateSelectedDataType(_ dataType: DataType) {
        selectedDataType = dataType
        updateStatistics()
    }

    // MARK: - Private Methods
    
    private func updateStatistics() {
        statistics = calculateStatisticsUseCase.execute(readings: readings, dataType: selectedDataType)
    }
}
