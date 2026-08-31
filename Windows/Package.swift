// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "Swift3270Windows",
    products: [
        .executable(name: "Swift3270Windows", targets: ["Swift3270Windows"]),
        .library(name: "Swift3270WindowsCore", targets: ["Swift3270WindowsCore"])
    ],
    dependencies: [
        .package(url: "https://github.com/moreSwift/swift-cross-ui.git", exact: "0.9.0"),
        // SwiftCrossUI 0.9 currently shares this dependency range.
        .package(url: "https://github.com/swiftlang/swift-subprocess.git", exact: "0.4.0")
    ],
    targets: [
        .target(name: "Swift3270WindowsCore"),
        .executableTarget(
            name: "Swift3270Windows",
            dependencies: [
                "Swift3270WindowsCore",
                .product(name: "SwiftCrossUI", package: "swift-cross-ui"),
                .product(name: "DefaultBackend", package: "swift-cross-ui"),
                .product(name: "Subprocess", package: "swift-subprocess")
            ]
        ),
        .testTarget(
            name: "Swift3270WindowsCoreTests",
            dependencies: ["Swift3270WindowsCore"]
        )
    ]
)
