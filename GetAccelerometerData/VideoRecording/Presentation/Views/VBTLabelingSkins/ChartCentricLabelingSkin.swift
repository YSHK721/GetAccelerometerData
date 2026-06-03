import SwiftUI
import AVKit
import Charts
import SensorDataKit

// MARK: - ChartCentricLabelingSkin
// IMU 波形チャートを画面の主役にするスキン。動画は右上に PiP 小窓、
// イベントボタンは横スクロール HStack、セッションヘッダは波形左上にオーバーレイ。
struct ChartCentricLabelingSkin: View {

    @ObservedObject var viewModel: VBTLabelingViewModel

    var body: some View {
        GeometryReader { geo in
            let chartHeight = max(280, geo.size.height * 0.45)
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    chartHero(height: chartHeight)
                    eventButtonsScroller
                    timeAxisDisplay
                    videoScrubBar
                    repsListSection
                    saveSection
                }
                .padding(.vertical, 8)
            }
        }
    }

    // MARK: - Chart hero (with overlay header + PiP video)

    @ViewBuilder
    private func chartHero(height: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            imuChart
                .frame(height: height)
                .background(Color.blue.opacity(0.04))
                .cornerRadius(8)

            sessionHeaderOverlay
                .padding(8)
        }
        .overlay(alignment: .topTrailing) {
            VideoPlayer(player: viewModel.player)
                .frame(width: 140, height: 78)
                .background(Color.black)
                .cornerRadius(6)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.blue, lineWidth: 1))
                .shadow(radius: 4)
                .padding(8)
        }
        .overlay(alignment: .bottomTrailing) {
            HStack(spacing: 8) {
                Button { viewModel.stepBackward() } label: {
                    Image(systemName: "backward.frame.fill")
                }
                Button { viewModel.togglePlayPause() } label: {
                    Image(systemName: "playpause.fill")
                }
                Button { viewModel.stepForward() } label: {
                    Image(systemName: "forward.frame.fill")
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .padding(8)
            .padding(.bottom, 12)
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    private var sessionHeaderOverlay: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(viewModel.folderName)
                .font(.caption2.monospaced())
                .foregroundStyle(.secondary)
                .lineLimit(1).truncationMode(.middle)
            if let meta = viewModel.sessionMeta {
                HStack(spacing: 6) {
                    Text(meta.exercise).font(.caption.bold())
                    Text("\(meta.weightKg, specifier: "%.1f")kg").font(.caption2)
                    Text("set \(meta.setIndex)").font(.caption2)
                    Text("x\(meta.repTarget)").font(.caption2)
                    Text(meta.sessionState.rawValue)
                        .font(.system(size: 9).bold())
                        .padding(.horizontal, 4).padding(.vertical, 1)
                        .background(meta.sessionState == .valid ? Color.green.opacity(0.2) : Color.orange.opacity(0.2))
                        .clipShape(Capsule())
                }
                if let iso = meta.videoStartIso8601 {
                    Text(iso).font(.system(size: 9)).foregroundStyle(.secondary)
                }
            } else {
                Text("meta.json 未読込").font(.caption2).foregroundStyle(.red)
            }
        }
        .padding(6)
        .background(.regularMaterial)
        .cornerRadius(6)
    }

    @ViewBuilder
    private var imuChart: some View {
        if viewModel.samples.isEmpty {
            VStack {
                Spacer()
                Text(viewModel.imuLoadError ?? "IMU 波形なし")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .frame(maxWidth: .infinity)
        } else {
            let base = viewModel.firstSampleTimestamp ?? viewModel.samples.first?.timestamp ?? 0
            let cursorRel = viewModel.imuCursorTime - base
            Chart {
                ForEach(Array(viewModel.samples.enumerated()), id: \.offset) { _, sample in
                    LineMark(x: .value("t (s)", sample.timestamp - base),
                             y: .value("|a|", sample.accelMagnitude))
                        .foregroundStyle(Color.blue)
                }
                RuleMark(x: .value("cursor", cursorRel))
                    .foregroundStyle(.red)
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                if let s = viewModel.state.syncMarkerImuStart {
                    RuleMark(x: .value("SYNC start (IMU)", s - base))
                        .foregroundStyle(.green)
                        .lineStyle(StrokeStyle(lineWidth: 2.0))
                }
                if let e = viewModel.state.syncMarkerImuEnd {
                    RuleMark(x: .value("SYNC end (IMU)", e - base))
                        .foregroundStyle(.orange)
                        .lineStyle(StrokeStyle(lineWidth: 2.0))
                }
            }
            .padding(.top, 60) // overlay header の高さ分の余白
            .gesture(VBTLabelingSkinShared.imuScrubGesture(viewModel: viewModel))
        }
    }

    // MARK: - Event button horizontal scroller

    @ViewBuilder
    private var eventButtonsScroller: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Button("BOTTOM") { viewModel.recordBottom() }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                Button("START") { viewModel.recordStart() }
                    .buttonStyle(.bordered)
                    .disabled(viewModel.state.repsDraft.isEmpty)
                Button("END") { viewModel.recordEnd() }
                    .buttonStyle(.bordered)
                    .disabled(viewModel.state.repsDraft.isEmpty)
                Divider().frame(height: 24)
                Button("SYNC START (Video)") { viewModel.recordSyncStartVideo() }
                    .buttonStyle(.bordered)
                Button("SYNC END (Video)") { viewModel.recordSyncEndVideo() }
                    .buttonStyle(.bordered)
                Divider().frame(height: 24)
                Button("SYNC START (IMU)") { viewModel.recordSyncStartImu() }
                    .buttonStyle(.bordered)
                Button("SYNC END (IMU)") { viewModel.recordSyncEndImu() }
                    .buttonStyle(.bordered)
            }
            .padding(.horizontal)
            .font(.caption)
        }
    }

    @ViewBuilder
    private var timeAxisDisplay: some View {
        HStack(spacing: 16) {
            Text(String(format: "Video %.3f s", viewModel.currentVideoTime))
                .foregroundStyle(Color.blue)
            Text(String(format: "IMU +%.3f s (%.3f)",
                        viewModel.relativeCursorTime, viewModel.imuCursorTime))
                .foregroundStyle(Color.green)
        }
        .font(.caption.monospaced())
        .padding(.horizontal)
    }

    @ViewBuilder
    private var videoScrubBar: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Video scrub").font(.caption2).foregroundStyle(.secondary)
            SharedVideoScrubBar(viewModel: viewModel)
                .frame(height: 24)
        }
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
                        HStack {
                            Text("#\(rep.repIndex)").font(.subheadline.bold())
                            Text(String(format: "b=%.3f", rep.bottomTimeVideo)).font(.caption)
                            Text("s=\(rep.startTimeVideo.map { String(format: "%.3f", $0) } ?? "-")").font(.caption)
                            Text("e=\(rep.endTimeVideo.map { String(format: "%.3f", $0) } ?? "-")").font(.caption)
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            Button(role: .destructive) { viewModel.deleteRep(at: idx) } label: {
                                Label("削除", systemImage: "trash")
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .frame(minHeight: 120, maxHeight: 200)
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
                HStack {
                    Image(systemName: "square.and.arrow.down.fill")
                    Text("SAVE").font(.headline)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)
            .controlSize(.large)
            .disabled(!viewModel.state.canSave)
            .padding(.horizontal)
        }
    }
}
