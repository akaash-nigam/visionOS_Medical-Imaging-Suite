//
//  ContentView.swift
//  MedicalImagingSuite
//
//  Created by Claude on 2025-11-24.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var showingFileImporter = false

    var body: some View {
        NavigationSplitView {
            // Sidebar: Study list
            StudyListView()
        } detail: {
            // Main content area
            if appState.isAuthenticated {
                WelcomeView()
            } else {
                AuthenticationView()
            }
        }
        .fileImporter(
            isPresented: $showingFileImporter,
            allowedContentTypes: [.data],
            allowsMultipleSelection: true
        ) { result in
            handleFileImport(result)
        }
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            print("Selected files: \(urls)")
            // TODO: Import DICOM files
        case .failure(let error):
            print("File import error: \(error)")
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}
