// VBT Motion Replay PoC Phase 5: SwiftUI 統合 View（最終フェーズ）。
// 内部設計書: .docs/07_vbt_motion_replay_internal_design.md §8.2
//
// 責務:
//   MotionReplayViewModel を保持し、警告 / 3D シーン / 再生コントロール（再生・スクラブ・経過時間） /
//   クォータニオン数値表示 / エラー表示を縦 VStack で組む。
//
// ガード方針:
//   ファイル全体を `#if canImport(UIKit) && os(iOS)` でガードし、
//   macOS テストランナーから不可視にする（SwiftUI/UIKit/SceneKit 依存のため）。

#if canImport(UIKit) && os(iOS)
import SwiftUI
import Foundation

public struct MotionReplayView: View {

    @StateObject private var viewModel = MotionReplayViewModel()
    private let folderURL: URL

    public init(folderURL: URL) {
        self.folderURL = folderURL
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 警告行
            Text("⚠ 相対姿勢のみ。絶対姿勢・長時間精度は保証されません")
                .font(.caption2)
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity, alignment: .leading)

            // 3D シーン
            MotionReplaySceneView(orientation: viewModel.state.currentOrientation)
                .frame(height: 320)
                .background(Color.black)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            // 再生コントロール行
            HStack(spacing: 12) {
                Button(action: { viewModel.togglePlayPause() }) {
                    Image(systemName: viewModel.state.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title2)
                }
                .disabled(viewModel.state.series.isEmpty)

                // スクラブバー
                GeometryReader { geo in
                    let duration = viewModel.state.series.duration
                    let progress = MotionReplayScrubMath.progress(
                        currentTime: viewModel.state.currentTime,
                        duration: duration
                    )
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.gray.opacity(0.3)).frame(height: 6)
                        Capsule().fill(Color.blue).frame(width: geo.size.width * progress, height: 6)
                        // ノブ x をクランプし、初期レイアウト時の左端はみ出しを回避（既定 14pt）
                        Circle().fill(Color.blue)
                            .frame(width: MotionReplayScrubMath.defaultKnobSize,
                                   height: MotionReplayScrubMath.defaultKnobSize)
                            .offset(x: MotionReplayScrubMath.knobOffsetX(progress: progress, width: geo.size.width))
                    }
                    .contentShape(Rectangle())
                    .gesture(
                        LongPressGesture(minimumDuration: 0.5)
                            .sequenced(before: DragGesture(minimumDistance: 0))
                            .onChanged { value in
                                if case .second(true, let drag?) = value, duration > 0 {
                                    let t = MotionReplayScrubMath.currentTimeFromDragLocation(
                                        x: drag.location.x,
                                        width: geo.size.width,
                                        duration: duration
                                    )
                                    viewModel.seek(to: t)
                                }
                            }
                    )
                    .allowsHitTesting(duration > 0)
                }
                .frame(height: 24)

                Text(String(format: "%.3f s", viewModel.state.currentTime))
                    .font(.caption.monospaced())
                    .frame(minWidth: 70, alignment: .trailing)
            }

            // クォータニオン数値表示
            Text(String(
                format: "q = (w: %+0.4f, x: %+0.4f, y: %+0.4f, z: %+0.4f)",
                viewModel.state.currentOrientation.w,
                viewModel.state.currentOrientation.x,
                viewModel.state.currentOrientation.y,
                viewModel.state.currentOrientation.z
            ))
            .font(.caption.monospaced())
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)

            // エラー表示（条件付き）
            if let err = viewModel.loadError {
                Text(err)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal)
        .navigationTitle("3D リプレイ [PoC]")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.load(folderURL: folderURL)
        }
    }
}
#endif
