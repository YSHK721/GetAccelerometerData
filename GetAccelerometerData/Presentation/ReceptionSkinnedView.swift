//
//  ReceptionSkinnedView.swift
//  GetAccelerometerData
//
//  「加速度データ受信」ビューの 5 スキン切替コンテナ。
//  共有 WatchSessionManager を @StateObject で保持し、Segmented Picker で 5 スキンを切替える。
//  切替時に WatchSessionManager の再初期化が起きないよう、各スキンには @ObservedObject で渡す。
//

import SwiftUI

struct ReceptionSkinnedView: View {
    @StateObject private var sessionManager = WatchSessionManager()
    @State private var selectedSkin: SkinChoice = .classicRefined

    enum SkinChoice: String, CaseIterable, Identifiable {
        case classicRefined = "Classic"
        case compactList = "Compact"
        case dashboard = "Dashboard"
        case darkPro = "Dark Pro"
        case cardBased = "Cards"
        var id: String { rawValue }
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("Skin", selection: $selectedSkin) {
                ForEach(SkinChoice.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.top, 8)

            Group {
                switch selectedSkin {
                case .classicRefined: ReceptionSkin01ClassicRefinedView(sessionManager: sessionManager)
                case .compactList:    ReceptionSkin02CompactListView(sessionManager: sessionManager)
                case .dashboard:      ReceptionSkin03DashboardView(sessionManager: sessionManager)
                case .darkPro:        ReceptionSkin04DarkProView(sessionManager: sessionManager)
                case .cardBased:      ReceptionSkin05CardBasedView(sessionManager: sessionManager)
                }
            }
        }
        .navigationTitle("加速度データ受信 [Skin]")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { sessionManager.activateSession() }
    }
}

#if DEBUG
struct ReceptionSkinnedView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            ReceptionSkinnedView()
        }
    }
}
#endif
