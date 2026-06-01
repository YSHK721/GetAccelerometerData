import Foundation

// MARK: - SessionListEntry
// VBT Ground Truth Tool Phase C: セッション一覧画面（仕様書 §10）の表示単位。
// SRP: ラベリング対象セッションの「フォルダ名 + 主要メタ」のみを保持する DTO。
public struct SessionListEntry: Sendable, Equatable, Identifiable {
    public var id: String { folderName }
    public let folderName: String
    public let exercise: String
    public let weightKg: Double
    public let setIndex: Int
    public let subjectId: String

    public init(folderName: String, exercise: String, weightKg: Double, setIndex: Int, subjectId: String) {
        self.folderName = folderName
        self.exercise = exercise
        self.weightKg = weightKg
        self.setIndex = setIndex
        self.subjectId = subjectId
    }
}

// MARK: - SessionListFilter
// 仕様書 §10:「session_state == "VALID" のみ表示」
// SRP: VALID フィルタ + DTO 変換のみ（FileManager 走査は Infrastructure 層）。
public enum SessionListFilter {
    public static func filter(metas: [(folderName: String, meta: MetaJSONPayload)]) -> [SessionListEntry] {
        metas
            .filter { $0.meta.sessionState == .valid }
            .map { pair in
                SessionListEntry(
                    folderName: pair.folderName,
                    exercise: pair.meta.exercise,
                    weightKg: pair.meta.weightKg,
                    setIndex: pair.meta.setIndex,
                    subjectId: pair.meta.subjectId
                )
            }
    }
}
