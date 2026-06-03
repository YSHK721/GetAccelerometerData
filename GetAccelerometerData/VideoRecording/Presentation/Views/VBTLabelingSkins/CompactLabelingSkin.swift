import SwiftUI
import AVKit
import Charts
import SensorDataKit

// MARK: - CompactLabelingSkin
// 1 画面密集型スキン。動画 160pt / 波形 100pt、イベントボタン 7 件は LazyVGrid、
// レップ一覧は 100pt のミニ List、SAVE は safeAreaInset で底に固定。
struct CompactLabelingSkin: View {

    @ObservedObject var viewModel: VBTLabelingViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 4) {
                sessionHeader

                VideoPlayer(player: viewModel.player)
                    .frame(height: 160)
                    .background(Color.black)

                HStack(spacing: 8) {
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
                .controlSize(.small)
                .padding(.horizontal, 8)

                videoScrubBar

                imuWaveformView

                timeAxisDisplay

                eventGrid

                repsMini
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .font(.caption2)
        }
        .safeAreaInset(edge: .bottom) {
            saveBar
        }
    }

    // MARK: - Sub views

    @ViewBuilder
    private var sessionHeader: some View {
        HStack(alignment: .top, spacing: 4) {
            Text(viewModel.folderName)
                .font(.caption2.monospaced())
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
            if let meta = viewModel.sessionMeta {
                Text("\(meta.exercise) / \(meta.weightKg, specifier: "%.1f")kg / set\(meta.setIndex) / x\(meta.repTarget)")
                    .font(.caption2.weight(.semibold))
                Text(meta.sessionState.rawValue)
                    .font(.system(size: 9))
                    .padding(.horizontal, 4).padding(.vertical, 1)
                    .background(meta.sessionState == .valid ? Color.green.opacity(0.25) : Color.orange.opacity(0.25))
                    .clipShape(Capsule())
            } else {
                Text("meta 未読込").font(.caption2).foregroundStyle(.red)
            }
        }
        if let meta = viewModel.sessionMeta, let iso = meta.videoStartIso8601 {
            Text("rec開始: \(iso)").font(.system(size: 9)).foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var videoScrubBar: some View {
        GeometryReader { geo in
            let progress = VBTLabelingSkinShared.videoProgress(
                currentTime: viewModel.currentVideoTime,
                duration: viewModel.videoDuration
            )
            ZStack(alignment: .leading) {
                Capsule().fill(Color.gray.opacity(0.3)).frame(height: 4)
                Capsule().fill(Color.blue).frame(width: geo.size.width * progress, height: 4)
                if viewModel.videoDuration > 0 {
                    if let s = viewModel.state.syncMarkerVideoStart {
                        let x = geo.size.width * min(1.0, max(0.0, s / viewModel.videoDuration))
                        Rectangle().fill(Color.green).frame(width: 2, height: 12).offset(x: x - 1)
                    }
                    if let e = viewModel.state.syncMarkerVideoEnd {
                        let x = geo.size.width * min(1.0, max(0.0, e / viewModel.videoDuration))
                        Rectangle().fill(Color.orange).frame(width: 2, height: 12).offset(x: x - 1)
                    }
                }
                Circle().fill(Color.blue).frame(width: 10, height: 10)
                    .offset(x: geo.size.width * progress - 5)
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
        .frame(height: 16)
    }

    @ViewBuilder
    private var imuWaveformView: some View {
        if viewModel.samples.isEmpty {
            Text(viewModel.imuLoadError ?? "IMU 波形なし")
                .font(.caption2).foregroundStyle(.secondary)
                .frame(height: 80)
        } else {
            let base = viewModel.firstSampleTimestamp ?? viewModel.samples.first?.timestamp ?? 0
            let cursorRel = viewModel.imuCursorTime - base
            Chart {
                ForEach(Array(viewModel.samples.enumerated()), id: \.offset) { _, sample in
                    LineMark(x: .value("t", sample.timestamp - base),
                             y: .value("|a|", sample.accelMagnitude))
                }
                RuleMark(x: .value("cursor", cursorRel))
                    .foregroundStyle(.red)
                    .lineStyle(StrokeStyle(lineWidth: 1.0, dash: [3, 3]))
                if let s = viewModel.state.syncMarkerImuStart {
                    RuleMark(x: .value("S", s - base)).foregroundStyle(.green)
                }
                if let e = viewModel.state.syncMarkerImuEnd {
                    RuleMark(x: .value("E", e - base)).foregroundStyle(.orange)
                }
            }
            .frame(height: 100)
            .gesture(VBTLabelingSkinShared.imuScrubGesture(viewModel: viewModel))
        }
    }

    @ViewBuilder
    private var timeAxisDisplay: some View {
        HStack(spacing: 8) {
            Text(String(format: "v %.3fs", viewModel.currentVideoTime))
            Text(String(format: "imu+%.3fs", viewModel.relativeCursorTime))
        }
        .font(.system(size: 10).monospaced())
        .foregroundStyle(.secondary)
    }

    @ViewBuilder
    private var eventGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 4) {
            Button("BOTTOM") { viewModel.recordBottom() }
                .buttonStyle(.borderedProminent)
            Button("START") { viewModel.recordStart() }
                .buttonStyle(.bordered)
                .disabled(viewModel.state.repsDraft.isEmpty)
            Button("END") { viewModel.recordEnd() }
                .buttonStyle(.bordered)
                .disabled(viewModel.state.repsDraft.isEmpty)
            Button("SYNC S(V)") { viewModel.recordSyncStartVideo() }.buttonStyle(.bordered)
            Button("SYNC E(V)") { viewModel.recordSyncEndVideo() }.buttonStyle(.bordered)
            Button("SYNC S(I)") { viewModel.recordSyncStartImu() }.buttonStyle(.bordered)
            Button("SYNC E(I)") { viewModel.recordSyncEndImu() }.buttonStyle(.bordered)
        }
        .controlSize(.small)
        .font(.caption2)
    }

    @ViewBuilder
    private var repsMini: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Reps（\(viewModel.state.repsDraft.count)）").font(.caption.bold())
            if viewModel.state.repsDraft.isEmpty {
                Text("未登録").font(.caption2).foregroundStyle(.secondary)
            } else {
                List {
                    ForEach(Array(viewModel.state.repsDraft.enumerated()), id: \.element.repIndex) { idx, rep in
                        HStack {
                            Text("#\(rep.repIndex)").font(.caption2.bold())
                            Text(String(format: "b=%.2f", rep.bottomTimeVideo)).font(.caption2)
                            Text("s=\(rep.startTimeVideo.map { String(format: "%.2f", $0) } ?? "-")").font(.caption2)
                            Text("e=\(rep.endTimeVideo.map { String(format: "%.2f", $0) } ?? "-")").font(.caption2)
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            Button(role: .destructive) { viewModel.deleteRep(at: idx) } label: {
                                Label("削除", systemImage: "trash")
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .frame(maxHeight: 100)
            }
        }
    }

    @ViewBuilder
    private var saveBar: some View {
        VStack(spacing: 2) {
            if !viewModel.state.canSave {
                Text("欠落: " + viewModel.state.missingRequirements.map(VBTLabelingSkinShared.shortMissingLabel).joined(separator: " / "))
                    .font(.system(size: 10))
                    .foregroundStyle(.red)
                    .lineLimit(2)
                    .padding(.horizontal, 8)
            }
            if let err = viewModel.saveError {
                Text(err).font(.caption2).foregroundStyle(.red)
            }
            if viewModel.didSave {
                Text("saved").font(.caption2).foregroundStyle(.green)
            }
            Button { viewModel.save() } label: {
                Text("SAVE").font(.subheadline.bold()).frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .disabled(!viewModel.state.canSave)
            .padding(.horizontal, 8)
            .padding(.bottom, 4)
        }
        .background(.thinMaterial)
    }

}
