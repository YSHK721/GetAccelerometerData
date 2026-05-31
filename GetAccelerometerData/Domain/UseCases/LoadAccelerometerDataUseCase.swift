import Foundation

// MARK: - LoadAccelerometerDataUseCase
// 加速度データ読み込みのユースケース（Domain）
protocol LoadAccelerometerDataUseCaseProtocol: Sendable {
    func execute(fileURL: URL) async throws -> [AccelerometerReading]
}

final class LoadAccelerometerDataUseCase: LoadAccelerometerDataUseCaseProtocol {
    private let repository: AccelerometerDataRepositoryProtocol

    init(repository: AccelerometerDataRepositoryProtocol) {
        self.repository = repository
    }

    func execute(fileURL: URL) async throws -> [AccelerometerReading] {
        return try await repository.loadDataFromCSV(fileURL: fileURL)
    }
}
