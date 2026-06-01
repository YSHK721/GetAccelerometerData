import Foundation

// MARK: - LabelingState
// VBT Ground Truth Tool Phase C: ラベリング UI 状態機械（仕様書 §10）。
//
// 設計判断:
//   - UI 操作中は「動画ローカル時刻」で rep の bottom/start/end を内部保持する（仕様書 §10「時刻系の正準」）。
//   - SAVE 時に `VideoToUnifiedConverter` で統一時刻軸に変換し `LabelsJSONPayload` を構築する。
//   - sync_markers_video / sync_markers_imu は変換不要でそのまま書き出す。
//
// SRP: 「UI イベント受信 → 内部状態更新 → 確定条件判定 → SAVE 用 DTO 構築」のみ。
//      AVPlayer / FileManager / Swift Charts 等の外部技術依存を持たない（純粋値型）。
//
// クライアント: `LabelingViewModel`（Presentation 層）から呼び出される。
public struct LabelingState: Sendable, Equatable {

    public struct RepDraft: Sendable, Equatable {
        public var repIndex: Int
        public var bottomTimeVideo: TimeInterval
        public var startTimeVideo: TimeInterval?
        public var endTimeVideo: TimeInterval?
    }

    public enum MissingRequirement: Sendable, Equatable, Hashable {
        case syncVideoStart
        case syncVideoEnd
        case syncImuStart
        case syncImuEnd
        case atLeastOneRep
        case bottomTimeMissing(repIndex: Int)
    }

    public enum BuildError: Error, Equatable {
        case requirementsNotMet([MissingRequirement])
        case converterFailed
        case repLabelValidationFailed
    }

    public let sessionId: String

    // 動画側マーカー（動画ローカル時刻）
    public private(set) var syncMarkerVideoStart: TimeInterval?
    public private(set) var syncMarkerVideoEnd: TimeInterval?
    // IMU 側マーカー（統一時刻軸 = IMU motion.timestamp）
    public private(set) var syncMarkerImuStart: TimeInterval?
    public private(set) var syncMarkerImuEnd: TimeInterval?

    public private(set) var repsDraft: [RepDraft] = []

    public init(sessionId: String) {
        self.sessionId = sessionId
    }

    // MARK: - UI イベント受信

    public mutating func recordBottom(atVideoTime time: TimeInterval) {
        let nextIndex = (repsDraft.map(\.repIndex).max() ?? 0) + 1
        repsDraft.append(RepDraft(
            repIndex: nextIndex,
            bottomTimeVideo: time,
            startTimeVideo: nil,
            endTimeVideo: nil
        ))
    }

    /// 仕様書 §10:「最大 rep_index を持つレップに上書き」
    public mutating func recordStart(atVideoTime time: TimeInterval) {
        guard let idx = indexOfMaxRep() else { return }
        repsDraft[idx].startTimeVideo = time
    }

    public mutating func recordEnd(atVideoTime time: TimeInterval) {
        guard let idx = indexOfMaxRep() else { return }
        repsDraft[idx].endTimeVideo = time
    }

    public mutating func recordSyncStartVideo(at time: TimeInterval) {
        syncMarkerVideoStart = time
    }

    public mutating func recordSyncEndVideo(at time: TimeInterval) {
        syncMarkerVideoEnd = time
    }

    public mutating func recordSyncStartImu(at time: TimeInterval) {
        syncMarkerImuStart = time
    }

    public mutating func recordSyncEndImu(at time: TimeInterval) {
        syncMarkerImuEnd = time
    }

    /// 配列インデックス（rep_index ではない）で削除し、rep_index を 1 始まりで再採番。
    public mutating func deleteRep(at arrayIndex: Int) {
        guard repsDraft.indices.contains(arrayIndex) else { return }
        repsDraft.remove(at: arrayIndex)
        for i in repsDraft.indices {
            repsDraft[i].repIndex = i + 1
        }
    }

    // MARK: - 確定条件判定（仕様書 §10）

    public var missingRequirements: [MissingRequirement] {
        var missing: [MissingRequirement] = []
        if syncMarkerVideoStart == nil { missing.append(.syncVideoStart) }
        if syncMarkerVideoEnd == nil { missing.append(.syncVideoEnd) }
        if syncMarkerImuStart == nil { missing.append(.syncImuStart) }
        if syncMarkerImuEnd == nil { missing.append(.syncImuEnd) }
        if repsDraft.isEmpty { missing.append(.atLeastOneRep) }
        // bottom_time は構造上必ず付与されるため通常欠落しないが、防御的に検証
        for rep in repsDraft where rep.bottomTimeVideo.isNaN {
            missing.append(.bottomTimeMissing(repIndex: rep.repIndex))
        }
        return missing
    }

    public var canSave: Bool { missingRequirements.isEmpty }

    // MARK: - SAVE: 動画時刻 → 統一時刻軸変換 + DTO 構築

    public func buildPayload() throws -> LabelsJSONPayload {
        let missing = missingRequirements
        guard missing.isEmpty else {
            throw BuildError.requirementsNotMet(missing)
        }
        // 確定条件で nil 不在を保証済み
        let videoStart = syncMarkerVideoStart!
        let videoEnd = syncMarkerVideoEnd!
        let imuStart = syncMarkerImuStart!
        let imuEnd = syncMarkerImuEnd!

        let videoMarker: SyncMarker
        let imuMarker: SyncMarker
        do {
            videoMarker = try SyncMarker(startTime: videoStart, endTime: videoEnd)
            imuMarker = try SyncMarker(startTime: imuStart, endTime: imuEnd)
        } catch {
            throw BuildError.converterFailed
        }

        let converter: VideoToUnifiedConverter
        do {
            converter = try VideoToUnifiedConverter(
                syncMarkersVideo: videoMarker,
                syncMarkersImu: imuMarker
            )
        } catch {
            throw BuildError.converterFailed
        }

        var convertedReps: [RepLabel] = []
        for rep in repsDraft {
            let bottom = converter.videoToUnified(rep.bottomTimeVideo)
            let start = rep.startTimeVideo.map(converter.videoToUnified)
            let end = rep.endTimeVideo.map(converter.videoToUnified)
            do {
                let label = try RepLabel(
                    repIndex: rep.repIndex,
                    bottomTime: bottom,
                    startTime: start,
                    endTime: end
                )
                convertedReps.append(label)
            } catch {
                throw BuildError.repLabelValidationFailed
            }
        }

        do {
            return try LabelsJSONPayload(
                sessionId: sessionId,
                syncMarkersVideo: videoMarker,
                syncMarkersImu: imuMarker,
                reps: convertedReps
            )
        } catch {
            throw BuildError.repLabelValidationFailed
        }
    }

    // MARK: - Helpers

    private func indexOfMaxRep() -> Int? {
        guard !repsDraft.isEmpty else { return nil }
        var maxIdx = 0
        for i in repsDraft.indices where repsDraft[i].repIndex > repsDraft[maxIdx].repIndex {
            maxIdx = i
        }
        return maxIdx
    }
}
