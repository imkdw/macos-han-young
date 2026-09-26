// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "crd-ime-toggle",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "crd-ime-toggle", targets: ["crd-ime-toggle"]),
        .executable(name: "keylog", targets: ["keylog"]),
    ],
    targets: [
        .target(name: "CRDIMECore"),
        .executableTarget(name: "crd-ime-toggle", dependencies: ["CRDIMECore"]),
        .executableTarget(name: "keylog"),
        .testTarget(name: "CRDIMECoreTests", dependencies: ["CRDIMECore"]),
    ]
)
