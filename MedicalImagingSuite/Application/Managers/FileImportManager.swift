//
//  FileImportManager.swift
//  MedicalImagingSuite
//
//  Manages DICOM file import from local storage
//

import Foundation
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Import Status

enum ImportStatus: Equatable {
    case idle
    case importing(progress: Double, current: Int, total: Int)
    case completed(studiesImported: Int)
    case failed(error: String)
}

// MARK: - Import Result

struct ImportResult {
    let studiesImported: Int
    let seriesImported: Int
    let imagesImported: Int
    let errors: [ImportError]
    let duration: TimeInterval

    var summary: String {
        """
        Import completed in \(String(format: "%.1f", duration))s
        Studies: \(studiesImported)
        Series: \(seriesImported)
        Images: \(imagesImported)
        Errors: \(errors.count)
        """
    }
}

struct ImportError {
    let filename: String
    let error: String
}

// MARK: - File Import Manager

/// Manages file import operations
@MainActor
final class FileImportManager: ObservableObject {

    @Published var status: ImportStatus = .idle
    @Published var lastResult: ImportResult?

    private let dicomImportService: DICOMImportService
    private let studyRepository: StudyRepository

    init(dicomImportService: DICOMImportService, studyRepository: StudyRepository) {
        self.dicomImportService = dicomImportService
        self.studyRepository = studyRepository
    }

    // MARK: - Single File Import

    /// Import a single DICOM file
    func importFile(url: URL) async {
        status = .importing(progress: 0, current: 0, total: 1)

        let startTime = Date()

        do {
            let study = try await dicomImportService.importSingleFile(url: url)
            try await studyRepository.saveStudy(study)

            let duration = Date().timeIntervalSince(startTime)
            let result = ImportResult(
                studiesImported: 1,
                seriesImported: study.series.count,
                imagesImported: study.series.flatMap(\.images).count,
                errors: [],
                duration: duration
            )

            lastResult = result
            status = .completed(studiesImported: 1)

            print("✅ \(result.summary)")

        } catch {
            status = .failed(error: error.localizedDescription)
            print("❌ Import failed: \(error)")
        }
    }

    // MARK: - Folder Import

    /// Import all DICOM files from a folder
    func importFolder(url: URL) async {
        let startTime = Date()
        var errors: [ImportError] = []
        var studyCount = 0

        // Find all DICOM files
        let files = findDICOMFiles(in: url)
        let total = files.count

        guard !files.isEmpty else {
            status = .failed(error: "No DICOM files found in folder")
            return
        }

        print("📁 Found \(total) DICOM files")

        // Import each file
        for (index, fileURL) in files.enumerated() {
            let progress = Double(index) / Double(total)
            status = .importing(progress: progress, current: index + 1, total: total)

            do {
                let study = try await dicomImportService.importSingleFile(url: fileURL)
                try await studyRepository.saveStudy(study)
                studyCount += 1
            } catch {
                errors.append(ImportError(
                    filename: fileURL.lastPathComponent,
                    error: error.localizedDescription
                ))
            }
        }

        let duration = Date().timeIntervalSince(startTime)

        // Get all imported studies for statistics
        let allStudies = try? await studyRepository.fetchAllStudies()
        let seriesCount = allStudies?.flatMap(\.series).count ?? 0
        let imageCount = allStudies?.flatMap(\.series).flatMap(\.images).count ?? 0

        let result = ImportResult(
            studiesImported: studyCount,
            seriesImported: seriesCount,
            imagesImported: imageCount,
            errors: errors,
            duration: duration
        )

        lastResult = result
        status = .completed(studiesImported: studyCount)

        print("✅ \(result.summary)")
    }

    // MARK: - Batch Import

    /// Import multiple files at once
    func importFiles(urls: [URL]) async {
        let startTime = Date()
        var errors: [ImportError] = []
        var studyCount = 0
        let total = urls.count

        for (index, url) in urls.enumerated() {
            let progress = Double(index) / Double(total)
            status = .importing(progress: progress, current: index + 1, total: total)

            do {
                let study = try await dicomImportService.importSingleFile(url: url)
                try await studyRepository.saveStudy(study)
                studyCount += 1
            } catch {
                errors.append(ImportError(
                    filename: url.lastPathComponent,
                    error: error.localizedDescription
                ))
            }
        }

        let duration = Date().timeIntervalSince(startTime)
        let allStudies = try? await studyRepository.fetchAllStudies()
        let seriesCount = allStudies?.flatMap(\.series).count ?? 0
        let imageCount = allStudies?.flatMap(\.series).flatMap(\.images).count ?? 0

        let result = ImportResult(
            studiesImported: studyCount,
            seriesImported: seriesCount,
            imagesImported: imageCount,
            errors: errors,
            duration: duration
        )

        lastResult = result
        status = .completed(studiesImported: studyCount)

        print("✅ \(result.summary)")
    }

    // MARK: - File Discovery

    private func findDICOMFiles(in directory: URL) -> [URL] {
        let fileManager = FileManager.default
        var dicomFiles: [URL] = []

        guard let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        for case let fileURL as URL in enumerator {
            // Check if file is regular file
            guard let resourceValues = try? fileURL.resourceValues(forKeys: [.isRegularFileKey]),
                  resourceValues.isRegularFile == true else {
                continue
            }

            // Check if file looks like DICOM (no extension or .dcm/.dicom)
            let ext = fileURL.pathExtension.lowercased()
            if ext.isEmpty || ext == "dcm" || ext == "dicom" {
                dicomFiles.append(fileURL)
            }
        }

        return dicomFiles
    }

    // MARK: - Reset

    func reset() {
        status = .idle
        lastResult = nil
    }
}

// MARK: - Supported File Types

extension UTType {
    static let dicom = UTType(filenameExtension: "dcm") ?? .data
    static let dicomAlt = UTType(filenameExtension: "dicom") ?? .data
}
