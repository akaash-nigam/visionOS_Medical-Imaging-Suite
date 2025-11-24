//
//  SliceNavigationView.swift
//  MedicalImagingSuite
//
//  Created by Claude on 2025-11-24.
//

import SwiftUI

/// View for navigating and displaying 2D slices from 3D volume
struct SliceNavigationView: View {
    let volume: VolumeData

    @StateObject private var viewModel: SliceNavigationViewModel
    @State private var selectedPlane: AnatomicalPlane = .axial

    init(volume: VolumeData) {
        self.volume = volume
        self._viewModel = StateObject(wrappedValue: SliceNavigationViewModel(volume: volume))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Plane selector
            Picker("Plane", selection: $selectedPlane) {
                ForEach(AnatomicalPlane.allCases, id: \.self) { plane in
                    Label(plane.rawValue, systemImage: plane.icon)
                        .tag(plane)
                }
            }
            .pickerStyle(.segmented)
            .padding()
            .onChange(of: selectedPlane) { _, newPlane in
                Task {
                    await viewModel.changePlane(newPlane)
                }
            }

            // Slice viewer
            GeometryReader { geometry in
                ZStack {
                    if let image = viewModel.currentImage {
                        Image(image, scale: 1.0, label: Text("Medical slice"))
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if viewModel.isLoading {
                        ProgressView("Loading slice...")
                    } else {
                        Text("No image available")
                            .foregroundColor(.secondary)
                    }

                    // Slice info overlay
                    VStack {
                        HStack {
                            sliceInfoPanel
                            Spacer()
                        }
                        Spacer()
                    }
                    .padding()
                }
            }

            // Navigation controls
            VStack(spacing: 12) {
                // Slice index slider
                HStack {
                    Text("\(viewModel.currentIndex + 1) / \(viewModel.maxSlices)")
                        .font(.caption)
                        .monospacedDigit()
                        .frame(width: 80)

                    Slider(
                        value: Binding(
                            get: { Double(viewModel.currentIndex) },
                            set: { newValue in
                                Task {
                                    await viewModel.setSliceIndex(Int(newValue))
                                }
                            }
                        ),
                        in: 0...Double(max(0, viewModel.maxSlices - 1)),
                        step: 1
                    )

                    Button {
                        Task {
                            await viewModel.playAnimation()
                        }
                    } label: {
                        Image(systemName: viewModel.isAnimating ? "pause.fill" : "play.fill")
                    }
                    .buttonStyle(.bordered)
                }

                // Quick navigation
                HStack {
                    Button("First") {
                        Task {
                            await viewModel.setSliceIndex(0)
                        }
                    }
                    .buttonStyle(.bordered)

                    Button("Previous") {
                        Task {
                            await viewModel.previousSlice()
                        }
                    }
                    .buttonStyle(.bordered)

                    Button("Next") {
                        Task {
                            await viewModel.nextSlice()
                        }
                    }
                    .buttonStyle(.bordered)

                    Button("Last") {
                        Task {
                            await viewModel.setSliceIndex(viewModel.maxSlices - 1)
                        }
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding()
        }
        .task {
            await viewModel.initialize()
        }
    }

    // MARK: - Slice Info Panel

    private var sliceInfoPanel: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(selectedPlane.rawValue)
                .font(.headline)
            Text("Slice \(viewModel.currentIndex + 1)/\(viewModel.maxSlices)")
                .font(.caption)
            Text("W/L: \(Int(volume.windowCenter))/\(Int(volume.windowWidth))")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(8)
        .background(.ultraThinMaterial)
        .cornerRadius(8)
    }
}

// MARK: - View Model

@MainActor
class SliceNavigationViewModel: ObservableObject {
    @Published var currentImage: CGImage?
    @Published var currentIndex: Int = 0
    @Published var isLoading = false
    @Published var isAnimating = false

    private let volume: VolumeData
    private let extractor = SliceExtractor()
    private var currentPlane: AnatomicalPlane = .axial
    private var animationTask: Task<Void, Never>?

    var maxSlices: Int {
        volume.sliceCount(for: currentPlane)
    }

    init(volume: VolumeData) {
        self.volume = volume
    }

    func initialize() async {
        await loadSlice(index: 0)
    }

    func changePlane(_ plane: AnatomicalPlane) async {
        currentPlane = plane
        currentIndex = maxSlices / 2  // Start at middle slice
        await loadSlice(index: currentIndex)
    }

    func setSliceIndex(_ index: Int) async {
        guard index >= 0 && index < maxSlices else { return }
        currentIndex = index
        await loadSlice(index: index)
    }

    func nextSlice() async {
        let newIndex = min(currentIndex + 1, maxSlices - 1)
        await setSliceIndex(newIndex)
    }

    func previousSlice() async {
        let newIndex = max(currentIndex - 1, 0)
        await setSliceIndex(newIndex)
    }

    func playAnimation() async {
        if isAnimating {
            // Stop animation
            animationTask?.cancel()
            animationTask = nil
            isAnimating = false
        } else {
            // Start animation
            isAnimating = true
            animationTask = Task {
                while !Task.isCancelled && isAnimating {
                    await nextSlice()
                    if currentIndex >= maxSlices - 1 {
                        currentIndex = 0
                    }
                    try? await Task.sleep(nanoseconds: 100_000_000)  // 100ms per frame
                }
            }
        }
    }

    private func loadSlice(index: Int) async {
        isLoading = true

        do {
            let slice = try await extractor.extractSlice(
                from: volume,
                plane: currentPlane,
                index: index
            )

            if let image = await extractor.createImage(from: slice) {
                self.currentImage = image
            }
        } catch {
            print("❌ Failed to load slice: \(error)")
        }

        isLoading = false
    }
}

// MARK: - Multi-Plane View

/// View showing all three anatomical planes simultaneously
struct MultiPlaneView: View {
    let volume: VolumeData

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    // Axial (top-left)
                    SliceNavigationView(volume: volume)
                        .frame(width: geometry.size.width / 2 - 4)

                    // Coronal (top-right)
                    SliceNavigationView(volume: volume)
                        .frame(width: geometry.size.width / 2 - 4)
                }

                // Sagittal (bottom)
                SliceNavigationView(volume: volume)
                    .frame(height: geometry.size.height / 2 - 4)
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
struct SliceNavigationView_Previews: PreviewProvider {
    static var previews: some View {
        SliceNavigationView(volume: VolumeData.sample)
    }
}
#endif
