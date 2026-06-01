import Foundation
import SwiftUI
import SensorDataKit

// MARK: - VBTSessionListViewModel
// VBT Ground Truth Tool Phase C: セッション一覧 ViewModel。
// 仕様書: .docs/VBT_GroundTruth_Tool_Spec.md §10 セッション一覧画面
//   - VALID 状態のみ表示
//   - タップでラベリング画面へ遷移（View 側で NavigationLink）
//
// Clean Architecture: ViewModel は UseCase に依存し、Infrastructure は知らない。
@MainActor
final class VBTSessionListViewModel: ObservableObject {

    struct Row: Identifiable, Equatable {
        let id: String
        let entry: SessionListEntry
        let folderURL: URL
    }

    @Published private(set) var rows: [Row] = []
    @Published private(set) var errorMessage: String?

    private let useCase: LoadSessionListUseCase

    init(useCase: LoadSessionListUseCase) {
        self.useCase = useCase
    }

    func reload() {
        do {
            let outputs = try useCase.execute()
            self.rows = outputs.map {
                Row(id: $0.entry.folderName, entry: $0.entry, folderURL: $0.folderURL)
            }
            self.errorMessage = nil
        } catch {
            self.rows = []
            self.errorMessage = "セッション一覧の読み込みに失敗: \(error.localizedDescription)"
        }
    }
}
