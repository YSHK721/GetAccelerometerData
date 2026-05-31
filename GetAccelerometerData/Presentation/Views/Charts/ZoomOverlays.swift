import SwiftUI

// MARK: - ヘルプメッセージ表示用コンポーネント

// MARK: ZoomHelpOverlay
// ヘルプメッセージ表示用のコンポーネント
struct ZoomHelpOverlay: View {
  @Environment(\.colorScheme) private var colorScheme
  @State private var isVisible = true

  var body: some View {
    VStack {
      if isVisible {
        HStack(spacing: 20) {
          VStack(alignment: .center) {
            Image(systemName: "hand.draw")
              .font(.title3)
            Text("ピンチでズーム")
              .font(.caption)
          }

          VStack(alignment: .center) {
            Image(systemName: "arrow.left.and.right")
              .font(.title3)
            Text("スワイプで移動")
              .font(.caption)
          }

          VStack(alignment: .center) {
            Image(systemName: "hand.tap")
              .font(.title3)
            Text("タップで選択")
              .font(.caption)
          }

          Button(action: {
            withAnimation {
              isVisible = false
            }
          }) {
            Image(systemName: "xmark.circle.fill")
              .foregroundColor(.secondary)
          }
        }
        .padding(10)
        .background(
          RoundedRectangle(cornerRadius: 8)
            .fill(colorScheme == .dark ? Color.gray.opacity(0.3) : Color.white)
            .shadow(color: Color.black.opacity(0.1), radius: 5)
        )
        .transition(.opacity)
        .onAppear {
          // 5秒後に自動非表示
          DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            withAnimation {
              isVisible = false
            }
          }
        }
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
    .padding(.bottom, 20)
  }
}

// MARK: - グラフのズーム状態を表示するコンポーネント

// MARK: ZoomStatusOverlay
// グラフのズーム状態を表示するコンポーネント
struct ZoomStatusOverlay: View {
  let scale: CGFloat

  var body: some View {
    if scale > 1.0 {
      HStack {
        Image(systemName: "magnifyingglass")
          .font(.caption)
        Text("\(Int(scale * 100))%")
          .font(.caption)
          .fontWeight(.bold)
      }
      .padding(6)
      .background(
        Capsule()
          .fill(Color.accentColor.opacity(0.2))
      )
      .foregroundColor(.accentColor)
    }
  }
}

