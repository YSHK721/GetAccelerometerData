import SwiftUI
import AVKit
import Charts
import SensorDataKit

// MARK: - DarkProLabelingSkin
// ダークテーマ強制 + アクセントカラー（緑/赤/シアン/橙）多用。
// ボタンは large + カラーパッド + cornerRadius(12)。波形ラインは緑、SYNC は太線。
struct DarkProLabelingSkin: View {

    @ObservedObject var viewModel: VBTLabelingViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                sessionHeader

                VideoPlayer(player: viewModel.player)
                    .frame(height: 240)
                    .background(Color.black)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.cyan.opacity(0.4), lineWidth: 1)
                    )
                    .padding(.horizontal)

                stepperBar

                Divider().background(Color.cyan.opacity(0.3))

                videoScrubBar

                imuWaveformView

                Divider().background(Color.cyan.opacity(0.3))

                timeAxisDisplay

                eventButtonsSection

                Divider().background(Color.cyan.opacity(0.3))

                repsListSection

                Divider().background(Color.cyan.opacity(0.3))

                saveSection
            }
            .padding(.vertical, 10)
        }
        .background(Color.black.ignoresSafeArea())
        .preferredColorScheme(.dark)
    }

    // MARK: - Sub views

    @ViewBuilder
    private var sessionHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(viewModel.folderName)
                .font(.caption.monospaced())
                .foregroundStyle(Color.cyan)
                .lineLimit(1).truncationMode(.middle)
            if let meta = viewModel.sessionMeta {
                HStack(spacing: 10) {
                    Text(meta.exercise)
                        .font(.headline)
                        .foregroundStyle(Color.white)
                    Text("\(meta.weightKg, specifier: "%.1f") kg")
                        .foregroundStyle(Color.cyan)
                    Text("set \(meta.setIndex)")
                        .foregroundStyle(Color.cyan)
                    Text("x\(meta.repTarget)")
                        .foregroundStyle(Color.cyan)
                    Spacer()
                    Text(meta.sessionState.rawValue)
                        .font(.caption2.bold())
                        .foregroundStyle(meta.sessionState == .valid ? Color.green : Color.red)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(
                            (meta.sessionState == .valid ? Color.green : Color.red).opacity(0.18)
                        )
                        .clipShape(Capsule())
                }
                .font(.caption)
                if let iso = meta.videoStartIso8601 {
                    Text("rec: \(iso)").font(.caption2).foregroundStyle(.gray)
                }
            } else {
                Text("meta.json 未読込").font(.caption).foregroundStyle(Color.red)
            }
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    private var stepperBar: some View {
        HStack(spacing: 12) {
            darkIconButton("backward.frame.fill") { viewModel.stepBackward() }
            darkIconButton("playpause.fill") { viewModel.togglePlayPause() }
            darkIconButton("forward.frame.fill") { viewModel.stepForward() }
        }
        .padding(.horizontal)
    }

    private func darkIconButton(_ system: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.title3)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.cyan.opacity(0.18))
                .foregroundStyle(Color.cyan)
                .cornerRadius(12)
        }
    }

    @ViewBuilder
    private var videoScrubBar: some View {
        GeometryReader { geo in
            let progress: Double = viewModel.videoDuration > 0
                ? min(1.0, max(0.0, viewModel.currentVideoTime / viewModel.videoDuration)) : 0
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.12)).frame(height: 8)
                Capsule().fill(Color.cyan).frame(width: geo.size.width * progress, height: 8)
                if viewModel.videoDuration > 0 {
                    if let s = viewModel.state.syncMarkerVideoStart {
                        let x = geo.size.width * min(1.0, max(0.0, s / viewModel.videoDuration))
                        Rectangle().fill(Color.green).frame(width: 3, height: 22).offset(x: x - 1)
                    }
                    if let e = viewModel.state.syncMarkerVideoEnd {
                        let x = geo.size.width * min(1.0, max(0.0, e / viewModel.videoDuration))
                        Rectangle().fill(Color.orange).frame(width: 3, height: 22).offset(x: x - 1)
                    }
                }
                Circle().fill(Color.cyan).frame(width: 16, height: 16)
                    .shadow(color: Color.cyan.opacity(0.6), radius: 6)
                    .offset(x: geo.size.width * progress - 8)
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
        .frame(height: 26)
        .padding(.horizontal)
    }

    @ViewBuilder
    private var imuWaveformView: some View {
        if viewModel.samples.isEmpty {
            VStack(spacing: 4) {
                Text("IMU 波形なし").font(.caption).foregroundStyle(Color.gray)
                if let reason = viewModel.imuLoadError {
                    Text(reason).font(.caption2).foregroundStyle(Color.red)
                }
            }
            .frame(height: 120)
            .frame(maxWidth: .infinity)
            .background(Color.white.opacity(0.04))
            .cornerRadius(12)
            .padding(.horizontal)
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
                    .foregroundStyle(Color.red)
                    .lineStyle(StrokeStyle(lineWidth: 2.0, dash: [4, 4]))
                if let s = viewModel.state.syncMarkerImuStart {
                    RuleMark(x: .value("SYNC S", s - base))
                        .foregroundStyle(Color.green)
                        .lineStyle(StrokeStyle(lineWidth: 2.5))
                }
                if let e = viewModel.state.syncMarkerImuEnd {
                    RuleMark(x: .value("SYNC E", e - base))
                        .foregroundStyle(Color.orange)
                        .lineStyle(StrokeStyle(lineWidth: 2.5))
                }
            }
            .frame(height: 160)
            .padding(10)
            .background(Color.white.opacity(0.04))
            .cornerRadius(12)
            .padding(.horizontal)
            .gesture(imuScrubGesture)
        }
    }

    /// IMU 波形スクラブ（既存 VBTLabelingView.swift:197-213 と等価）
    private var imuScrubGesture: some Gesture {
        LongPressGesture(minimumDuration: 0.5)
            .sequenced(before: DragGesture(minimumDistance: 0))
            .onChanged { value in
                if case .second(true, let drag?) = value {
                    if let first = viewModel.samples.first?.timestamp,
                       let last = viewModel.samples.last?.timestamp,
                       last > first {
                        let ratio = max(0.0, min(1.0, drag.location.x / 300.0))
                        viewModel.imuCursorTime = first + ratio * (last - first)
                    }
                }
            }
    }

    @ViewBuilder
    private var timeAxisDisplay: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(String(format: "VIDEO: %.3f s", viewModel.currentVideoTime))
                .foregroundStyle(Color.cyan)
            Text(String(format: "IMU  : %.3f s（+%.3f s）",
                        viewModel.imuCursorTime, viewModel.relativeCursorTime))
                .foregroundStyle(Color.green)
        }
        .font(.caption.monospaced())
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
    }

    @ViewBuilder
    private var eventButtonsSection: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                darkPad("BOTTOM", color: .green) { viewModel.recordBottom() }
                darkPad("START", color: .cyan, disabled: viewModel.state.repsDraft.isEmpty) {
                    viewModel.recordStart()
                }
                darkPad("END", color: .orange, disabled: viewModel.state.repsDraft.isEmpty) {
                    viewModel.recordEnd()
                }
            }
            HStack(spacing: 10) {
                darkPad("SYNC-S (V)", color: .green) { viewModel.recordSyncStartVideo() }
                darkPad("SYNC-E (V)", color: .orange) { viewModel.recordSyncEndVideo() }
            }
            HStack(spacing: 10) {
                darkPad("SYNC-S (I)", color: .green) { viewModel.recordSyncStartImu() }
                darkPad("SYNC-E (I)", color: .orange) { viewModel.recordSyncEndImu() }
            }
        }
        .padding(.horizontal)
    }

    private func darkPad(_ title: String, color: Color, disabled: Bool = false,
                         action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption.bold())
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(color.opacity(disabled ? 0.08 : 0.22))
                .foregroundStyle(disabled ? Color.gray : color)
                .cornerRadius(12)
        }
        .controlSize(.large)
        .disabled(disabled)
    }

    @ViewBuilder
    private var repsListSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("REPS (\(viewModel.state.repsDraft.count))")
                .font(.headline)
                .foregroundStyle(Color.cyan)
            if viewModel.state.repsDraft.isEmpty {
                Text("レップ未登録").font(.caption).foregroundStyle(.gray)
            } else {
                List {
                    ForEach(Array(viewModel.state.repsDraft.enumerated()), id: \.element.repIndex) { idx, rep in
                        VStack(alignment: .leading, spacing: 2) {
                            Text("#\(rep.repIndex) bottom=\(String(format: "%.3fs", rep.bottomTimeVideo))")
                                .font(.subheadline)
                                .foregroundStyle(Color.white)
                            HStack(spacing: 10) {
                                Text("start: \(rep.startTimeVideo.map { String(format: "%.3fs", $0) } ?? "-")")
                                    .foregroundStyle(Color.green.opacity(0.8))
                                Text("end: \(rep.endTimeVideo.map { String(format: "%.3fs", $0) } ?? "-")")
                                    .foregroundStyle(Color.orange.opacity(0.8))
                            }
                            .font(.caption2)
                        }
                        .listRowBackground(Color.white.opacity(0.04))
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
        .padding(.horizontal)
    }

    @ViewBuilder
    private var saveSection: some View {
        VStack(spacing: 6) {
            if !viewModel.state.canSave {
                VStack(alignment: .leading, spacing: 2) {
                    Text("欠落要素:").font(.caption.bold()).foregroundStyle(Color.red)
                    ForEach(viewModel.state.missingRequirements, id: \.self) { req in
                        Text("- \(missingLabel(req))").font(.caption2).foregroundStyle(Color.red)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
            }
            if let err = viewModel.saveError {
                Text(err).font(.caption).foregroundStyle(Color.red)
            }
            if viewModel.didSave {
                Text("保存しました（labels.json）").font(.caption).foregroundStyle(Color.green)
            }
            Button { viewModel.save() } label: {
                Text("SAVE")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(viewModel.state.canSave ? Color.green : Color.gray.opacity(0.3))
                    .foregroundStyle(Color.black)
                    .cornerRadius(12)
            }
            .controlSize(.large)
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
        case .atLeastOneRep:  return "レップが 0 件"
        case .bottomTimeMissing(let i): return "rep #\(i) bottom 欠落"
        case .syncVideoOrderInvalid: return "SYNC (Video) 順序不正"
        case .syncImuOrderInvalid:   return "SYNC (IMU) 順序不正"
        }
    }
}
