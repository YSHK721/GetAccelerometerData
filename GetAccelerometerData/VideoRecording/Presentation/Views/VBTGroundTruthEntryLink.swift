import SwiftUI

// MARK: - VBTGroundTruthEntryLink
// 既存 ContentView は変更せず、本 View をネスト挿入する代わりに、
// ContentView 上に NavigationLink を 1 行追加する形を最小変更とする。
//
// 仕様書: .docs/VBT_GroundTruth_Tool_Spec.md Phase B / メタ入力画面の追加
//
// 補助: 同モジュール内で再利用するためのリンクラッパ。
struct VBTGroundTruthEntryLink: View {
    var body: some View {
        NavigationLink(destination: VBTGroundTruthMetaInputView()) {
            Label("VBT 記録セッション", systemImage: "video.badge.checkmark")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.indigo)
                .foregroundColor(.white)
                .cornerRadius(10)
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.horizontal)
    }
}
