//
//  DICOMImportService.swift
//  MedicalImagingSuite
//
//  Created by Claude on 2025-11-24.
//

import Foundation

/// Orchestrates the complete DICOM import workflow
actor DICOMImportService {

    private let parser: DICOMParserImpl
    private let mapper: DICOMMapper
    private let reconstructor: VolumeReconstructor

    init() {
        self.parser = DICOMParserImpl()
        self.mapper = DICOMMapper()
        self.reconstructor = VolumeReconstructor()
    }

    // MARK: - Single File Import

    /// Import a single DICOM file with complete processing
    /// - Parameter url: URL to DICOM file
    /// - Returns: Complete import result with all extracted data
    /// - Throws: DICOMError or VolumeReconstructionError if import fails
    func importFile(_ url: URL) async throws -> DICOMImportResult {
        print("📥 Importing DICOM file: \(url.lastPathComponent)")

        // 1. Parse DICOM file
        let dataset = try await parser.parse(url: url)
        print("✅ Parsed DICOM dataset")

        // 2. Extract pixel data
        let pixelData = try parser.extractPixelData(from: dataset)
        print("✅ Extracted pixel data: \(pixelData.rows)×\(pixelData.columns)×\(pixelData.bitsAllocated)bit")

        // 3. Map to domain models
        guard let hierarchy = await mapper.mapToHierarchy(from: dataset, pixelData: pixelData) else {
            throw DICOMImportError.mappingFailed
        }
        print("✅ Mapped to domain models")

        // 4. Create single-slice volume
        let volume = await reconstructor.createSingleSliceVolume(
            from: hierarchy.image,
            pixelData: pixelData,
            seriesUID: hierarchy.series.seriesInstanceUID
        )
        print("✅ Created volume: \(volume.dimensions)")

        return DICOMImportResult(
            patient: hierarchy.patient,
            study: hierarchy.study,
            series: hierarchy.series,
            images: [hierarchy.image],
            pixelData: [pixelData],
            volume: volume,
            sourceURL: url
        )
    }

    // MARK: - Series Import

    /// Import multiple DICOM files as a series and reconstruct 3D volume
    /// - Parameter urls: Array of DICOM file URLs in the same series
    /// - Returns: Complete import result with reconstructed 3D volume
    /// - Throws: DICOMError or VolumeReconstructionError if import fails
    func importSeries(_ urls: [URL]) async throws -> DICOMImportResult {
        guard !urls.isEmpty else {
            throw DICOMImportError.emptyFileList
        }

        print("📥 Importing DICOM series: \(urls.count) files")

        var allImages: [ImageInstance] = []
        var allPixelData: [ProcessedPixelData] = []
        var patient: Patient?
        var study: Study?
        var series: Series?

        // Import each file
        for (index, url) in urls.enumerated() {
            print("📄 Processing file \(index + 1)/\(urls.count): \(url.lastPathComponent)")

            // Parse and extract
            let dataset = try await parser.parse(url: url)
            let pixelData = try parser.extractPixelData(from: dataset)

            // Map to domain models
            guard let hierarchy = await mapper.mapToHierarchy(from: dataset, pixelData: pixelData) else {
                print("⚠️ Skipping file \(index + 1) - mapping failed")
                continue
            }

            // Store first patient/study/series as reference
            if patient == nil {
                patient = hierarchy.patient
                study = hierarchy.study
                series = hierarchy.series
            }

            // Validate all images belong to same series
            if let expectedSeriesUID = series?.seriesInstanceUID,
               hierarchy.series.seriesInstanceUID != expectedSeriesUID {
                print("⚠️ Warning: Image \(index + 1) belongs to different series")
            }

            allImages.append(hierarchy.image)
            allPixelData.append(pixelData)
        }

        guard let finalPatient = patient,
              let finalStudy = study,
              let finalSeries = series else {
            throw DICOMImportError.noValidImages
        }

        print("✅ Imported \(allImages.count) images")

        // Reconstruct 3D volume if we have multiple slices
        let volume: VolumeData
        if allImages.count > 1 {
            // Combine images and pixel data for reconstruction
            let imagesWithData = zip(allImages, allPixelData).map { ($0, $1) }
            volume = try await reconstructor.reconstructVolume(
                from: imagesWithData,
                seriesUID: finalSeries.seriesInstanceUID
            )
            print("✅ Reconstructed 3D volume: \(volume.dimensions)")
        } else {
            // Single slice volume
            volume = await reconstructor.createSingleSliceVolume(
                from: allImages[0],
                pixelData: allPixelData[0],
                seriesUID: finalSeries.seriesInstanceUID
            )
            print("✅ Created single-slice volume")
        }

        // Update series with actual image count
        let updatedSeries = Series(
            id: finalSeries.id,
            seriesInstanceUID: finalSeries.seriesInstanceUID,
            seriesNumber: finalSeries.seriesNumber,
            seriesDescription: finalSeries.seriesDescription,
            modality: finalSeries.modality,
            instanceCount: allImages.count,
            images: allImages
        )

        return DICOMImportResult(
            patient: finalPatient,
            study: finalStudy,
            series: updatedSeries,
            images: allImages,
            pixelData: allPixelData,
            volume: volume,
            sourceURL: urls.first
        )
    }

    // MARK: - Directory Import

    /// Import all DICOM files from a directory
    /// - Parameter directoryURL: URL to directory containing DICOM files
    /// - Returns: Array of import results, one per series found
    /// - Throws: DICOMImportError if directory access fails
    func importDirectory(_ directoryURL: URL) async throws -> [DICOMImportResult] {
        print("📁 Scanning directory: \(directoryURL.path)")

        // Find all .dcm files
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(
            at: directoryURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            throw DICOMImportError.directoryAccessFailed
        }

        var dicomFiles: [URL] = []
        for case let fileURL as URL in enumerator {
            if fileURL.pathExtension.lowercased() == "dcm" ||
               fileURL.pathExtension.lowercased() == "dicom" {
                dicomFiles.append(fileURL)
            }
        }

        guard !dicomFiles.isEmpty else {
            throw DICOMImportError.noDICOMFiles
        }

        print("📄 Found \(dicomFiles.count) DICOM files")

        // Group files by series
        let seriesGroups = try await groupFilesBySeries(dicomFiles)
        print("📦 Found \(seriesGroups.count) series")

        // Import each series
        var results: [DICOMImportResult] = []
        for (index, (seriesUID, files)) in seriesGroups.enumerated() {
            print("\n📊 Importing series \(index + 1)/\(seriesGroups.count): \(seriesUID)")
            do {
                let result = try await importSeries(files)
                results.append(result)
            } catch {
                print("⚠️ Failed to import series \(seriesUID): \(error)")
            }
        }

        print("\n✅ Successfully imported \(results.count) series")
        return results
    }

    // MARK: - Helper Methods

    /// Group DICOM files by series instance UID
    private func groupFilesBySeries(_ urls: [URL]) async throws -> [String: [URL]] {
        var seriesMap: [String: [URL]] = [:]

        for url in urls {
            do {
                let dataset = try await parser.parse(url: url)
                if let seriesUID = dataset.seriesInstanceUID {
                    seriesMap[seriesUID, default: []].append(url)
                } else {
                    print("⚠️ Skipping file without series UID: \(url.lastPathComponent)")
                }
            } catch {
                print("⚠️ Failed to parse \(url.lastPathComponent): \(error)")
            }
        }

        return seriesMap
    }
}

