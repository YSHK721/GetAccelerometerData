//
//  ReceptionSkin04DarkProView.swift
//  GetAccelerometerData
//
//  Reception Skin 04: Dark Pro
//  ダーク強制 + Monospace + LED 風インジケータ + ターミナルログ風ファイル一覧。
//

import SwiftUI

struct ReceptionSkin04DarkProView: View {
    @ObservedObject var sessionManager: WatchSessionManager
    @State private var blink: Bool = false

    private let backgroundColor = Color(white: 0.08)
    private let lineColor = Color(white: 0.18)

    var body: some View {
        ZStack {
            backgroundColor.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    headerLine
                    Divider().background(lineColor)
                    statusLine
                    Divider().background(lineColor)
                    fileLogSection
                    if sessionManager.isTransferring {
                        Divider().background(lineColor)
                        transferLogLine
                    }
                    if !sessionManager.lastMessage.isEmpty {
                        Divider().background(lineColor)
                        lastMessageLine
                    }
                }
                .padding(16)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            // 未接続時のみ blink を起動（接続時はアニメ不要）
            blink = true
        }
    }

    private var headerLine: some View {
        Text("$ accel-receiver --status")
            .font(.system(.footnote, design: .monospaced).weight(.semibold))
            .foregroundColor(.green)
    }

    private var statusLine: some View {
        HStack(spacing: 10) {
            ledIndicator
            Text(sessionManager.isSessionReachable ? "STATUS: CONNECTED" : "STATUS: DISCONNECTED")
                .font(.system(.subheadline, design: .monospaced).weight(.semibold))
                .foregroundColor(sessionManager.isSessionReachable ? .green : Color(red: 0.8, green: 0.3, blue: 0.3))
        }
    }

    private var ledIndicator: some View {
        Circle()
            .fill(
                sessionManager.isSessionReachable
                    ? Color.green
                    : (blink ? Color.red.opacity(0.85) : Color(red: 0.4, green: 0.15, blue: 0.15))
            )
            .frame(width: 12, height: 12)
            .shadow(
                color: sessionManager.isSessionReachable ? Color.green.opacity(0.7) : Color.red.opacity(blink ? 0.6 : 0.0),
                radius: sessionManager.isSessionReachable ? 6 : (blink ? 4 : 0)
            )
            .animation(
                sessionManager.isSessionReachable
                    ? nil
                    : .easeInOut(duration: 0.9).repeatForever(autoreverses: true),
                value: blink
            )
            .onAppear {
                if !sessionManager.isSessionReachable {
                    blink.toggle()
                }
            }
    }

    private var fileLogSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("# received files (\(sessionManager.allReceivedFiles.count))")
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(Color(white: 0.6))
            if sessionManager.allReceivedFiles.isEmpty {
                Text("[--:--:--] (no files received)")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(Color(white: 0.5))
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(sessionManager.allReceivedFiles, id: \.lastPathComponent) { fileURL in
                        NavigationLink(destination: FileDetailView(fileURL: fileURL)) {
                            logLine(fileURL: fileURL)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
        }
    }

    private func logLine(fileURL: URL) -> some View {
        let date = sessionManager.getFileDate(for: fileURL)
        return Text("[\(date)] received: \(fileURL.lastPathComponent)")
            .font(.system(.caption, design: .monospaced))
            .foregroundColor(Color(white: 0.85))
            .lineLimit(2)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var transferLogLine: some View {
        HStack(spacing: 8) {
            ProgressView()
                .progressViewStyle(.circular)
                .scaleEffect(0.6)
            Text("[transfer] receiving...")
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.cyan)
        }
    }

    private var lastMessageLine: some View {
        Text("# \(sessionManager.lastMessage)")
            .font(.system(.caption, design: .monospaced))
            .foregroundColor(Color(white: 0.7))
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#if DEBUG
struct ReceptionSkin04DarkProView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            ReceptionSkin04DarkProView(sessionManager: WatchSessionManager())
        }
    }
}
#endif
