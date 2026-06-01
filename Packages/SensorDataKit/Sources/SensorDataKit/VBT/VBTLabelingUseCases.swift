import Foundation

// MARK: - VBT Labeling Use Cases
// VBT Ground Truth Tool Phase C: 仕様書 §10 ラベリング UI を支える Application Business Rules 層。
//
// Clean Architecture:
//   - Input Boundary は SwiftUI ViewModel から直接呼び出される（小規模アプリのため Controller 省略）
//   - Output Boundary は `VBTLabelingPorts.swift` の 3 Port（Session/IMU/Labels）
//
// SRP: 各 UseCase は単一目的（一覧・波形・保存）に分割し、状態機械 `LabelingState` を入力にとる。

// MARK: - LoadSessionListUseCase

public final class LoadSessionListUseCase: Sendable {

    public struct Output: Sendable, Equatable {
        public let entry: SessionListEntry
        public let folderURL: URL
        public init(entry: SessionListEntry, folderURL: URL) {
            self.entry = entry
            self.folderURL = folderURL
        }
    }

    private let loader: SessionListLoaderPort

    public init(loader: SessionListLoaderPort) {
        self.loader = loader
    }

    public func execute() throws -> [Output] {
        let raw = try loader.loadAll()
        // VALID フィルタ + DTO 変換
        return raw
            .filter { $0.meta.sessionState == .valid }
            .map { item in
                Output(
                    entry: SessionListEntry(
                        folderName: item.folderName,
                        exercise: item.meta.exercise,
                        weightKg: item.meta.weightKg,
                        setIndex: item.meta.setIndex,
                        subjectId: item.meta.subjectId
                    ),
                    folderURL: item.folderURL
                )
            }
    }
}

// MARK: - LoadIMUWaveformUseCase

public final class LoadIMUWaveformUseCase: Sendable {
    private let loader: IMUWaveformLoaderPort

    public init(loader: IMUWaveformLoaderPort) {
        self.loader = loader
    }

    public func execute(folderURL: URL) throws -> [IMUWaveformSample] {
        try loader.load(fromFolder: folderURL)
    }
}

// MARK: - SaveLabelsUseCase

public final class SaveLabelsUseCase: Sendable {
    private let store: LabelsStorePort

    public init(store: LabelsStorePort) {
        self.store = store
    }

    public func execute(state: LabelingState, folder: URL) throws {
        let payload = try state.buildPayload()
        try store.writeLabelsJSON(payload, to: folder)
    }
}
