import SwiftUI

// MARK: - VBTRecordingView
// 仕様書: .docs/VBT_GroundTruth_Tool_Spec.md Phase A
//
// 最小 UI（Watch 側）:
//   - 「記録開始」ボタン（idle のときのみ有効）
//   - 「記録停止」ボタン（recording のときのみ有効）
//   - 状態表示
//   - エラーメッセージ表示（Item9 通知文言）
//
// 既存 ContentView の置換ではなく、Phase A の検証用ビューとして追加する。

struct VBTRecordingView: View {
    @StateObject private var controller = VBTRecordingController()

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                Text("VBT 記録 (Phase A)")
                    .font(.headline)

                stateLabel

                switch controller.uiState {
                case .idle, .completed, .failed:
                    Button("記録開始") {
                        Task { await controller.tapStartRecording() }
                    }
                    .buttonStyle(.borderedProminent)
                case .recording:
                    Button("記録停止") {
                        Task { await controller.tapStopRecording() }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                case .starting, .stopping:
                    ProgressView()
                }

                if case .failed(let message) = controller.uiState {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                    if !controller.prerequisitesMissing.isEmpty {
                        Text("欠落: \(controller.prerequisitesMissing.joined(separator: ", "))")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                    Button("リトライ") {
                        controller.reset()
                    }
                    .buttonStyle(.bordered)
                }

                if case .completed = controller.uiState {
                    Text("セッション保存完了")
                        .font(.caption)
                        .foregroundStyle(.green)
                    Button("次のセッション") {
                        controller.reset()
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(.horizontal, 8)
        }
    }

    @ViewBuilder
    private var stateLabel: some View {
        switch controller.uiState {
        case .idle:
            Text("待機中").font(.caption).foregroundStyle(.secondary)
        case .starting:
            Text("録画開始要求中...").font(.caption).foregroundStyle(.secondary)
        case .recording:
            Text("● 記録中").font(.caption).foregroundStyle(.red)
        case .stopping:
            Text("停止処理中...").font(.caption).foregroundStyle(.secondary)
        case .completed:
            Text("✓ 完了").font(.caption).foregroundStyle(.green)
        case .failed:
            Text("✗ 失敗").font(.caption).foregroundStyle(.red)
        }
    }
}

#Preview {
    VBTRecordingView()
}
