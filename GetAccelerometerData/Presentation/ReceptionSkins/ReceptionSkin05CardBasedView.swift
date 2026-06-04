//
//  ReceptionSkin05CardBasedView.swift
//  GetAccelerometerData
//
//  Reception Skin 05: Card-Based
//  全要素を独立した角丸シャドウカードで構成。接続インジケータは中央配置のアニメ波紋。
//

import SwiftUI

struct ReceptionSkin05CardBasedView: View {
    @ObservedObject var sessionManager: WatchSessionManager
    @State private var pulse: Bool = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                connectionCard

                if sessionManager.isTransferring {
                    transferringCard
                }

                ForEach(sessionManager.allReceivedFiles, id: \.lastPathComponent) { fileURL in
                    NavigationLink(destination: FileDetailView(fileURL: fileURL)) {
                        fileCard(fileURL: fileURL)
                    }
                    .buttonStyle(PlainButtonStyle())
                }

                if sessionManager.allReceivedFiles.isEmpty {
                    emptyCard
                }

                if !sessionManager.lastMessage.isEmpty {
                    messageCard
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
        }
        .background(Color(.systemGroupedBackground))
        .onAppear {
            if sessionManager.isSessionReachable {
                pulse = true
            }
        }
        .onChange(of: sessionManager.isSessionReachable) { _, newValue in
            pulse = newValue
        }
    }

    private var connectionCard: some View {
        VStack(spacing: 16) {
            ZStack {
                // 波紋（接続時のみアニメ）
                if sessionManager.isSessionReachable {
                    Circle()
                        .stroke(Color.green.opacity(pulse ? 0.0 : 0.5), lineWidth: 3)
                        .frame(width: pulse ? 100 : 50, height: pulse ? 100 : 50)
                        .animation(.easeOut(duration: 1.4).repeatForever(autoreverses: false), value: pulse)
                }
                Circle()
                    .fill(sessionManager.isSessionReachable ? Color.green : Color.gray)
                    .frame(width: 50, height: 50)
                Image(systemName: sessionManager.isSessionReachable ? "wave.3.right" : "wifi.slash")
                    .font(.title2)
                    .foregroundColor(.white)
            }
            .frame(height: 110)
            Text(sessionManager.isSessionReachable ? "Apple Watch 接続中" : "未接続")
                .font(.headline)
                .foregroundColor(sessionManager.isSessionReachable ? .green : .secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(cardBackground)
    }

    private var transferringCard: some View {
        HStack(spacing: 14) {
            ProgressView()
            VStack(alignment: .leading, spacing: 2) {
                Text("ファイル受信中")
                    .font(.subheadline.weight(.semibold))
                Text("Apple Watch から転送中…")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .background(cardBackground)
    }

    private func fileCard(fileURL: URL) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.accentColor.opacity(0.15))
                    .frame(width: 48, height: 48)
                Image(systemName: "doc.text.fill")
                    .font(.title3)
                    .foregroundColor(.accentColor)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(fileURL.lastPathComponent)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                Text(sessionManager.getFileDate(for: fileURL))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .background(cardBackground)
    }

    private var emptyCard: some View {
        VStack(spacing: 10) {
            Image(systemName: "tray")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            Text("受信ファイルなし")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Text("Apple Watch からの転送をお待ちください")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(28)
        .background(cardBackground)
    }

    private var messageCard: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle.fill")
                .foregroundColor(.blue)
            Text(sessionManager.lastMessage)
                .font(.footnote)
            Spacer()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Color(.secondarySystemGroupedBackground))
            .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 2)
    }
}

#if DEBUG
struct ReceptionSkin05CardBasedView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            ReceptionSkin05CardBasedView(sessionManager: WatchSessionManager())
        }
    }
}
#endif
