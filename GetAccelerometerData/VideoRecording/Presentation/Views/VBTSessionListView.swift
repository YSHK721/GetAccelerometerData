import SwiftUI
import SensorDataKit

// MARK: - VBTSessionListView
// VBT Ground Truth Tool Phase C: セッション一覧画面（仕様書 §10）。
//   VALID 状態のみ表示、タップで LabelingView へ遷移。
struct VBTSessionListView: View {

    @StateObject private var viewModel: VBTSessionListViewModel

    init() {
        let composition = VBTGroundTruthMetaInputViewModel.shared
        _viewModel = StateObject(wrappedValue: VBTSessionListViewModel(useCase: composition.loadSessionListUseCase))
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
                        }
                    }
                }
            }
        }
        .navigationTitle("VBT ラベリング")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { viewModel.reload() }
        .refreshable { viewModel.reload() }
    }

    private func formatWeight(_ w: Double) -> String {
        if w == w.rounded() { return String(Int(w)) }
        return String(w)
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
