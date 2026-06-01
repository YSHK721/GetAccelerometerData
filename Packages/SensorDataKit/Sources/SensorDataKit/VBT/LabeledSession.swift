import Foundation

// MARK: - LabeledSession
// VBT Ground Truth Tool: labels.json のトップ構造。
// 仕様書: .docs/VBT_GroundTruth_Tool_Spec.md §8（labels.json）
//
// SRP: ラベル付きセッション全体の整合性（session_id・マーカー・rep_index 一意性）を集約。
public struct LabeledSession: Codable, Equatable, Sendable {
    public let sessionId: String
    public let syncMarkers: SyncMarker
    public let reps: [RepLabel]

    public enum ValidationError: Error, Equatable {
        case emptySessionId
        case duplicateRepIndex
    }

    public init(
        sessionId: String,
        syncMarkers: SyncMarker,
        reps: [RepLabel]
    ) throws {
        guard !sessionId.isEmpty else { throw ValidationError.emptySessionId }
        let indices = reps.map(\.repIndex)
        if Set(indices).count != indices.count {
            throw ValidationError.duplicateRepIndex
        }
        self.sessionId = sessionId
        self.syncMarkers = syncMarkers
        self.reps = reps
    }

    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case syncMarkers = "sync_markers"
        case reps
    }
}
