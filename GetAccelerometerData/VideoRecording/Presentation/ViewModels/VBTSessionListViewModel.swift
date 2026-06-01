import Foundation
import SwiftUI
import SensorDataKit

// MARK: - VBTSessionListViewModel
// VBT Ground Truth Tool Phase C/D: セッション一覧 ViewModel。
// 仕様書: .docs/VBT_GroundTruth_Tool_Spec.md §10 / §8
//   - Phase C: VALID 状態のみ表示、タップでラベリング画面へ遷移
//   - Phase D: 各行に isExportable（labels.json 存在）を含め、共有シート起動 URL を解決
//
// Clean Architecture: ViewModel は UseCase / Port に依存し、Infrastructure は知らない。
@MainActor
final class VBTSessionListViewModel: ObservableObject {

    struct Row: Identifiable, Equatable {
        let id: String
        let entry: SessionListEntry
        let folderURL: URL
        let isExportable: Bool
    }

    @Published private(set) var rows: [Row] = []
    @Published private(set) var errorMessage: String?

    private let useCase: LoadSessionListUseCase
    private let labelsChecker: LabelsExistenceCheckerPort
    private let exportUseCase: ExportSessionUseCase

    init(
        useCase: LoadSessionListUseCase,
        labelsChecker: LabelsExistenceCheckerPort,
        exportUseCase: ExportSessionUseCase
    ) {
        self.useCase = useCase
        self.labelsChecker = labelsChecker
        self.exportUseCase = exportUseCase
    }

    func reload() {
        do {
            let outputs = try useCase.execute()
            self.rows = outputs.map { output in
                let exportable = labelsChecker.labelsExist(in: output.folderURL)
                return Row(
                    id: output.entry.folderName,
                    entry: output.entry,
                    folderURL: output.folderURL,
                    isExportable: exportable
                )
            }
            self.errorMessage = nil
        } catch {
            self.rows = []
            self.errorMessage = "セッション一覧の読み込みに失敗: \(error.localizedDescription)"
        }
    }

    /// Phase D: 指定セッション ID のエクスポート対象フォルダ URL を解決する。
    /// 不可セッション（VALID 未満 / labels.json 未生成）は nil を返し、UI 側は共有シートを開かない。
    func resolveExportURL(sessionId: String) -> URL? {
        do {
            return try exportUseCase.execute(sessionId: sessionId)
        } catch {
            self.errorMessage = "エクスポート不可: \(error.localizedDescription)"
            return nil
        }
    }
}
