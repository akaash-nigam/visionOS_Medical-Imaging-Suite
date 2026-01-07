//
//  DICOMMapper.swift
//  MedicalImagingSuite
//
//  Created by Claude on 2025-11-24.
//

import Foundation

/// Maps DICOM datasets to domain models (Patient, Study, Series, etc.)
actor DICOMMapper {

    // MARK: - Patient Mapping

    /// Extract patient information from DICOM dataset
    /// - Parameter dataset: Parsed DICOM dataset
    /// - Returns: Patient domain model or nil if required fields are missing
    func mapToPatient(from dataset: DICOMDataset) -> Patient? {
        // Patient ID is required
        guard let patientID = dataset.patientID else {
            return nil
        }

        // Patient Name (parse DICOM format: Family^Given^Middle^Prefix^Suffix)
        let personName: PersonName
        if let nameString = dataset.patientName {
            personName = PersonName.from(dicomString: nameString)
        } else {
            // Use default name if not provided
            personName = PersonName(familyName: "Unknown", givenName: "Patient")
        }

        // Birth Date
        let birthDate = dataset.date(for: .patientBirthDate)

        // Sex
        let sexString = dataset.string(for: .patientSex) ?? "U"
        let sex = Sex(rawValue: sexString) ?? .unknown

        // Patient Age (optional)
        let ageString = dataset.string(for: .patientAge)
        let age = parsePatientAge(ageString)

        // Patient Weight (optional, in kg)
        let weight = dataset.float(for: .patientWeight)

        return Patient(
            patientID: patientID,
            name: personName,
            birthDate: birthDate,
            sex: sex
        )
    }

    // MARK: - Study Mapping

    /// Extract study information from DICOM dataset
    /// - Parameters:
    ///   - dataset: Parsed DICOM dataset
    ///   - patient: Associated patient
    /// - Returns: Study domain model or nil if required fields are missing
    func mapToStudy(from dataset: DICOMDataset, patient: Patient) -> Study? {
        // Study Instance UID is required
        guard let studyInstanceUID = dataset.studyInstanceUID else {
            return nil
        }

        // Study Date
        let studyDate = dataset.studyDate ?? Date()

        // Study Description
        let studyDescription = dataset.studyDescription ?? "Unknown Study"

        // Accession Number
        let accessionNumber = dataset.string(for: .accessionNumber)

        // Modality
        let modalityString = dataset.modality ?? "OT"
        let modality = Modality(rawValue: modalityString) ?? .other

        return Study(
            studyInstanceUID: studyInstanceUID,
            studyDate: studyDate,
            studyDescription: studyDescription,
            accessionNumber: accessionNumber,
            modalities: [modality],
            patient: patient,
            series: []  // Series will be added separately
        )
    }

    // MARK: - Series Mapping

    /// Extract series information from DICOM dataset
    /// - Parameter dataset: Parsed DICOM dataset
    /// - Returns: Series domain model or nil if required fields are missing
    func mapToSeries(from dataset: DICOMDataset) -> Series? {
        // Series Instance UID is required
        guard let seriesInstanceUID = dataset.seriesInstanceUID else {
            return nil
        }

        // Series Number
        let seriesNumber = dataset.int(for: .seriesNumber) ?? 0

        // Series Description
        let seriesDescription = dataset.seriesDescription ?? "Unknown Series"

        // Modality
        let modalityString = dataset.modality ?? "OT"
        let modality = Modality(rawValue: modalityString) ?? .other

        // Instance Count (will be updated as images are added)
        let instanceCount = 0

        return Series(
            seriesInstanceUID: seriesInstanceUID,
            seriesNumber: seriesNumber,
            seriesDescription: seriesDescription,
            modality: modality,
            instanceCount: instanceCount,
            images: []  // Images will be added separately
        )
    }

    // MARK: - Image Instance Mapping

    /// Extract image instance information from DICOM dataset
    /// - Parameters:
    ///   - dataset: Parsed DICOM dataset
    ///   - pixelData: Processed pixel data
    /// - Returns: ImageInstance domain model or nil if required fields are missing
    func mapToImageInstance(
        from dataset: DICOMDataset,
        pixelData: ProcessedPixelData
    ) -> ImageInstance? {
        // SOP Instance UID is required
        guard let sopInstanceUID = dataset.string(for: .sopInstanceUID) else {
            return nil
        }

        // Instance Number
        let instanceNumber = dataset.int(for: .instanceNumber)

        // Image Position (x, y, z coordinates in mm)
        let imagePosition = parseImagePosition(dataset.string(for: .imagePositionPatient))

        // Image Orientation (direction cosines)
        let imageOrientation = parseImageOrientation(dataset.string(for: .imageOrientationPatient))

        // Slice Location
        let sliceLocation = dataset.float(for: .sliceLocation)

        return ImageInstance(
            sopInstanceUID: sopInstanceUID,
            instanceNumber: instanceNumber,
            dimensions: SIMD2<Int>(pixelData.columns, pixelData.rows),
            pixelSpacing: pixelData.pixelSpacing,
            imagePosition: imagePosition,
            imageOrientation: imageOrientation,
            sliceLocation: sliceLocation,
            windowCenter: pixelData.windowCenter,
            windowWidth: pixelData.windowWidth
        )
    }

    // MARK: - Complete Hierarchy Mapping

    /// Map DICOM dataset to complete Patient → Study → Series → Image hierarchy
    /// - Parameters:
    ///   - dataset: Parsed DICOM dataset
    ///   - pixelData: Processed pixel data
    /// - Returns: Tuple containing (Patient, Study, Series, ImageInstance) or nil if mapping fails
    func mapToHierarchy(
        from dataset: DICOMDataset,
        pixelData: ProcessedPixelData
    ) -> (patient: Patient, study: Study, series: Series, image: ImageInstance)? {
        // Map patient
        guard let patient = mapToPatient(from: dataset) else {
            print("⚠️ Failed to map patient from DICOM")
            return nil
        }

        // Map study
        guard let study = mapToStudy(from: dataset, patient: patient) else {
            print("⚠️ Failed to map study from DICOM")
            return nil
        }

        // Map series
        guard let series = mapToSeries(from: dataset) else {
            print("⚠️ Failed to map series from DICOM")
            return nil
        }

        // Map image instance
        guard let image = mapToImageInstance(from: dataset, pixelData: pixelData) else {
            print("⚠️ Failed to map image instance from DICOM")
            return nil
        }

        return (patient, study, series, image)
    }

    // MARK: - Helper Methods

    /// Parse patient age string (format: "045Y", "012M", "007D", "002W")
    private func parsePatientAge(_ ageString: String?) -> Int? {
        guard let ageString = ageString, ageString.count >= 4 else {
            return nil
        }

        let numberPart = String(ageString.prefix(3))
        let unit = ageString.suffix(1)

        guard let value = Int(numberPart) else {
            return nil
        }

        switch unit {
        case "Y": // Years
            return value
        case "M": // Months
            return value / 12
        case "W": // Weeks
            return value / 52
        case "D": // Days
            return value / 365
        default:
            return nil
        }
    }

    /// Parse image position patient (x\y\z format in mm)
    private func parseImagePosition(_ positionString: String?) -> SIMD3<Float>? {
        guard let positionString = positionString else {
            return nil
        }

        let components = positionString.split(separator: "\\").compactMap { Float($0) }
        guard components.count == 3 else {
            return nil
        }

        return SIMD3<Float>(components[0], components[1], components[2])
    }

    /// Parse image orientation patient (6 direction cosines: row_x\row_y\row_z\col_x\col_y\col_z)
    private func parseImageOrientation(_ orientationString: String?) -> [Float]? {
        guard let orientationString = orientationString else {
            return nil
        }

        let components = orientationString.split(separator: "\\").compactMap { Float($0) }
        guard components.count == 6 else {
            return nil
        }

        return components
    }
}
