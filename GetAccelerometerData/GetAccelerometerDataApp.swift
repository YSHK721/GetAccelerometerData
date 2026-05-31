//
//  GetAccelerometerDataApp.swift
//  GetAccelerometerData
//
//  Created by i on 2025/04/22.
//

import SwiftUI

@main
struct GetAccelerometerDataApp: App {
    private let composition = AppComposition()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.appComposition, composition)
        }
    }
}
