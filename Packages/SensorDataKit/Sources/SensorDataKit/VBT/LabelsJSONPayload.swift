import Foundation

// MARK: - LabelsJSONPayload
// VBT Ground Truth Tool Phase C: labels.json 出力ペイロード。
// 仕様書: .docs/VBT_GroundTruth_Tool_Spec.md §8 / §10
//
// 既存 `LabeledSession` は単一 syncMarkers の旧構造を保持する別責務（後段で互換維持）。
// 本型は仕様書 Item8 で確定した「sync_markers_video / sync_markers_imu の2軸分離 + schema_version」
// に特化した DTO であり、Phase C で labels.json 永続化のために新規追加する。
//
// SRP: 「Phase C 確定スキーマでの labels.json 構造保持と整合性検証」のみを担う。
// 不変条件:
//   - sessionId 非空
//   - reps >= 1（仕様書 §10 確定条件 #3）
//   - 各 rep の rep_index が一意
public struct LabelsJSONPayload: Codable, Equatable, Sendable {
    public let sessionId: String
    public let schemaVersion: String
    public let syncMarkersVideo: SyncMarker
    public let syncMarkersImu: SyncMarker
    public let reps: [RepLabel]

    public enum ValidationError: Error, Equatable {
        case emptySessionId
        case emptyReps
        case duplicateRepIndex
    }

    public init(
        sessionId: String,
        syncMarkersVideo: SyncMarker,
        syncMarkersImu: SyncMarker,
        reps: [RepLabel],
        schemaVersion: String = "1.0"
    ) throws {
        guard !sessionId.isEmpty else { throw ValidationError.emptySessionId }
        guard !reps.isEmpty else { throw ValidationError.emptyReps }
        let indices = reps.map(\.repIndex)
        if Set(indices).count != indices.count {
            throw ValidationError.duplicateRepIndex
        }
        self.sessionId = sessionId
        self.schemaVersion = schemaVersion
        self.syncMarkersVideo = syncMarkersVideo
        self.syncMarkersImu = syncMarkersImu
        self.reps = reps
    }

    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case schemaVersion = "schema_version"
        case syncMarkersVideo = "sync_markers_video"
        case syncMarkersImu = "sync_markers_imu"
        case reps
    }
}
