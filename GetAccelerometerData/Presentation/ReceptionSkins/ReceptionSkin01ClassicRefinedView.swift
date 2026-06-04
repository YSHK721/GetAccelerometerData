//
//  ReceptionSkin01ClassicRefinedView.swift
//  GetAccelerometerData
//
//  Reception Skin 01: Classic Refined
//  既存 ContentView をベースに視覚階層を整理。Section ベース構成 + カード化ファイル行。
//

import SwiftUI

struct ReceptionSkin01ClassicRefinedView: View {
    @ObservedObject var sessionManager: WatchSessionManager

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Apple Watch アイコン
                Image(systemName: "applewatch")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 88, height: 88)
                    .foregroundColor(.accentColor)
                    .padding(.top, 8)

                // 接続バッジ（拡大）
                connectionBadge

                // セクション: 受信ファイル
                receivedFilesSection

                // セクション: 転送進行
                if sessionManager.isTransferring {
                    transferringSection
                }

                // セクション: 直近メッセージ
                if !sessionManager.lastMessage.isEmpty {
                    lastMessageSection
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
    }

    private var connectionBadge: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(sessionManager.isSessionReachable ? Color.green : Color.red)
                .frame(width: 14, height: 14)
            Text("接続状態: \(sessionManager.isSessionReachable ? "接続中" : "未接続")")
                .font(.title3.weight(.semibold))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            (sessionManager.isSessionReachable ? Color.green : Color.red).opacity(0.15)
        )
        .cornerRadius(14)
        .animation(.easeInOut, value: sessionManager.isSessionReachable)
    }

    private var receivedFilesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("受信ファイル")
                    .font(.headline)
                Spacer()
                Text("\(sessionManager.allReceivedFiles.count) 件")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            if sessionManager.allReceivedFiles.isEmpty {
                Text("Apple Watch からファイルを受信していません")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .background(Color.gray.opacity(0.08))
                    .cornerRadius(10)
            } else {
                VStack(spacing: 10) {
                    ForEach(sessionManager.allReceivedFiles, id: \.lastPathComponent) { fileURL in
                        NavigationLink(destination: FileDetailView(fileURL: fileURL)) {
                            fileCard(fileURL: fileURL)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
        }
    }

    private func fileCard(fileURL: URL) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "doc.text")
                .font(.title3)
                .foregroundColor(.accentColor)
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
        .padding(12)
        .background(Color.gray.opacity(0.08))
        .cornerRadius(10)
    }

    private var transferringSection: some View {
        HStack(spacing: 10) {
            ProgressView()
            Text("ファイル受信中…")
                .font(.subheadline)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(10)
    }

    private var lastMessageSection: some View {
        Text(sessionManager.lastMessage)
            .font(.footnote)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color.gray.opacity(0.12))
            .cornerRadius(8)
    }
}

#if DEBUG
struct ReceptionSkin01ClassicRefinedView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            ReceptionSkin01ClassicRefinedView(sessionManager: WatchSessionManager())
        }
    }
}
#endif
