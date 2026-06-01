import SwiftUI
import SensorDataKit

// MARK: - VBTGroundTruthMetaInputView
// VBT Ground Truth Tool Phase B: メタ入力 + 録画待機画面。
// 仕様書: .docs/VBT_GroundTruth_Tool_Spec.md §5 入力データ表
//   入力: exercise / weight_kg / rep_target / set_index / subject_id
//   バリデーション: 非空 / > 0 / >= 1 / >= 0 / 非空
//
// 既存 ContentView は変更せず、ContentView から NavigationLink で本ビューへ遷移する。
struct VBTGroundTruthMetaInputView: View {
    @StateObject private var viewModel = VBTGroundTruthMetaInputViewModel()

    var body: some View {
        Form {
            Section("セッションメタ情報") {
                TextField("exercise (例: back_squat)", text: $viewModel.exercise)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)

                HStack {
                    Text("weight_kg")
                    Spacer()
                    TextField("80", value: $viewModel.weightKg, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                }

                HStack {
                    Text("rep_target")
                    Spacer()
                    TextField("10", value: $viewModel.repTarget, format: .number)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                }

                HStack {
                    Text("set_index")
                    Spacer()
                    TextField("1", value: $viewModel.setIndex, format: .number)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                }

                TextField("subject_id (例: ao)", text: $viewModel.subjectId)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
            }

            if let error = viewModel.validationError {
                Section {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Section {
                Button(action: { viewModel.submitPendingMetadata() }) {
                    Text("メタ情報を確定して待機")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!viewModel.canSubmit)
            }

            if viewModel.isWaitingForWatch {
                Section("Watch との連携") {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("Watch で記録開始してください")
                    }
                    .font(.subheadline)
                }
            }

            Section("セッション状態") {
                Text(viewModel.statusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("VBT 記録セッション")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { viewModel.attachRouterIfNeeded() }
    }
}

#Preview {
    NavigationStack {
        VBTGroundTruthMetaInputView()
    }
}
