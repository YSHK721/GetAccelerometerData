import SwiftUI
import SensorDataKit

// MARK: - VBTSessionListView
// VBT Ground Truth Tool Phase C/D: セッション一覧画面（仕様書 §10 / §8）。
//   - Phase C: VALID 状態のみ表示、タップで LabelingView へ遷移
//   - Phase D: 各セッション行にエクスポート（共有シート）ボタンを追加
//              labels.json 未生成の VALID セッションはボタンを disabled 化
struct VBTSessionListView: View {

    @StateObject private var viewModel: VBTSessionListViewModel

    // Phase D: 共有シート提示用の状態（行単位ではなく List 全体で 1 つ）
    @State private var sharingFolderURL: URL?

    init() {
        let composition = VBTGroundTruthMetaInputViewModel.shared
        _viewModel = StateObject(wrappedValue: VBTSessionListViewModel(
            useCase: composition.loadSessionListUseCase,
            labelsChecker: composition.labelsExistenceChecker,
            exportUseCase: composition.exportSessionUseCase
        ))
    }

    var body: some View {
        List {
            if let err = viewModel.errorMessage {
                Section {
                    Text(err)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            if viewModel.rows.isEmpty {
                Section {
                    Text("VALID 状態の記録セッションがありません")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else {
                ForEach(viewModel.rows) { row in
                    sessionRow(row)
                }
            }
        }
        .navigationTitle("VBT ラベリング")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { viewModel.reload() }
        .refreshable { viewModel.reload() }
        // Phase D: 共有シート提示
        .sheet(item: ShareItem.binding($sharingFolderURL)) { item in
            VBTShareSheetView(activityItems: [item.url]) { _, _ in
                sharingFolderURL = nil
            }
        }
    }

    // MARK: - Row
    @ViewBuilder
    private func sessionRow(_ row: VBTSessionListViewModel.Row) -> some View {
        HStack(spacing: 8) {
            NavigationLink(destination: VBTLabelingView(
                sessionId: row.entry.folderName,
                folderURL: row.folderURL
            )) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(row.entry.folderName)
                        .font(.headline)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    HStack(spacing: 12) {
                        Text("種目: \(row.entry.exercise)")
                        Text("重量: \(formatWeight(row.entry.weightKg))kg")
                        Text("Set: \(row.entry.setIndex)")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    if !row.isExportable {
                        Text("共有不可: ラベリング未完了")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                }
            }

            // Phase D: 共有ボタン
            Button {
                shareSession(row)
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .font(.title3)
                    .padding(.horizontal, 4)
            }
            .buttonStyle(.borderless)
            .disabled(!row.isExportable)
            .foregroundStyle(row.isExportable ? Color.blue : Color.gray)
            .accessibilityLabel(row.isExportable ? "共有" : "共有不可（ラベリング未完了）")
        }
    }

    private func shareSession(_ row: VBTSessionListViewModel.Row) {
        guard let url = viewModel.resolveExportURL(sessionId: row.entry.folderName) else { return }
        sharingFolderURL = url
    }

    private func formatWeight(_ w: Double) -> String {
        if w == w.rounded() { return String(Int(w)) }
        return String(w)
    }
}

// MARK: - ShareItem
// URL を Identifiable にラップして `.sheet(item:)` に渡すための Adapter。
private struct ShareItem: Identifiable {
    let id: String
    let url: URL

    static func binding(_ source: Binding<URL?>) -> Binding<ShareItem?> {
        Binding(
            get: { source.wrappedValue.map { ShareItem(id: $0.path, url: $0) } },
            set: { newValue in source.wrappedValue = newValue?.url }
        )
    }
}

// MARK: - VBTSessionListEntryLink（ContentView から呼ぶ）

struct VBTSessionListEntryLink: View {
    var body: some View {
        NavigationLink(destination: VBTSessionListView()) {
            Label("VBT ラベリング", systemImage: "list.bullet.rectangle")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.purple)
                .foregroundColor(.white)
                .cornerRadius(10)
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.horizontal)
    }
}
