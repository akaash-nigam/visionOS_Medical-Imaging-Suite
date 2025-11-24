//
//  WelcomeView.swift
//  MedicalImagingSuite
//
//  Created by Claude on 2025-11-24.
//

import SwiftUI

struct WelcomeView: View {
    var body: some View {
        VStack(spacing: 32) {
            Image(systemName: "heart.text.square")
                .font(.system(size: 100))
                .foregroundStyle(.blue.gradient)

            VStack(spacing: 16) {
                Text("Medical Imaging Suite")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("View medical scans at life-size in spatial computing")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 12) {
                FeatureRow(
                    icon: "cube.transparent",
                    title: "3D Volume Rendering",
                    description: "View CT and MRI scans in full 3D"
                )

                FeatureRow(
                    icon: "ruler",
                    title: "Precise Measurements",
                    description: "Measure distances and angles with sub-millimeter accuracy"
                )

                FeatureRow(
                    icon: "pencil.tip.crop.circle",
                    title: "Surgical Planning",
                    description: "Annotate and plan procedures in spatial environment"
                )
            }
            .padding()

            Button(action: {}) {
                Label("Import DICOM Files", systemImage: "folder.badge.plus")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(40)
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title)
                .foregroundStyle(.blue)
                .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    WelcomeView()
}
