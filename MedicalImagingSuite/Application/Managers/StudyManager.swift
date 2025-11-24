//
//  StudyManager.swift
//  MedicalImagingSuite
//
//  Manages study list, search, and thumbnails
//

import Foundation
import SwiftUI

// MARK: - Study Filter

struct StudyFilter {
    var searchText: String = ""
    var modality: String? = nil
    var startDate: Date? = nil
    var endDate: Date? = nil
    var patientID: String? = nil

    var isActive: Bool {
        !searchText.isEmpty || modality != nil || startDate != nil || endDate != nil || patientID != nil
    }
}

// MARK: - Study Sort

enum StudySortOption: String, CaseIterable {
    case dateNewest = "Date (Newest)"
    case dateOldest = "Date (Oldest)"
    case patientName = "Patient Name"
    case studyDescription = "Description"

    func compare(_ s1: Study, _ s2: Study) -> Bool {
        switch self {
        case .dateNewest:
            return s1.studyDate > s2.studyDate
        case .dateOldest:
            return s1.studyDate < s2.studyDate
        case .patientName:
            return s1.patientName < s2.patientName
        case .studyDescription:
            return (s1.studyDescription ?? "") < (s2.studyDescription ?? "")
        }
    }
}

// MARK: - Study Manager

/// Manages study list operations
@MainActor
final class StudyManager: ObservableObject {

    @Published var studies: [Study] = []
    @Published var filteredStudies: [Study] = []
    @Published var filter: StudyFilter = StudyFilter()
    @Published var sortOption: StudySortOption = .dateNewest
    @Published var isLoading: Bool = false

    private let repository: StudyRepository
    private let thumbnailCache: ThumbnailCache

    init(repository: StudyRepository) {
        self.repository = repository
        self.thumbnailCache = ThumbnailCache()
    }

    // MARK: - Loading

    func loadStudies() async {
        isLoading = true

        do {
            let loadedStudies = try await repository.fetchAllStudies()
            studies = loadedStudies
            applyFiltersAndSort()

            print("✅ Loaded \(studies.count) studies")
        } catch {
            print("❌ Failed to load studies: \(error)")
        }

        isLoading = false
    }

    func refreshStudies() async {
        await loadStudies()
    }

    // MARK: - Filtering & Sorting

    func applyFiltersAndSort() {
        var results = studies

        // Apply search text filter
        if !filter.searchText.isEmpty {
            results = results.filter { study in
                study.patientName.localizedCaseInsensitiveContains(filter.searchText) ||
                study.patientID.localizedCaseInsensitiveContains(filter.searchText) ||
                (study.studyDescription?.localizedCaseInsensitiveContains(filter.searchText) ?? false)
            }
        }

        // Apply modality filter
        if let modality = filter.modality {
            results = results.filter { study in
                study.series.contains { $0.modality == modality }
            }
        }

        // Apply date range filter
        if let startDate = filter.startDate {
            results = results.filter { $0.studyDate >= startDate }
        }

        if let endDate = filter.endDate {
            results = results.filter { $0.studyDate <= endDate }
        }

        // Apply patient ID filter
        if let patientID = filter.patientID {
            results = results.filter { $0.patientID == patientID }
        }

        // Apply sorting
        results.sort { sortOption.compare($0, $1) }

        filteredStudies = results
    }

    func setFilter(_ newFilter: StudyFilter) {
        filter = newFilter
        applyFiltersAndSort()
    }

    func setSortOption(_ option: StudySortOption) {
        sortOption = option
        applyFiltersAndSort()
    }

    func clearFilters() {
        filter = StudyFilter()
        applyFiltersAndSort()
    }

    // MARK: - Study Operations

    func deleteStudy(_ study: Study) async {
        do {
            try await repository.deleteStudy(uid: study.studyInstanceUID)
            studies.removeAll { $0.id == study.id }
            applyFiltersAndSort()

            print("✅ Deleted study: \(study.studyInstanceUID)")
        } catch {
            print("❌ Failed to delete study: \(error)")
        }
    }

    func deleteAllStudies() async {
        for study in studies {
            try? await repository.deleteStudy(uid: study.studyInstanceUID)
        }

        studies.removeAll()
        filteredStudies.removeAll()

        print("✅ Deleted all studies")
    }

    // MARK: - Thumbnails

    func thumbnail(for study: Study) -> UIImage? {
        return thumbnailCache.thumbnail(for: study.studyInstanceUID)
    }

    func generateThumbnail(for study: Study, from volumeData: VolumeData) {
        thumbnailCache.generateThumbnail(for: study.studyInstanceUID, from: volumeData)
    }

    // MARK: - Statistics

    var statistics: StudyStatistics {
        StudyStatistics(
            totalStudies: studies.count,
            totalSeries: studies.flatMap(\.series).count,
            totalImages: studies.flatMap(\.series).flatMap(\.images).count,
            modalityCounts: modalityCounts(),
            oldestStudy: studies.map(\.studyDate).min(),
            newestStudy: studies.map(\.studyDate).max()
        )
    }

    private func modalityCounts() -> [String: Int] {
        var counts: [String: Int] = [:]

        for study in studies {
            for series in study.series {
                counts[series.modality, default: 0] += 1
            }
        }

        return counts
    }
}

// MARK: - Study Statistics

struct StudyStatistics {
    let totalStudies: Int
    let totalSeries: Int
    let totalImages: Int
    let modalityCounts: [String: Int]
    let oldestStudy: Date?
    let newestStudy: Date?

    var summary: String {
        """
        Studies: \(totalStudies)
        Series: \(totalSeries)
        Images: \(totalImages)
        Modalities: \(modalityCounts.keys.sorted().joined(separator: ", "))
        """
    }
}

// MARK: - Thumbnail Cache

/// Manages thumbnail generation and caching
final class ThumbnailCache {

    private var cache: [String: UIImage] = [:]
    private let queue = DispatchQueue(label: "com.medicalimaging.thumbnailcache")

    func thumbnail(for studyUID: String) -> UIImage? {
        queue.sync {
            return cache[studyUID]
        }
    }

    func generateThumbnail(for studyUID: String, from volumeData: VolumeData) {
        queue.async {
            // Generate thumbnail from middle slice
            let middleZ = volumeData.dimensions.z / 2

            // TODO: Extract slice and create UIImage
            // For now, create placeholder
            let thumbnail = self.createPlaceholder()

            self.cache[studyUID] = thumbnail
        }
    }

    private func createPlaceholder() -> UIImage {
        let size = CGSize(width: 128, height: 128)
        let renderer = UIGraphicsImageRenderer(size: size)

        return renderer.image { context in
            UIColor.systemGray.setFill()
            context.fill(CGRect(origin: .zero, size: size))

            // Draw crosshair
            UIColor.white.setStroke()
            let path = UIBezierPath()
            path.move(to: CGPoint(x: size.width / 2, y: 0))
            path.addLine(to: CGPoint(x: size.width / 2, y: size.height))
            path.move(to: CGPoint(x: 0, y: size.height / 2))
            path.addLine(to: CGPoint(x: size.width, y: size.height / 2))
            path.lineWidth = 2
            path.stroke()
        }
    }

    func clearCache() {
        queue.sync {
            cache.removeAll()
        }
    }
}
