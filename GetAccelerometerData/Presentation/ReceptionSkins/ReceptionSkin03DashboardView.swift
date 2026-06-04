//
//  ReceptionSkin03DashboardView.swift
//  GetAccelerometerData
//
//  Reception Skin 03: Dashboard
//  上部: 3 メトリックタイル / 中部: プログレスリング / 下部: 横スクロール 5 件 + 通常リスト。
//

import SwiftUI

struct ReceptionSkin03DashboardView: View {
    @ObservedObject var sessionManager: WatchSessionManager

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                metricsRow

                transferStatusRing

                recentHorizontalCards

                fullList

                if !sessionManager.lastMessage.isEmpty {
                    Text(sessionManager.lastMessage)
                        .font(.caption)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                        .padding(.horizontal)
                }
            }
            .padding(.vertical, 12)
        }
    }

    // MARK: - 3 メトリックタイル
    private var metricsRow: some View {
        HStack(spacing: 10) {
            metricTile(
                title: "接続",
                value: sessionManager.isSessionReachable ? "ON" : "OFF",
                color: sessionManager.isSessionReachable ? .green : .red,
                icon: "antenna.radiowaves.left.and.right"
            )
            metricTile(
                title: "ファイル数",
                value: "\(sessionManager.allReceivedFiles.count)",
                color: .blue,
                icon: "tray.full"
            )
            metricTile(
                title: "最終受信",
                value: latestReceptionLabel,
                color: .orange,
                icon: "clock"
            )
        }
        .padding(.horizontal, 12)
    }

    private var latestReceptionLabel: String {
        guard let latest = sessionManager.allReceivedFiles.first else {
            return "-"
        }
        let raw = sessionManager.getFileDate(for: latest)
        // メトリックタイル内に収めるため簡略表示（時刻部分まで、文字数 8 程度）
        let parts = raw.split(separator: " ")
        if parts.count >= 2 {
            return String(parts.last ?? "-")
        }
        return raw
    }

    private func metricTile(title: String, value: String, color: Color, icon: String) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                Text(title)
                    .font(.caption)
            }
            .foregroundColor(.secondary)
            Text(value)
                .font(.title3.weight(.bold))
                .foregroundColor(color)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }

    // MARK: - 中部: プログレスリング風
    private var transferStatusRing: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 6)
                    .frame(width: 80, height: 80)
                if sessionManager.isTransferring {
                    Circle()
                        .trim(from: 0, to: 0.7)
                        .stroke(Color.blue, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .frame(width: 80, height: 80)
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: sessionManager.isTransferring)
                }
                VStack {
                    Image(systemName: sessionManager.isTransferring ? "arrow.down.circle" : "checkmark.circle")
                        .font(.title2)
                        .foregroundColor(sessionManager.isTransferring ? .blue : .green)
                }
            }
            Text(sessionManager.isTransferring ? "ファイル受信中" : "待機中")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    // MARK: - 下部: 最近 5 件の横スクロールカード
    private var recentHorizontalCards: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("最近の受信")
                .font(.headline)
                .padding(.horizontal, 12)

            let recent = Array(sessionManager.allReceivedFiles.prefix(5))
            if recent.isEmpty {
                Text("受信ファイルなし")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 12)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(recent, id: \.lastPathComponent) { fileURL in
                            NavigationLink(destination: FileDetailView(fileURL: fileURL)) {
                                recentCard(fileURL: fileURL)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal, 12)
                }
            }
        }
    }

    private func recentCard(fileURL: URL) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: "doc.text.fill")
                .font(.title3)
                .foregroundColor(.accentColor)
            Text(fileURL.lastPathComponent)
                .font(.caption.weight(.semibold))
                .lineLimit(2)
                .foregroundColor(.primary)
            Text(sessionManager.getFileDate(for: fileURL))
                .font(.caption2)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .frame(width: 140, height: 100, alignment: .topLeading)
        .padding(10)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
    }

    // MARK: - 下部: 全ファイルリスト（5 件超え以降）
    private var fullList: some View {
        VStack(alignment: .leading, spacing: 6) {
            let remaining = sessionManager.allReceivedFiles.dropFirst(5)
            if !remaining.isEmpty {
                Text("その他 \(remaining.count) 件")
                    .font(.headline)
                    .padding(.horizontal, 12)
                VStack(spacing: 4) {
                    ForEach(Array(remaining), id: \.lastPathComponent) { fileURL in
                        NavigationLink(destination: FileDetailView(fileURL: fileURL)) {
                            HStack {
                                Text(fileURL.lastPathComponent)
                                    .font(.caption)
                                    .lineLimit(1)
                                Spacer()
                                Text(sessionManager.getFileDate(for: fileURL))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.gray.opacity(0.06))
                            .cornerRadius(6)
                            .foregroundColor(.primary)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 12)
            }
        }
    }
}

#if DEBUG
struct ReceptionSkin03DashboardView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            ReceptionSkin03DashboardView(sessionManager: WatchSessionManager())
        }
    }
}
#endif
