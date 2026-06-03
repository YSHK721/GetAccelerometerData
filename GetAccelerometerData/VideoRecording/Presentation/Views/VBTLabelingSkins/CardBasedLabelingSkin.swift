import SwiftUI
import AVKit
import Charts
import SensorDataKit

// MARK: - CardBasedLabelingSkin
// 各セクションを独立した色付きカードで表現するスキン。
// 動画=青 / 波形=緑 / SYNC=橙 / イベント=紫 / レップ=ティール / SAVE=赤。
struct CardBasedLabelingSkin: View {

    @ObservedObject var viewModel: VBTLabelingViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                sessionCard
                videoCard
                waveformCard
                syncCard
                eventCard
                repsCard
                saveCard
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 12)
        }
    }

    // MARK: - Card chrome

    @ViewBuilder
    private func card<Content: View>(
        title: String,
        icon: String,
        color: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: icon).foregroundStyle(color)
                Text(title).font(.subheadline.bold()).foregroundStyle(color)
            }
            content()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(color.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(color.opacity(0.25), lineWidth: 1)
        )
        .shadow(radius: 2)
    }

    // MARK: - Cards

    @ViewBuilder
    private var sessionCard: some View {
        card(title: "セッション", icon: "doc.text", color: .gray) {
            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.folderName)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(2).truncationMode(.middle)
                if let meta = viewModel.sessionMeta {
                    HStack(spacing: 8) {
                        Text(meta.exercise).font(.subheadline.weight(.semibold))
                        Text("\(meta.weightKg, specifier: "%.1f") kg").font(.caption)
                        Text("set \(meta.setIndex)").font(.caption)
                        Text("x\(meta.repTarget)").font(.caption)
                        Spacer()
                        Text(meta.sessionState.rawValue)
                            .font(.caption2)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(meta.sessionState == .valid ? Color.green.opacity(0.2) : Color.orange.opacity(0.2))
                            .clipShape(Capsule())
                    }
                    if let iso = meta.videoStartIso8601 {
                        Text("録画開始: \(iso)").font(.caption2).foregroundStyle(.secondary)
                    }
                } else {
                    Text("meta.json 未読込").font(.caption2).foregroundStyle(.red)
                }
            }
        }
    }

    @ViewBuilder
    private var videoCard: some View {
        card(title: "動画", icon: "play.rectangle.fill", color: .blue) {
            VStack(spacing: 8) {
                VideoPlayer(player: viewModel.player)
                    .frame(height: 220)
                    .background(Color.black)
                    .cornerRadius(10)

                HStack(spacing: 12) {
                    Button { viewModel.stepBackward() } label: {
                        Image(systemName: "backward.frame.fill").frame(maxWidth: .infinity)
                    }
                    Button { viewModel.togglePlayPause() } label: {
                        Image(systemName: "playpause.fill").frame(maxWidth: .infinity)
                    }
                    Button { viewModel.stepForward() } label: {
                        Image(systemName: "forward.frame.fill").frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.bordered)
                .tint(.blue)

                videoScrubBar

                Text(String(format: "動画ローカル: %.3f s", viewModel.currentVideoTime))
                    .font(.caption.monospaced())
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    @ViewBuilder
    private var videoScrubBar: some View {
        SharedVideoScrubBar(viewModel: viewModel)
            .frame(height: 24)
    }

    @ViewBuilder
    private var waveformCard: some View {
        card(title: "IMU 波形", icon: "waveform.path.ecg", color: .green) {
            VStack(alignment: .leading, spacing: 6) {
                if viewModel.samples.isEmpty {
                    VStack(spacing: 4) {
                        Text("IMU 波形なし").font(.caption).foregroundStyle(.secondary)
                        if let reason = viewModel.imuLoadError {
                            Text(reason).font(.caption2).foregroundStyle(.red)
                        }
                    }
                    .frame(height: 120)
                    .frame(maxWidth: .infinity)
                } else {
                    let base = viewModel.firstSampleTimestamp ?? viewModel.samples.first?.timestamp ?? 0
                    let cursorRel = viewModel.imuCursorTime - base
                    Chart {
                        ForEach(Array(viewModel.samples.enumerated()), id: \.offset) { _, sample in
                            LineMark(x: .value("t (s)", sample.timestamp - base),
                                     y: .value("|a|", sample.accelMagnitude))
                                .foregroundStyle(Color.green)
                        }
                        RuleMark(x: .value("cursor", cursorRel))
                            .foregroundStyle(.red)
                            .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                        if let s = viewModel.state.syncMarkerImuStart {
                            RuleMark(x: .value("SYNC start (IMU)", s - base))
                                .foregroundStyle(.green)
                                .lineStyle(StrokeStyle(lineWidth: 1.5))
                        }
                        if let e = viewModel.state.syncMarkerImuEnd {
                            RuleMark(x: .value("SYNC end (IMU)", e - base))
                                .foregroundStyle(.orange)
                                .lineStyle(StrokeStyle(lineWidth: 1.5))
                        }
                    }
                    .frame(height: 160)
                    .gesture(VBTLabelingSkinShared.imuScrubGesture(viewModel: viewModel))
                }
                Text(String(format: "IMU 統一軸: %.3f s（+%.3f s）",
                            viewModel.imuCursorTime, viewModel.relativeCursorTime))
                    .font(.caption.monospaced())
            }
        }
    }

    @ViewBuilder
    private var syncCard: some View {
        card(title: "SYNC マーカー", icon: "arrow.triangle.2.circlepath", color: .orange) {
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    Button("SYNC START (Video)") { viewModel.recordSyncStartVideo() }
                        .buttonStyle(.bordered).tint(.orange).frame(maxWidth: .infinity)
                    Button("SYNC END (Video)") { viewModel.recordSyncEndVideo() }
                        .buttonStyle(.bordered).tint(.orange).frame(maxWidth: .infinity)
                }
                HStack(spacing: 8) {
                    Button("SYNC START (IMU)") { viewModel.recordSyncStartImu() }
                        .buttonStyle(.bordered).tint(.orange).frame(maxWidth: .infinity)
                    Button("SYNC END (IMU)") { viewModel.recordSyncEndImu() }
                        .buttonStyle(.bordered).tint(.orange).frame(maxWidth: .infinity)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Video: S=\(viewModel.state.syncMarkerVideoStart.map { String(format: "%.3fs", $0) } ?? "-") / E=\(viewModel.state.syncMarkerVideoEnd.map { String(format: "%.3fs", $0) } ?? "-")")
                    Text("IMU  : S=\(viewModel.state.syncMarkerImuStart.map { String(format: "%.3fs", $0) } ?? "-") / E=\(viewModel.state.syncMarkerImuEnd.map { String(format: "%.3fs", $0) } ?? "-")")
                }
                .font(.caption.monospaced())
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .font(.caption)
        }
    }

    @ViewBuilder
    private var eventCard: some View {
        card(title: "イベント", icon: "bolt.fill", color: .purple) {
            HStack(spacing: 8) {
                Button("BOTTOM") { viewModel.recordBottom() }
                    .buttonStyle(.borderedProminent).tint(.purple)
                    .frame(maxWidth: .infinity)
                Button("START") { viewModel.recordStart() }
                    .buttonStyle(.bordered).tint(.purple)
                    .frame(maxWidth: .infinity)
                    .disabled(viewModel.state.repsDraft.isEmpty)
                Button("END") { viewModel.recordEnd() }
                    .buttonStyle(.bordered).tint(.purple)
                    .frame(maxWidth: .infinity)
                    .disabled(viewModel.state.repsDraft.isEmpty)
            }
            .font(.caption)
        }
    }

    @ViewBuilder
    private var repsCard: some View {
        card(title: "レップ一覧（\(viewModel.state.repsDraft.count)）",
             icon: "list.bullet",
             color: .teal) {
            if viewModel.state.repsDraft.isEmpty {
                Text("レップ未登録").font(.caption).foregroundStyle(.secondary)
            } else {
                List {
                    ForEach(Array(viewModel.state.repsDraft.enumerated()), id: \.element.repIndex) { idx, rep in
                        VStack(alignment: .leading, spacing: 2) {
                            Text("#\(rep.repIndex) bottom=\(String(format: "%.3fs", rep.bottomTimeVideo))")
                                .font(.subheadline)
                            HStack(spacing: 12) {
                                Text("start: \(rep.startTimeVideo.map { String(format: "%.3fs", $0) } ?? "-")")
                                Text("end: \(rep.endTimeVideo.map { String(format: "%.3fs", $0) } ?? "-")")
                            }
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        }
                        .listRowBackground(Color.teal.opacity(0.04))
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            Button(role: .destructive) { viewModel.deleteRep(at: idx) } label: {
                                Label("削除", systemImage: "trash")
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 120, maxHeight: 240)
            }
        }
    }

    @ViewBuilder
    private var saveCard: some View {
        card(title: "保存", icon: "square.and.arrow.down.fill", color: .red) {
            VStack(spacing: 6) {
                if !viewModel.state.canSave {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("欠落要素:").font(.caption.bold()).foregroundStyle(.red)
                        ForEach(viewModel.state.missingRequirements, id: \.self) { req in
                            Text("- \(VBTLabelingSkinShared.missingLabel(req))").font(.caption2).foregroundStyle(.red)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                if let err = viewModel.saveError {
                    Text(err).font(.caption).foregroundStyle(.red)
                }
                if viewModel.didSave {
                    Text("保存しました（labels.json）").font(.caption).foregroundStyle(.green)
                }
                Button { viewModel.save() } label: {
                    Text("SAVE").font(.headline).frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .controlSize(.large)
                .disabled(!viewModel.state.canSave)
            }
        }
    }
}
