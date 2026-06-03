import SwiftUI
import AVKit
import Charts
import SensorDataKit

// MARK: - VBTLabelingView
// VBT Ground Truth Tool Phase C: ラベリング画面（仕様書 §10）。
//
// 構成:
//   1. 動画プレイヤー領域（AVKit VideoPlayer）
//   2. IMU 加速度マグニチュード波形プレビュー（Swift Charts, iOS 16+）
//   3. タイムスクラブバー（動画ローカル時刻 / IMU 統一時刻軸の2軸）
//   4. イベント記録ボタン群（BOTTOM / START / END / SYNC START/END Video / SYNC START/END IMU）
//   5. レップ一覧（左スワイプで削除）
//   6. SAVE ボタン（確定条件未満は無効化 + 赤字で欠落要素を表示）
struct VBTLabelingView: View {

    @StateObject private var viewModel: VBTLabelingViewModel

    init(sessionId: String, folderURL: URL) {
        let composition = VBTGroundTruthMetaInputViewModel.shared
        _viewModel = StateObject(wrappedValue: VBTLabelingViewModel(
            sessionId: sessionId,
            folderURL: folderURL,
            loadIMU: composition.loadIMUWaveformUseCase,
            saveLabels: composition.saveLabelsUseCase
        ))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // ISSUE-025: セッション識別ヘッダ（どのセッションを開いているか即確認）
                sessionHeader

                // 1) 動画プレイヤー
                VideoPlayer(player: viewModel.player)
                    .frame(height: 240)
                    .background(Color.black)

                // 動画コマ送り操作
                HStack(spacing: 16) {
                    Button { viewModel.stepBackward() } label: {
                        Image(systemName: "backward.frame.fill")
                            .frame(maxWidth: .infinity)
                    }
                    Button { viewModel.togglePlayPause() } label: {
                        Image(systemName: "playpause.fill")
                            .frame(maxWidth: .infinity)
                    }
                    Button { viewModel.stepForward() } label: {
                        Image(systemName: "forward.frame.fill")
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal)

                // 動画タイムスクラブ（500ms 長押し + ドラッグ：仕様書 §10）
                videoScrubBar

                // 2) IMU 波形 + カーソル
                imuWaveformView

                // 3) 現在の時刻表示（2軸）
                timeAxisDisplay

                // 4) イベント記録ボタン
                eventButtonsSection

                // 5) レップ一覧
                repsListSection

                // 6) SAVE
                saveSection
            }
            .padding(.vertical, 8)
        }
        .navigationTitle("ラベリング")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { viewModel.load() }
    }

    // MARK: - 動画スクラブバー
    @ViewBuilder
    private var videoScrubBar: some View {
        GeometryReader { geo in
            let progress: Double = {
                guard viewModel.videoDuration > 0 else { return 0 }
                return min(1.0, max(0.0, viewModel.currentVideoTime / viewModel.videoDuration))
            }()
            ZStack(alignment: .leading) {
                Capsule().fill(Color.gray.opacity(0.3)).frame(height: 6)
                Capsule().fill(Color.blue).frame(width: geo.size.width * progress, height: 6)
                Circle()
                    .fill(Color.blue)
                    .frame(width: 14, height: 14)
                    .offset(x: geo.size.width * progress - 7)
            }
            .contentShape(Rectangle())
            .gesture(
                LongPressGesture(minimumDuration: 0.5)
                    .sequenced(before: DragGesture(minimumDistance: 0))
                    .onChanged { value in
                        switch value {
                        case .second(true, let drag?):
                            viewModel.isScrubbing = true
                            let ratio = min(1.0, max(0.0, drag.location.x / geo.size.width))
                            viewModel.seek(to: ratio * viewModel.videoDuration)
                        default:
                            break
                        }
                    }
                    .onEnded { _ in
                        viewModel.isScrubbing = false
                    }
            )
        }
        .frame(height: 24)
        .padding(.horizontal)
    }

    // MARK: - IMU 波形
    @ViewBuilder
    private var imuWaveformView: some View {
        if viewModel.samples.isEmpty {
            VStack(spacing: 4) {
                Text("IMU 波形なし")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                // ISSUE-024: 失敗理由を表示（silent failure 防止）
                if let reason = viewModel.imuLoadError {
                    Text(reason)
                        .font(.caption2)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }
            .frame(height: 120)
        } else {
            // ISSUE-026: timestamp は UNIX 秒（≈1.78e9）で桁が大きすぎ Swift Charts が
            // domain を 0..1.78e9 に自動拡張して波形が右端に潰れる。
            // X 軸をプロット用に「録画開始からの相対秒」に変換して描画する。
            // 内部保持（imuCursorTime / sync_markers 等）は仕様書 §8 の線形変換に
            // 必要なため UNIX 秒のまま維持し、表示変換のみで対応する。
            let base = viewModel.firstSampleTimestamp ?? viewModel.samples.first?.timestamp ?? 0
            let cursorRel = viewModel.imuCursorTime - base
            Chart {
                ForEach(Array(viewModel.samples.enumerated()), id: \.offset) { _, sample in
                    LineMark(
                        x: .value("t (s)", sample.timestamp - base),
                        y: .value("|a|", sample.accelMagnitude)
                    )
                }
                RuleMark(x: .value("cursor", cursorRel))
                    .foregroundStyle(.red)
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
            }
            .frame(height: 140)
            .padding(.horizontal)
            .gesture(
                LongPressGesture(minimumDuration: 0.5)
                    .sequenced(before: DragGesture(minimumDistance: 0))
                    .onChanged { value in
                        if case .second(true, let drag?) = value {
                            // 波形カーソルを drag.x 比率で動かす（簡易マッピング）
                            if let first = viewModel.samples.first?.timestamp,
                               let last = viewModel.samples.last?.timestamp,
                               last > first {
                                // 画面幅は GeometryReader を介さない簡易計算。
                                // 改善は後段で（仕様書範囲外）。
                                let ratio = max(0.0, min(1.0, drag.location.x / 300.0))
                                viewModel.imuCursorTime = first + ratio * (last - first)
                            }
                        }
                    }
            )
        }
    }

    // MARK: - セッション識別ヘッダ（ISSUE-025）
    @ViewBuilder
    private var sessionHeader: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(viewModel.folderName)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .truncationMode(.middle)
            if let meta = viewModel.sessionMeta {
                HStack(spacing: 8) {
                    Text(meta.exercise)
                        .font(.subheadline.weight(.semibold))
                    Text("\(meta.weightKg, specifier: "%.1f") kg")
                        .font(.caption)
                    Text("set \(meta.setIndex)")
                        .font(.caption)
                    Text("rep目標 \(meta.repTarget)")
                        .font(.caption)
                    Spacer()
                    Text(meta.sessionState.rawValue)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(meta.sessionState == .valid ? Color.green.opacity(0.2) : Color.orange.opacity(0.2))
                        .clipShape(Capsule())
                }
                if let iso = meta.videoStartIso8601 {
                    Text("録画開始: \(iso)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("meta.json 未読込")
                    .font(.caption2)
                    .foregroundStyle(.red)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
        .padding(.top, 4)
    }

    // MARK: - 時刻表示
    @ViewBuilder
    private var timeAxisDisplay: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(String(format: "動画ローカル: %.3f s", viewModel.currentVideoTime))
            // ISSUE-025: 統一時刻軸（UNIX 秒）+ 録画開始からの相対秒を併記
            Text(String(
                format: "IMU 統一軸: %.3f s（録画開始+%.3f s）",
                viewModel.imuCursorTime,
                viewModel.relativeCursorTime
            ))
        }
        .font(.caption.monospaced())
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
    }

    // MARK: - イベントボタン
    @ViewBuilder
    private var eventButtonsSection: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Button("BOTTOM") { viewModel.recordBottom() }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
                Button("START") { viewModel.recordStart() }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
                    .disabled(viewModel.state.repsDraft.isEmpty)
                Button("END") { viewModel.recordEnd() }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
                    .disabled(viewModel.state.repsDraft.isEmpty)
            }
            HStack(spacing: 8) {
                Button("SYNC START (Video)") { viewModel.recordSyncStartVideo() }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
                Button("SYNC END (Video)") { viewModel.recordSyncEndVideo() }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
            }
            HStack(spacing: 8) {
                Button("SYNC START (IMU)") { viewModel.recordSyncStartImu() }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
                Button("SYNC END (IMU)") { viewModel.recordSyncEndImu() }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
            }
        }
        .font(.caption)
        .padding(.horizontal)
    }

    // MARK: - レップ一覧
    @ViewBuilder
    private var repsListSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Reps（\(viewModel.state.repsDraft.count)）")
                .font(.headline)
            if viewModel.state.repsDraft.isEmpty {
                Text("レップ未登録")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                List {
                    ForEach(Array(viewModel.state.repsDraft.enumerated()), id: \.element.repIndex) { idx, rep in
                        VStack(alignment: .leading, spacing: 2) {
                            Text("#\(rep.repIndex) bottom=\(formatTime(rep.bottomTimeVideo))")
                                .font(.subheadline)
                            HStack(spacing: 12) {
                                Text("start: \(rep.startTimeVideo.map(formatTime) ?? "-")")
                                Text("end: \(rep.endTimeVideo.map(formatTime) ?? "-")")
                            }
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                viewModel.deleteRep(at: idx)
                            } label: {
                                Label("削除", systemImage: "trash")
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .frame(minHeight: 120, maxHeight: 240)
            }
        }
        .padding(.horizontal)
    }

    // MARK: - 保存
    @ViewBuilder
    private var saveSection: some View {
        VStack(spacing: 6) {
            if !viewModel.state.canSave {
                VStack(alignment: .leading, spacing: 2) {
                    Text("欠落要素:")
                        .font(.caption.bold())
                        .foregroundStyle(.red)
                    ForEach(viewModel.state.missingRequirements, id: \.self) { req in
                        Text("- \(missingLabel(req))")
                            .font(.caption2)
                            .foregroundStyle(.red)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
            }
            if let err = viewModel.saveError {
                Text(err).font(.caption).foregroundStyle(.red)
            }
            if viewModel.didSave {
                Text("保存しました（labels.json）").font(.caption).foregroundStyle(.green)
            }
            Button {
                viewModel.save()
            } label: {
                Text("SAVE")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(viewModel.state.canSave ? Color.blue : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .disabled(!viewModel.state.canSave)
            .padding(.horizontal)
        }
    }

    private func missingLabel(_ r: LabelingState.MissingRequirement) -> String {
        switch r {
        case .syncVideoStart: return "SYNC START (Video) 未記録"
        case .syncVideoEnd:   return "SYNC END (Video) 未記録"
        case .syncImuStart:   return "SYNC START (IMU) 未記録"
        case .syncImuEnd:     return "SYNC END (IMU) 未記録"
        case .atLeastOneRep:  return "レップが 0 件（BOTTOM を最低1回）"
        case .bottomTimeMissing(let i): return "rep #\(i) の bottom_time 欠落"
        // ISSUE-027: end <= start の場合に表示する順序エラー。
        case .syncVideoOrderInvalid: return "SYNC (Video) 順序不正（END > START でない）"
        case .syncImuOrderInvalid:   return "SYNC (IMU) 順序不正（END > START でない）"
        }
    }

    private func formatTime(_ t: TimeInterval) -> String {
        String(format: "%.3fs", t)
    }
}

