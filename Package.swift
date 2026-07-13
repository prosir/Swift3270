// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "Swift3270",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "Swift3270", targets: ["Swift3270"])
    ],
    targets: [
        .executableTarget(name: "Swift3270")
    ]
)
