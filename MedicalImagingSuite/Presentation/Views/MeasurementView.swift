//
//  MeasurementView.swift
//  MedicalImagingSuite
//
//  UI for measurement tools and measurement list
//

import SwiftUI

// MARK: - Measurement View

/// Main view for measurement tools
struct MeasurementView: View {
    @StateObject private var manager = MeasurementToolManager()
    @State private var selectedMeasurement: Measurement?
    @State private var isEditingLabel: Bool = false
    @State private var newLabel: String = ""

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            toolBar

            Divider()

            // Measurement list
            measurementList

            Divider()

            // Export options
            exportSection
        }
        .frame(width: 300)
        .glassBackgroundEffect()
    }

    // MARK: - Toolbar

    private var toolBar: some View {
        VStack(spacing: 12) {
            Text("Measurements")
                .font(.headline)

            // Measurement type picker
            Picker("Type", selection: $manager.activeMeasurementType) {
                ForEach(MeasurementType.allCases, id: \.self) { type in
                    Label(type.rawValue, systemImage: type.icon)
                        .tag(type)
                }
            }
            .pickerStyle(.segmented)

            // Action buttons
            HStack(spacing: 8) {
                Button(action: {
                    manager.startMeasurement()
                }) {
                    Label("New", systemImage: "plus.circle")
                }
                .buttonStyle(.borderedProminent)
                .disabled(manager.isActive)

                if manager.isActive {
                    Button(action: {
                        manager.cancelMeasurement()
                    }) {
                        Label("Cancel", systemImage: "xmark")
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                }

                Spacer()

                Button(action: {
                    manager.deleteAll()
                }) {
                    Label("Clear All", systemImage: "trash")
                }
                .buttonStyle(.bordered)
                .tint(.red)
                .disabled(manager.measurements.isEmpty)
            }
        }
        .padding()
    }

    // MARK: - Measurement List

    private var measurementList: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                if manager.measurements.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "ruler")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)

                        Text("No measurements")
                            .font(.headline)
                            .foregroundStyle(.secondary)

                        Text("Select a measurement type and tap 'New' to start")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                } else {
                    ForEach(manager.measurements) { measurement in
                        measurementRow(measurement)
                    }
                }
            }
            .padding()
        }
    }

    private func measurementRow(_ measurement: Measurement) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                // Type icon
                Image(systemName: measurement.type.icon)
                    .foregroundColor(measurement.color.color)

                // Label or type
                Text(measurement.label ?? measurement.type.rawValue)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Spacer()

                // Value
                Text(measurement.formattedValue)
                    .font(.subheadline)
                    .monospacedDigit()
                    .foregroundColor(.primary)
            }

            // Timestamp
            Text(measurement.timestamp, style: .relative)
                .font(.caption2)
                .foregroundStyle(.secondary)

            // Point count
            Text("\(measurement.points.count) point\(measurement.points.count == 1 ? "" : "s")")
                .font(.caption2)
                .foregroundStyle(.tertiary)

            // Actions
            HStack(spacing: 4) {
                Button(action: {
                    selectedMeasurement = measurement
                    newLabel = measurement.label ?? ""
                    isEditingLabel = true
                }) {
                    Label("Edit", systemImage: "pencil")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)

                Button(action: {
                    manager.deleteMeasurement(measurement)
                }) {
                    Label("Delete", systemImage: "trash")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
                .tint(.red)
            }
        }
        .padding()
        .background(.quaternary.opacity(0.5))
        .cornerRadius(8)
        .sheet(isPresented: $isEditingLabel) {
            editLabelSheet
        }
    }

    // MARK: - Edit Label Sheet

    private var editLabelSheet: some View {
        VStack(spacing: 16) {
            Text("Edit Label")
                .font(.headline)

            TextField("Label", text: $newLabel)
                .textFieldStyle(.roundedBorder)

            HStack {
                Button("Cancel") {
                    isEditingLabel = false
                }
                .buttonStyle(.bordered)

                Button("Save") {
                    if let measurement = selectedMeasurement {
                        manager.updateLabel(for: measurement, label: newLabel)
                    }
                    isEditingLabel = false
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(width: 300)
    }

    // MARK: - Export Section

    private var exportSection: some View {
        VStack(spacing: 8) {
            Text("Export")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                Button(action: exportJSON) {
                    Label("JSON", systemImage: "doc.text")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button(action: exportCSV) {
                    Label("CSV", systemImage: "tablecells")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button(action: exportDICOM) {
                    Label("DICOM SR", systemImage: "doc.badge.gearshape")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding()
        .disabled(manager.measurements.isEmpty)
    }

    // MARK: - Export Actions

    private func exportJSON() {
        guard let json = manager.exportAsJSON() else {
            print("❌ Failed to export JSON")
            return
        }

        // Save to file
        saveToFile(content: json, filename: "measurements.json")
    }

    private func exportCSV() {
        let csv = manager.exportAsCSV()
        saveToFile(content: csv, filename: "measurements.csv")
    }

    private func exportDICOM() {
        // TODO: Implement DICOM Structured Report export
        print("📋 DICOM SR export not yet implemented")
    }

    private func saveToFile(content: String, filename: String) {
        // In a real app, this would use file picker or share sheet
        print("💾 Saving to \(filename)")
        print(content)
    }
}

// MARK: - Measurement Stats View

/// Summary statistics for measurements
struct MeasurementStatsView: View {
    let measurements: [Measurement]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Statistics")
                .font(.headline)

            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 4) {
                GridRow {
                    Text("Total:")
                        .foregroundStyle(.secondary)
                    Text("\(measurements.count)")
                        .monospacedDigit()
                }

                ForEach(MeasurementType.allCases, id: \.self) { type in
                    GridRow {
                        Label(type.rawValue + ":", systemImage: type.icon)
                            .foregroundStyle(.secondary)
                        Text("\(measurements.filter { $0.type == type }.count)")
                            .monospacedDigit()
                    }
                }

                if !measurements.isEmpty {
                    Divider()

                    GridRow {
                        Text("Oldest:")
                            .foregroundStyle(.secondary)
                        if let oldest = measurements.map(\.timestamp).min() {
                            Text(oldest, style: .relative)
                        }
                    }

                    GridRow {
                        Text("Newest:")
                            .foregroundStyle(.secondary)
                        if let newest = measurements.map(\.timestamp).max() {
                            Text(newest, style: .relative)
                        }
                    }
                }
            }
            .font(.caption)
        }
        .padding()
        .background(.quaternary.opacity(0.3))
        .cornerRadius(8)
    }
}

// MARK: - Measurement Tool Palette

/// Floating tool palette for quick access
struct MeasurementToolPalette: View {
    @Binding var selectedTool: MeasurementType
    @Binding var isActive: Bool

    var body: some View {
        HStack(spacing: 12) {
            ForEach(MeasurementType.allCases, id: \.self) { type in
                Button(action: {
                    selectedTool = type
                    isActive = true
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: type.icon)
                            .font(.title2)
                        Text(type.rawValue)
                            .font(.caption2)
                    }
                    .frame(width: 60, height: 60)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .tint(selectedTool == type && isActive ? .blue : .gray)
            }
        }
        .padding()
        .glassBackgroundEffect()
    }
}

// MARK: - Preview

#if DEBUG
struct MeasurementView_Previews: PreviewProvider {
    static var previews: some View {
        MeasurementView()
    }
}
#endif
