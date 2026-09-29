// swift-tools-version: 6.2

import PackageDescription
import Foundation

// `swift test` builds more than only the selected test target on Windows. In
// CI that would pull in the complete WinUI/CWinRT graph just to test the
// platform-independent core. Core-only mode removes the app target and its
// external packages. The workflow preserves Package.resolved around this run.
let coreOnly = ProcessInfo.processInfo.environment["SWIFT3270_CORE_ONLY"] == "1"

var products: [Product] = [
    .library(name: "Swift3270WindowsCore", targets: ["Swift3270WindowsCore"])
]
let dependencies: [Package.Dependency] = coreOnly
    ? []
    : [
        .package(url: "https://github.com/moreSwift/swift-cross-ui.git", exact: "0.9.0"),
        // SwiftCrossUI 0.9 currently shares this dependency range.
        .package(url: "https://github.com/swiftlang/swift-subprocess.git", exact: "0.4.0"),
        // FilePath is part of SystemPackage and is used by Executable.path.
        .package(url: "https://github.com/apple/swift-system.git", from: "1.5.0")
    ]
var targets: [Target] = [
    .target(name: "Swift3270WindowsCore"),
    .testTarget(
        name: "Swift3270WindowsCoreTests",
        dependencies: ["Swift3270WindowsCore"]
    )
]

#if os(Windows)
if !coreOnly {
    products.insert(.executable(name: "Swift3270Windows", targets: ["Swift3270Windows"]), at: 0)
    targets.insert(
        .executableTarget(
            name: "Swift3270Windows",
            dependencies: [
                "Swift3270WindowsCore",
                .product(name: "SwiftCrossUI", package: "swift-cross-ui"),
                .product(name: "WinUIBackend", package: "swift-cross-ui"),
                .product(name: "Subprocess", package: "swift-subprocess"),
                .product(name: "SystemPackage", package: "swift-system")
            ]
        ),
        at: 1
    )
}
#endif

let package = Package(
    name: "Swift3270Windows",
    platforms: [.macOS(.v13)],
    products: products,
    dependencies: dependencies,
    targets: targets
)
