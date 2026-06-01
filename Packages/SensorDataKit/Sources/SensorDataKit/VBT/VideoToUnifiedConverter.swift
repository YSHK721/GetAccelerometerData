import Foundation

// MARK: - VideoToUnifiedConverter
// VBT Ground Truth Tool Phase C: 動画ローカル時刻 → 統一時刻軸（IMU motion.timestamp 基準）への線形変換。
// 仕様書: .docs/VBT_GroundTruth_Tool_Spec.md §8
//   a = (sync_markers_imu.end - sync_markers_imu.start) /
//       (sync_markers_video.end - sync_markers_video.start)
//   b = sync_markers_imu.start - a * sync_markers_video.start
//   t_unified = a * t_video + b
//
// SRP: 「sync_markers の2点線形補正による動画→統一軸変換」のみを担う。
// 既存 `TimeAxisAligner` は同じ原理だが「imu→video（unified）」の向きを既に提供している。
// 本型は逆向き（video→unified）を独立して提供することで、UI 側で動画時刻を集約して
// SAVE 時にまとめて変換する責務分離を実現する。
public struct VideoToUnifiedConverter: Sendable {
    public let syncMarkersVideo: SyncMarker
    public let syncMarkersImu: SyncMarker
    private let slope: Double
    private let intercept: Double

    public enum ValidationError: Error, Equatable {
        case degenerateVideoSpan
    }

    public init(
        syncMarkersVideo: SyncMarker,
        syncMarkersImu: SyncMarker
    ) throws {
        let videoSpan = syncMarkersVideo.endTime - syncMarkersVideo.startTime
        guard videoSpan != 0 else { throw ValidationError.degenerateVideoSpan }
        let imuSpan = syncMarkersImu.endTime - syncMarkersImu.startTime
        self.syncMarkersVideo = syncMarkersVideo
        self.syncMarkersImu = syncMarkersImu
        self.slope = imuSpan / videoSpan
        self.intercept = syncMarkersImu.startTime - slope * syncMarkersVideo.startTime
    }

    public func videoToUnified(_ videoTime: TimeInterval) -> TimeInterval {
        slope * videoTime + intercept
    }
}
