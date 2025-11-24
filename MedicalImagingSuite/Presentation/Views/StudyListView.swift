//
//  StudyListView.swift
//  MedicalImagingSuite
//
//  Created by Claude on 2025-11-24.
//

import SwiftUI

struct StudyListView: View {
    @State private var studies: [Study] = []
    @State private var searchText = ""

    var body: some View {
        List {
            Section {
                if studies.isEmpty {
                    ContentUnavailableView(
                        "No Studies",
                        systemImage: "tray",
                        description: Text("Import DICOM files to get started")
                    )
                } else {
                    ForEach(studies) { study in
                        StudyRow(study: study)
                    }
                }
            } header: {
                Text("Recent Studies")
            }
        }
        .navigationTitle("Studies")
        .searchable(text: $searchText, prompt: "Search studies")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: {}) {
                    Label("Import", systemImage: "square.and.arrow.down")
                }
            }
        }
    }
}

struct StudyRow: View {
    let study: Study

    var body: some View {
        HStack(spacing: 16) {
            // Thumbnail placeholder
            RoundedRectangle(cornerRadius: 8)
                .fill(.tertiary)
                .frame(width: 60, height: 60)
                .overlay {
                    Image(systemName: "doc.text.image")
                        .foregroundStyle(.secondary)
                }

            VStack(alignment: .leading, spacing: 4) {
                Text(study.patient.name.formatted)
                    .font(.headline)

                Text(study.studyDescription ?? "No Description")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack {
                    Label(
                        study.studyDate?.formatted(date: .abbreviated, time: .omitted) ?? "",
                        systemImage: "calendar"
                    )
                    .font(.caption)

                    Label(
                        study.modalities.map { $0.rawValue }.joined(separator: ", "),
                        systemImage: "camera"
                    )
                    .font(.caption)
                }
                .foregroundStyle(.tertiary)
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        StudyListView()
    }
}
