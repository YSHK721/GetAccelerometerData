//
//  ReceptionSkin02CompactListView.swift
//  GetAccelerometerData
//
//  Reception Skin 02: Compact List
//  情報密度優先。最上部ステータスバー（高さ 28pt 程度）+ 稠密 1 行 1 ファイル表示。
//  Apple Watch アイコン非表示。
//

import SwiftUI

struct ReceptionSkin02CompactListView: View {
    @ObservedObject var sessionManager: WatchSessionManager

    var body: some View {
        VStack(spacing: 0) {
            statusBar

            if sessionManager.isTransferring {
                transferringBar
            }

            if sessionManager.allReceivedFiles.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(sessionManager.allReceivedFiles, id: \.lastPathComponent) { fileURL in
                        NavigationLink(destination: FileDetailView(fileURL: fileURL)) {
                            compactRow(fileURL: fileURL)
                        }
                        .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
                    }
                }
                .listStyle(.plain)
            }

            if !sessionManager.lastMessage.isEmpty {
                Text(sessionManager.lastMessage)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(Color.gray.opacity(0.1))
            }
        }
    }

    private var statusBar: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(sessionManager.isSessionReachable ? Color.green : Color.red)
                .frame(width: 8, height: 8)
            Text(sessionManager.isSessionReachable ? "接続中" : "未接続")
                .font(.caption.weight(.medium))
            Spacer()
            Text("\(sessionManager.allReceivedFiles.count) files")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .frame(height: 28)
        .background(Color.gray.opacity(0.12))
    }

    private var transferringBar: some View {
        HStack(spacing: 6) {
            ProgressView()
                .scaleEffect(0.6)
            Text("受信中…")
                .font(.caption2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .frame(height: 22)
        .background(Color.blue.opacity(0.12))
    }

    private func compactRow(fileURL: URL) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "doc")
                .font(.caption)
                .foregroundColor(.secondary)
            VStack(alignment: .leading, spacing: 1) {
                Text(fileURL.lastPathComponent)
                    .font(.caption.weight(.medium))
                    .lineLimit(1)
                Text(sessionManager.getFileDate(for: fileURL))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
    }

    private var emptyState: some View {
        VStack {
            Spacer()
            Text("ファイル未受信")
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

#if DEBUG
struct ReceptionSkin02CompactListView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            ReceptionSkin02CompactListView(sessionManager: WatchSessionManager())
        }
    }
}
#endif
