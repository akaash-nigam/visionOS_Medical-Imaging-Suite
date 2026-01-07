// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Medical-Imaging-Suite",
    platforms: [
        .visionOS(.v1)
    ],
    products: [
        .executable(
            name: "Medical-Imaging-Suite",
            targets: ["Medical-Imaging-Suite"]
        )
    ],
    dependencies: [
    ],
    targets: [
        .executableTarget(
            name: "Medical-Imaging-Suite",
            path: "MedicalImagingSuite"
        )
    ]
)