// MARK: - Import Result

/// Complete result of DICOM import with all extracted data
struct DICOMImportResult {
    let patient: Patient
    let study: Study
    let series: Series
    let images: [ImageInstance]
    let pixelData: [ProcessedPixelData]
    let volume: VolumeData
    let sourceURL: URL?

    /// Total memory used by pixel data
    var totalDataSize: Int {
        pixelData.reduce(0) { $0 + $1.dataSize }
    }

    /// Summary description
    var summary: String {
        """
        Patient: \(patient.name.formatted) (\(patient.patientID))
        Study: \(study.studyDescription ?? "Unknown") - \(study.studyInstanceUID)
        Series: \(series.seriesDescription ?? "Unknown") [\(series.modality.rawValue)]
        Images: \(images.count)
        Volume: \(volume.dimensions.x)×\(volume.dimensions.y)×\(volume.dimensions.z)
        Spacing: \(volume.spacing.x)×\(volume.spacing.y)×\(volume.spacing.z) mm
        Memory: \(String(format: "%.1f", Double(volume.memorySize) / 1_048_576)) MB
        """
    }
}

// MARK: - Errors

enum DICOMImportError: Error, LocalizedError {
    case emptyFileList
    case mappingFailed
    case noValidImages
    case directoryAccessFailed
    case noDICOMFiles

    var errorDescription: String? {
        switch self {
        case .emptyFileList:
            return "No DICOM files provided"
        case .mappingFailed:
            return "Failed to map DICOM data to domain models"
        case .noValidImages:
            return "No valid images could be imported"
        case .directoryAccessFailed:
            return "Failed to access directory"
        case .noDICOMFiles:
            return "No DICOM files found in directory"
        }
    }
}
