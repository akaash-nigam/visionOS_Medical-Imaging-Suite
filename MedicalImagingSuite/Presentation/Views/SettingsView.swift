//
//  SettingsView.swift
//  MedicalImagingSuite
//
//  Created by Claude on 2025-11-24.
//

import SwiftUI

struct SettingsView: View {
    @AppStorage("cacheRetentionDays") private var cacheRetentionDays = 7
    @AppStorage("defaultWindowingPreset") private var defaultWindowingPreset = "softTissue"
    @AppStorage("measurementUnit") private var measurementUnit = "mm"

    var body: some View {
        Form {
            Section {
                Picker("Cache Retention", selection: $cacheRetentionDays) {
                    Text("3 days").tag(3)
                    Text("7 days").tag(7)
                    Text("14 days").tag(14)
                    Text("30 days").tag(30)
                }

                Button("Clear Cache") {
                    // TODO: Implement cache clearing
                }
            } header: {
                Text("Storage")
            } footer: {
                Text("Studies will be automatically removed after the retention period")
            }

            Section("Defaults") {
                Picker("Windowing Preset", selection: $defaultWindowingPreset) {
                    Text("Bone").tag("bone")
                    Text("Soft Tissue").tag("softTissue")
                    Text("Lung").tag("lung")
                    Text("Brain").tag("brain")
                }

                Picker("Measurement Unit", selection: $measurementUnit) {
                    Text("Millimeters (mm)").tag("mm")
                    Text("Centimeters (cm)").tag("cm")
                }
            }

            Section("Security") {
                Toggle("Require Authentication", isOn: .constant(true))
                    .disabled(true)

                Picker("Session Timeout", selection: .constant(15)) {
                    Text("5 minutes").tag(5)
                    Text("15 minutes").tag(15)
                    Text("30 minutes").tag(30)
                    Text("Never").tag(0)
                }
            }

            Section("About") {
                LabeledContent("Version", value: "1.0.0 (MVP)")
                LabeledContent("Build", value: "2024.11.24")

                Link("Privacy Policy", destination: URL(string: "https://example.com/privacy")!)
                Link("Terms of Service", destination: URL(string: "https://example.com/terms")!)
            }
        }
        .navigationTitle("Settings")
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}
