//
//  StudyViewerView.swift
//  MedicalImagingSuite
//
//  Created by Claude on 2025-11-24.
//

import SwiftUI
import RealityKit

/// Main study viewer integrating DICOM import and 3D rendering
struct StudyViewerView: View {
    @StateObject private var viewModel = StudyViewerViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                if let result = viewModel.importResult {
                    // Show viewer based on mode
                    Group {
                        if viewModel.viewMode == .volume3D {
                            VolumeView(
                                volume: result.volume,
                                windowLevel: viewModel.selectedWindowLevel
                            )
                        } else {
                            SliceNavigationView(volume: result.volume)
                        }
                    }
                    .overlay(alignment: .topLeading) {
                        studyInfoPanel(result: result)
                    }
                    .overlay(alignment: .bottomTrailing) {
                        controlsPanel()
                    }
                } else if viewModel.isImporting {
                    // Show loading state
                    ProgressView {
                        VStack(spacing: 16) {
                            Text("Importing DICOM files...")
                            if let progress = viewModel.importProgress {
                                Text(progress)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                } else {
                    // Show import options
                    importOptionsView()
                }
            }
            .navigationTitle("Study Viewer")
            .alert("Import Error", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "Unknown error")
            }
        }
    }

    // MARK: - Import Options

    private func importOptionsView() -> some View {
        VStack(spacing: 32) {
            Text("Medical Imaging Suite")
                .font(.largeTitle)
                .bold()

            VStack(spacing: 16) {
                Button {
                    viewModel.showFileImporter = true
                } label: {
                    Label("Import DICOM File", systemImage: "doc.badge.plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Button {
                    viewModel.showDirectoryImporter = true
                } label: {
                    Label("Import DICOM Folder", systemImage: "folder.badge.plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                #if DEBUG
                Button {
                    Task {
                        await viewModel.loadSampleData()
                    }
                } label: {
                    Label("Load Sample CT", systemImage: "heart.text.square")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                #endif
            }
            .frame(maxWidth: 400)
        }
        .padding()
        .fileImporter(
            isPresented: $viewModel.showFileImporter,
            allowedContentTypes: [.data],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    Task {
                        await viewModel.importFile(url)
                    }
                }
            case .failure(let error):
                viewModel.handleError(error)
            }
        }
        .fileImporter(
            isPresented: $viewModel.showDirectoryImporter,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    Task {
                        await viewModel.importDirectory(url)
                    }
                }
            case .failure(let error):
                viewModel.handleError(error)
            }
        }
    }

    // MARK: - Study Info Panel

    private func studyInfoPanel(result: DICOMImportResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(result.patient.name.formatted)
                .font(.headline)
            Text("ID: \(result.patient.patientID)")
                .font(.caption)
            Text(result.study.studyDescription ?? "Unknown Study")
                .font(.subheadline)
            Text("\(result.series.modality.displayName) • \(result.images.count) images")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(12)
        .padding()
    }

    // MARK: - Controls Panel

    private func controlsPanel() -> some View {
        VStack(alignment: .trailing, spacing: 16) {
            // View mode toggle
            Picker("View Mode", selection: $viewModel.viewMode) {
                Label("3D", systemImage: "cube.fill")
                    .tag(ViewMode.volume3D)
                Label("2D", systemImage: "square.grid.2x2")
                    .tag(ViewMode.slices2D)
            }
            .pickerStyle(.segmented)
            .frame(width: 200)

            // Window/Level presets
            Menu {
                ForEach(WindowLevel.allPresets, id: \.name) { preset in
                    Button(preset.name) {
                        viewModel.selectedWindowLevel = preset
                    }
                }
            } label: {
                Label("Window/Level", systemImage: "slider.horizontal.3")
            }
            .buttonStyle(.bordered)

            // View controls
            Button {
                // Reset view
            } label: {
                Label("Reset View", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)

            // New import
            Button {
                viewModel.reset()
            } label: {
                Label("New Import", systemImage: "plus.circle")
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }
}

// MARK: - View Model

/// View mode for study viewer
enum ViewMode {
    case volume3D
    case slices2D
}

@MainActor
class StudyViewerViewModel: ObservableObject {
    @Published var importResult: DICOMImportResult?
    @Published var isImporting = false
    @Published var importProgress: String?
    @Published var selectedWindowLevel: WindowLevel = .softTissue
    @Published var viewMode: ViewMode = .volume3D
    @Published var showFileImporter = false
    @Published var showDirectoryImporter = false
    @Published var showError = false
    @Published var errorMessage: String?

    private let importService = DICOMImportService()

    // MARK: - Import Methods

    func importFile(_ url: URL) async {
        isImporting = true
        importProgress = "Parsing DICOM file..."

        do {
            let result = try await importService.importFile(url)
            self.importResult = result
            print("✅ Import successful: \(result.summary)")
        } catch {
            handleError(error)
        }

        isImporting = false
        importProgress = nil
    }

    func importDirectory(_ url: URL) async {
        isImporting = true
        importProgress = "Scanning directory..."

        do {
            let results = try await importService.importDirectory(url)
            // For now, just show the first series
            if let firstResult = results.first {
                self.importResult = firstResult
                print("✅ Imported \(results.count) series")
            } else {
                throw DICOMImportError.noValidImages
            }
        } catch {
            handleError(error)
        }

        isImporting = false
        importProgress = nil
    }

    func loadSampleData() async {
        isImporting = true
        importProgress = "Generating sample CT data..."

        // Create sample CT series
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("Sample-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        var urls: [URL] = []
        for i in 0..<20 {
            var params = TestFixtures.DICOMGenerationParams()
            params.rows = 256
            params.columns = 256
            params.pixelRepresentation = 1
            params.rescaleSlope = 1.0
            params.rescaleIntercept = -1024.0
            params.windowCenter = 40.0
            params.windowWidth = 400.0
            params.pixelSpacing = (0.7, 0.7)

            let data = TestFixtures.generateSyntheticDICOM(params: params)
            let url = tempDir.appendingPathComponent("slice_\(String(format: "%03d", i)).dcm")
            try? data.write(to: url)
            urls.append(url)
        }

        do {
            let result = try await importService.importSeries(urls)
            self.importResult = result
            print("✅ Loaded sample data")
        } catch {
            handleError(error)
        }

        isImporting = false
        importProgress = nil

        // Clean up temp files after a delay
        Task {
            try? await Task.sleep(nanoseconds: 5_000_000_000)  // 5 seconds
            try? FileManager.default.removeItem(at: tempDir)
        }
    }

    func reset() {
        importResult = nil
        selectedWindowLevel = .softTissue
    }

    func handleError(_ error: Error) {
        errorMessage = error.localizedDescription
        showError = true
        print("❌ Error: \(error)")
    }
}

// MARK: - Preview

#if DEBUG
struct StudyViewerView_Previews: PreviewProvider {
    static var previews: some View {
        StudyViewerView()
    }
}
#endif
