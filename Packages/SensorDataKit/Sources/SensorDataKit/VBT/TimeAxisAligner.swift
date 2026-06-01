import Foundation

// MARK: - TimeAxisAligner
// VBT Ground Truth Tool: 物理マーカー2点による IMU 時刻軸 → 統一時刻軸（動画時刻軸）への線形マッピング。
// 仕様書: .docs/VBT_GroundTruth_Tool_Spec.md §5
//   「マーカーは記録開始直後と終了直前の計2回必須とし、2点で線形に時刻を対応づける（クロックドリフト補正）」
//
// SRP: 「2点線形補正の計算」のみを担う。マーカーの抽出・検出は責務外（人手確認）。
// 不変条件: imuMarkerTimes / videoMarkerTimes ともに start != end（傾きが定義可能であること）。
public struct TimeAxisAligner: Sendable {
    public let imuMarkerTimes: (start: TimeInterval, end: TimeInterval)
    public let videoMarkerTimes: (start: TimeInterval, end: TimeInterval)
    private let slope: Double
    private let intercept: Double

    public enum ValidationError: Error, Equatable {
        case degenerateMarkers
    }

    public init(
        imuMarkerTimes: (start: TimeInterval, end: TimeInterval),
        videoMarkerTimes: (start: TimeInterval, end: TimeInterval)
    ) throws {
        let imuSpan = imuMarkerTimes.end - imuMarkerTimes.start
        let videoSpan = videoMarkerTimes.end - videoMarkerTimes.start
        guard imuSpan != 0, videoSpan != 0 else {
            throw ValidationError.degenerateMarkers
        }
        self.imuMarkerTimes = imuMarkerTimes
        self.videoMarkerTimes = videoMarkerTimes
        // unified = slope * imu + intercept
        self.slope = videoSpan / imuSpan
        self.intercept = videoMarkerTimes.start - slope * imuMarkerTimes.start
    }

    /// IMU 時刻軸上の値を統一時刻軸（動画時刻軸）に変換する。
    /// マーカー2点の外側に対しては線形外挿する（後段の解釈は呼び出し側が判断する）。
    public func imuTimeToUnified(_ imuTime: TimeInterval) -> TimeInterval {
        slope * imuTime + intercept
    }
}
