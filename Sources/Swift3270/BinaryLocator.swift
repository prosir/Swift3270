import Foundation

enum BinaryLocator {
    static let b3270Candidates = [
        "/opt/homebrew/bin/b3270",
        "/usr/local/bin/b3270",
        "/opt/local/bin/b3270",
        "/usr/bin/b3270"
    ]

    static func findB3270() -> URL? {
        if let configured = ProcessInfo.processInfo.environment["SWIFT3270_B3270_PATH"],
           FileManager.default.isExecutableFile(atPath: configured) {
            return URL(fileURLWithPath: configured)
        }

        if let candidate = b3270Candidates.first(where: FileManager.default.isExecutableFile(atPath:)) {
            return URL(fileURLWithPath: candidate)
        }

        return findInPath("b3270")
    }

    static var b3270StatusText: String {
        findB3270()?.path ?? "b3270 niet gevonden"
    }

    static var engineStatusText: String {
        if let b3270 = findB3270() {
            return "b3270 klaar: \(b3270.path)"
        }

        return "geen b3270 backend gevonden"
    }

    private static func findInPath(_ executable: String) -> URL? {
        let pathValue = ProcessInfo.processInfo.environment["PATH"] ?? ""
        for directory in pathValue.split(separator: ":") {
            let path = "\(directory)/\(executable)"
            if FileManager.default.isExecutableFile(atPath: path) {
                return URL(fileURLWithPath: path)
            }
        }

        return nil
    }
}
