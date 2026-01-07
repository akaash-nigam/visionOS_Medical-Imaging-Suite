//
//  AppSettings.swift
//  MedicalImagingSuite
//
//  Centralized app settings and user preferences
//

import Foundation
import SwiftUI

// MARK: - App Settings

/// Centralized settings manager
@MainActor
final class AppSettings: ObservableObject {

    // MARK: - Storage Settings

    @AppStorage("cacheRetentionDays") var cacheRetentionDays: Int = 7
    @AppStorage("cacheSizeLimitGB") var cacheSizeLimitGB: Int = 5
    @AppStorage("autoEvictCache") var autoEvictCache: Bool = true

    // MARK: - Display Settings

    @AppStorage("defaultWindowingPreset") var defaultWindowingPreset: String = "softTissue"
    @AppStorage("defaultTransferFunction") var defaultTransferFunction: String = "grayscale"
    @AppStorage("defaultRenderMode") var defaultRenderMode: String = "dvr"
    @AppStorage("renderQuality") var renderQuality: String = "high"

    // MARK: - Measurement Settings

    @AppStorage("measurementUnit") var measurementUnit: String = "mm"
    @AppStorage("angleUnit") var angleUnit: String = "degrees"
    @AppStorage("showMeasurementLabels") var showMeasurementLabels: Bool = true
    @AppStorage("measurementPrecision") var measurementPrecision: Int = 2

    // MARK: - Annotation Settings

    @AppStorage("defaultAnnotationColor") var defaultAnnotationColor: String = "yellow"
    @AppStorage("annotationLineWidth") var annotationLineWidth: Double = 2.0
    @AppStorage("annotationOpacity") var annotationOpacity: Double = 1.0
    @AppStorage("autoSaveAnnotations") var autoSaveAnnotations: Bool = true

    // MARK: - Security Settings

    @AppStorage("requireAuthentication") var requireAuthentication: Bool = true
    @AppStorage("sessionTimeoutMinutes") var sessionTimeoutMinutes: Int = 15
    @AppStorage("lockOnBackground") var lockOnBackground: Bool = true
    @AppStorage("enableAuditLogging") var enableAuditLogging: Bool = true

    // MARK: - Import Settings

    @AppStorage("autoImportMetadata") var autoImportMetadata: Bool = true
    @AppStorage("generateThumbnails") var generateThumbnails: Bool = true
    @AppStorage("validateDICOMOnImport") var validateDICOMOnImport: Bool = true

    // MARK: - UI Settings

    @AppStorage("showPatientInfo") var showPatientInfo: Bool = true
    @AppStorage("showStudyInfo") var showStudyInfo: Bool = true
    @AppStorage("showTechnicalInfo") var showTechnicalInfo: Bool = false
    @AppStorage("uiScale") var uiScale: Double = 1.0

    // MARK: - Methods

    func resetToDefaults() {
        cacheRetentionDays = 7
        cacheSizeLimitGB = 5
        autoEvictCache = true

        defaultWindowingPreset = "softTissue"
        defaultTransferFunction = "grayscale"
        defaultRenderMode = "dvr"
        renderQuality = "high"

        measurementUnit = "mm"
        angleUnit = "degrees"
        showMeasurementLabels = true
        measurementPrecision = 2

        defaultAnnotationColor = "yellow"
        annotationLineWidth = 2.0
        annotationOpacity = 1.0
        autoSaveAnnotations = true

        requireAuthentication = true
        sessionTimeoutMinutes = 15
        lockOnBackground = true
        enableAuditLogging = true

        autoImportMetadata = true
        generateThumbnails = true
        validateDICOMOnImport = true

        showPatientInfo = true
        showStudyInfo = true
        showTechnicalInfo = false
        uiScale = 1.0

        print("✅ Settings reset to defaults")
    }

    func exportSettings() -> String {
        let settings: [String: Any] = [
            "cacheRetentionDays": cacheRetentionDays,
            "cacheSizeLimitGB": cacheSizeLimitGB,
            "defaultWindowingPreset": defaultWindowingPreset,
            "measurementUnit": measurementUnit,
            "sessionTimeoutMinutes": sessionTimeoutMinutes,
            "renderQuality": renderQuality
        ]

        guard let data = try? JSONSerialization.data(withJSONObject: settings, options: .prettyPrinted),
              let json = String(data: data, encoding: .utf8) else {
            return "{}"
        }

        return json
    }
}

// MARK: - Windowing Preset Helpers

extension AppSettings {
    var windowingPreset: WindowingPreset {
        WindowingPreset(rawValue: defaultWindowingPreset.capitalized) ?? .softTissue
    }

    func setWindowingPreset(_ preset: WindowingPreset) {
        defaultWindowingPreset = preset.rawValue.lowercased()
    }
}

// MARK: - Render Quality

enum RenderQuality: String, CaseIterable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
    case ultra = "Ultra"

    var stepSize: Float {
        switch self {
        case .low: return 0.02
        case .medium: return 0.01
        case .high: return 0.005
        case .ultra: return 0.002
        }
    }

    var maxSteps: Int {
        switch self {
        case .low: return 500
        case .medium: return 1000
        case .high: return 2000
        case .ultra: return 5000
        }
    }
}
