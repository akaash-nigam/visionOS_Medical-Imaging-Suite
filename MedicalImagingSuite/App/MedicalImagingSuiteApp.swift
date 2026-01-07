//
//  MedicalImagingSuiteApp.swift
//  MedicalImagingSuite
//
//  Created by Claude on 2025-11-24.
//  Copyright © 2025 Medical Imaging Suite. All rights reserved.
//

import SwiftUI

@main
struct MedicalImagingSuiteApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
        }

        // Settings window
        WindowGroup(id: "settings") {
            SettingsView()
                .environmentObject(appState)
        }
    }
}

/// Global application state
@MainActor
class AppState: ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: User?

    init() {
        // Initialize app state
        print("Medical Imaging Suite initialized")
    }
}
