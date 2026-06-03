import SwiftUI
import AVKit
import Charts
import SensorDataKit

// MARK: - ClassicLabelingSkin
// 現行 VBTLabelingView の標準階層を踏襲したスキン。配色・フォント・ボタン構成は
// システムデフォルト。3 段イベントボタン + .borderedProminent SAVE。
struct ClassicLabelingSkin: View {

    @ObservedObject var viewModel: VBTLabelingViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                sessionHeader

                VideoPlayer(player: viewModel.player)
                    .frame(height: 240)
                    .background(Color.black)

                HStack(spacing: 16) {
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
                .padding(.horizontal)

                videoScrubBar

                imuWaveformView

                timeAxisDisplay

                eventButtonsSection

                repsListSection

                saveSection
            }
            .padding(.vertical, 8)
        }
    }

    // MARK: - Sub views

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
                    Text(meta.exercise).font(.subheadline.weight(.semibold))
                    Text("\(meta.weightKg, specifier: "%.1f") kg").font(.caption)
                    Text("set \(meta.setIndex)").font(.caption)
                    Text("rep目標 \(meta.repTarget)").font(.caption)
                    Spacer()
                    Text(meta.sessionState.rawValue)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
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
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
        .padding(.top, 4)
    }

    @ViewBuilder
    private var videoScrubBar: some View {
        GeometryReader { geo in
            let progress = VBTLabelingSkinShared.videoProgress(
                currentTime: viewModel.currentVideoTime,
                duration: viewModel.videoDuration
            )
            ZStack(alignment: .leading) {
                Capsule().fill(Color.gray.opacity(0.3)).frame(height: 6)
                Capsule().fill(Color.blue).frame(width: geo.size.width * progress, height: 6)
                if viewModel.videoDuration > 0 {
                    if let s = viewModel.state.syncMarkerVideoStart {
                        let x = geo.size.width * min(1.0, max(0.0, s / viewModel.videoDuration))
                        Rectangle().fill(Color.green).frame(width: 2, height: 18).offset(x: x - 1)
                    }
                    if let e = viewModel.state.syncMarkerVideoEnd {
                        let x = geo.size.width * min(1.0, max(0.0, e / viewModel.videoDuration))
                        Rectangle().fill(Color.orange).frame(width: 2, height: 18).offset(x: x - 1)
                    }
                }
                Circle().fill(Color.blue).frame(width: 14, height: 14)
                    .offset(x: geo.size.width * progress - 7)
            }
            .contentShape(Rectangle())
            .gesture(
                LongPressGesture(minimumDuration: 0.5)
                    .sequenced(before: DragGesture(minimumDistance: 0))
                    .onChanged { value in
                        if case .second(true, let drag?) = value {
                            viewModel.isScrubbing = true
                            let ratio = min(1.0, max(0.0, drag.location.x / geo.size.width))
                            viewModel.seek(to: ratio * viewModel.videoDuration)
                        }
                    }
                    .onEnded { _ in viewModel.isScrubbing = false }
            )
        }
        .frame(height: 24)
        .padding(.horizontal)
    }

    @ViewBuilder
    private var imuWaveformView: some View {
        if viewModel.samples.isEmpty {
            VStack(spacing: 4) {
                Text("IMU 波形なし").font(.caption).foregroundStyle(.secondary)
                if let reason = viewModel.imuLoadError {
                    Text(reason).font(.caption2).foregroundStyle(.red)
                        .multilineTextAlignment(.center).padding(.horizontal)
                }
            }
            .frame(height: 120)
        } else {
            let base = viewModel.firstSampleTimestamp ?? viewModel.samples.first?.timestamp ?? 0
            let cursorRel = viewModel.imuCursorTime - base
            Chart {
                ForEach(Array(viewModel.samples.enumerated()), id: \.offset) { _, sample in
                    LineMark(x: .value("t (s)", sample.timestamp - base),
                             y: .value("|a|", sample.accelMagnitude))
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
            .frame(height: 140)
            .padding(.horizontal)
            .gesture(VBTLabelingSkinShared.imuScrubGesture(viewModel: viewModel))
        }
    }

    @ViewBuilder
    private var timeAxisDisplay: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(String(format: "動画ローカル: %.3f s", viewModel.currentVideoTime))
            Text(String(format: "IMU 統一軸: %.3f s（録画開始+%.3f s）",
                        viewModel.imuCursorTime, viewModel.relativeCursorTime))
        }
        .font(.caption.monospaced())
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
    }

    @ViewBuilder
    private var eventButtonsSection: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Button("BOTTOM") { viewModel.recordBottom() }
                    .buttonStyle(.borderedProminent).frame(maxWidth: .infinity)
                Button("START") { viewModel.recordStart() }
                    .buttonStyle(.bordered).frame(maxWidth: .infinity)
                    .disabled(viewModel.state.repsDraft.isEmpty)
                Button("END") { viewModel.recordEnd() }
                    .buttonStyle(.bordered).frame(maxWidth: .infinity)
                    .disabled(viewModel.state.repsDraft.isEmpty)
            }
            HStack(spacing: 8) {
                Button("SYNC START (Video)") { viewModel.recordSyncStartVideo() }
                    .buttonStyle(.bordered).frame(maxWidth: .infinity)
                Button("SYNC END (Video)") { viewModel.recordSyncEndVideo() }
                    .buttonStyle(.bordered).frame(maxWidth: .infinity)
            }
            HStack(spacing: 8) {
                Button("SYNC START (IMU)") { viewModel.recordSyncStartImu() }
                    .buttonStyle(.bordered).frame(maxWidth: .infinity)
                Button("SYNC END (IMU)") { viewModel.recordSyncEndImu() }
                    .buttonStyle(.bordered).frame(maxWidth: .infinity)
            }
        }
        .font(.caption)
        .padding(.horizontal)
    }

    @ViewBuilder
    private var repsListSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Reps（\(viewModel.state.repsDraft.count)）").font(.headline)
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
                            .font(.caption2).foregroundStyle(.secondary)
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            Button(role: .destructive) { viewModel.deleteRep(at: idx) } label: {
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

    @ViewBuilder
    private var saveSection: some View {
        VStack(spacing: 6) {
            if !viewModel.state.canSave {
                VStack(alignment: .leading, spacing: 2) {
                    Text("欠落要素:").font(.caption.bold()).foregroundStyle(.red)
                    ForEach(viewModel.state.missingRequirements, id: \.self) { req in
                        Text("- \(VBTLabelingSkinShared.missingLabel(req))").font(.caption2).foregroundStyle(.red)
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
            Button { viewModel.save() } label: {
                Text("SAVE").font(.headline).frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)
            .controlSize(.large)
            .disabled(!viewModel.state.canSave)
            .padding(.horizontal)
        }
    }
}
