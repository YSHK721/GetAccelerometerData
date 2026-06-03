import SwiftUI
import SensorDataKit

// MARK: - VBTLabelingSkinnedView
// VBT Labeling 画面の「スキン切り替え可能版」エントリポイント。
//
// 設計方針:
//   - 既存 VBTLabelingView.swift / VBTLabelingViewModel.swift は完全無変更で利用する
//   - 本ビューが ViewModel を所有し、選択された各スキンへ @ObservedObject で共有する
//   - スキン間の遷移ではセッション状態（State / samples / cursor 等）が継続する
struct VBTLabelingSkinnedView: View {

    @StateObject private var viewModel: VBTLabelingViewModel
    @AppStorage("vbt.labeling.selectedSkin") private var selectedSkinRaw: String = LabelingSkinKind.classic.rawValue

    private var selectedSkin: Binding<LabelingSkinKind> {
        Binding(
            get: { LabelingSkinKind(rawValue: selectedSkinRaw) ?? .classic },
            set: { selectedSkinRaw = $0.rawValue }
        )
    }

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
        VStack(spacing: 0) {
            Picker("Design", selection: selectedSkin) {
                ForEach(LabelingSkinKind.allCases) { kind in
                    Text(kind.displayName).tag(kind)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)

            switch selectedSkin.wrappedValue {
            case .classic:
                ClassicLabelingSkin(viewModel: viewModel)
            case .compact:
                CompactLabelingSkin(viewModel: viewModel)
            case .darkPro:
                DarkProLabelingSkin(viewModel: viewModel)
            case .chartCentric:
                ChartCentricLabelingSkin(viewModel: viewModel)
            case .cardBased:
                CardBasedLabelingSkin(viewModel: viewModel)
            }
        }
        .navigationTitle("ラベリング [Skin]")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { viewModel.load() }
    }
}
