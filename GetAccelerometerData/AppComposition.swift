import SwiftUI

// MARK: - AppComposition
// Composition Root：UseCase / Repository の生成を一元管理する。
// SwiftUI Environment 経由で各 View に注入される。
// Sendable struct として定義することで Swift 6 Strict Concurrency 下でも Environment に渡せる。
struct AppComposition: Sendable {
    let loadDataUseCase: LoadAccelerometerDataUseCaseProtocol
    let calculateStatisticsUseCase: CalculateStatisticsUseCaseProtocol

    init(
        loadDataUseCase: LoadAccelerometerDataUseCaseProtocol? = nil,
        calculateStatisticsUseCase: CalculateStatisticsUseCaseProtocol? = nil
    ) {
        let repository: AccelerometerDataRepositoryProtocol = AccelerometerDataRepository()
        self.loadDataUseCase = loadDataUseCase
            ?? LoadAccelerometerDataUseCase(repository: repository)
        self.calculateStatisticsUseCase = calculateStatisticsUseCase
            ?? CalculateStatisticsUseCase()
    }
}

// MARK: - Environment 注入
private struct AppCompositionKey: EnvironmentKey {
    static let defaultValue = AppComposition()
}

extension EnvironmentValues {
    var appComposition: AppComposition {
        get { self[AppCompositionKey.self] }
        set { self[AppCompositionKey.self] = newValue }
    }
}
