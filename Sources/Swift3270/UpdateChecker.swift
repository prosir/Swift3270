import AppKit
import CryptoKit
import Foundation

@MainActor
final class UpdateChecker: ObservableObject {
    @Published var availableUpdate: AppUpdate?
    @Published private(set) var installProgress = 0.0
    @Published private(set) var installStatus = ""
    @Published private(set) var installError: String?

    private let releasesURL = URL(string: "https://api.github.com/repos/prosir/Swift3270/releases")!
    private let currentVersion: AppVersion

    init(currentVersion: AppVersion = .current) {
        self.currentVersion = currentVersion
    }

    func checkForUpdates() async {
        availableUpdate = await latestReleaseUpdate()
    }

    func install(_ update: AppUpdate) async {
        guard let downloadURL = update.downloadURL,
              let checksumURL = update.checksumURL else {
            installError = "Deze GitHub Release bevat nog geen Swift3270-macOS.zip en checksum."
            return
        }

        installError = nil
        installProgress = 0.08
        installStatus = "Update downloaden…"

        do {
            async let archiveRequest = URLSession.shared.data(from: downloadURL)
            async let checksumRequest = URLSession.shared.data(from: checksumURL)
            let ((archive, archiveResponse), (checksumData, checksumResponse)) = try await (archiveRequest, checksumRequest)
            try Self.validateHTTPResponse(archiveResponse)
            try Self.validateHTTPResponse(checksumResponse)

            installProgress = 0.55
            installStatus = "Download controleren…"
            let expectedChecksum = String(decoding: checksumData, as: UTF8.self)
                .split(whereSeparator: { $0.isWhitespace })
                .first
                .map(String.init)?
                .lowercased()
            let actualChecksum = SHA256.hash(data: archive)
                .map { String(format: "%02x", $0) }
                .joined()
            guard expectedChecksum == actualChecksum else {
                throw UpdateInstallError.invalidChecksum
            }

            let stagingDirectory = FileManager.default.temporaryDirectory
                .appendingPathComponent("Swift3270-update-\(UUID().uuidString)", isDirectory: true)
            try FileManager.default.createDirectory(at: stagingDirectory, withIntermediateDirectories: true)
            let archiveURL = stagingDirectory.appendingPathComponent("Swift3270-macOS.zip")
            try archive.write(to: archiveURL, options: .atomic)

            installProgress = 0.70
            installStatus = "Update uitpakken…"
            try await Self.run("/usr/bin/ditto", arguments: ["-x", "-k", archiveURL.path, stagingDirectory.path])

            let stagedApp = stagingDirectory.appendingPathComponent("Swift3270.app", isDirectory: true)
            try Self.validateStagedApp(at: stagedApp, expectedVersion: update.version)

            let currentApp = Bundle.main.bundleURL
            guard currentApp.pathExtension == "app" else {
                throw UpdateInstallError.notRunningFromAppBundle
            }
            guard FileManager.default.isWritableFile(atPath: currentApp.deletingLastPathComponent().path) else {
                throw UpdateInstallError.applicationFolderNotWritable
            }

            installProgress = 0.94
            installStatus = "Swift3270 opnieuw starten…"
            try Self.launchReplacementHelper(currentApp: currentApp, stagedApp: stagedApp)
            installProgress = 1
            NSApplication.shared.terminate(nil)
        } catch {
            installStatus = "Update mislukt"
            installError = error.localizedDescription
        }
    }

    private func latestReleaseUpdate() async -> AppUpdate? {
        do {
            let releases = try await fetch([GitHubRelease].self, from: releasesURL)
            return releases
                .filter { !$0.draft }
                .compactMap { release -> (version: AppVersion, update: AppUpdate)? in
                    guard let version = AppVersion(release.tagName), version > currentVersion else { return nil }
                    return (
                        version,
                        AppUpdate(
                            version: release.tagName,
                            title: release.displayName,
                            changelog: release.displayBody,
                            url: release.htmlURL,
                            downloadURL: release.asset(named: "Swift3270-macOS.zip"),
                            checksumURL: release.asset(named: "Swift3270-macOS.zip.sha256")
                        )
                    )
                }
                .max { $0.version < $1.version }?
                .update
        } catch {
            return nil
        }
    }

    private func fetch<T: Decodable>(_ type: T.Type, from url: URL) async throws -> T {
        var request = URLRequest(url: url)
        request.timeoutInterval = 4
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("Swift3270", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }

        return try JSONDecoder().decode(T.self, from: data)
    }

    private static func validateHTTPResponse(_ response: URLResponse) throws {
        guard let response = response as? HTTPURLResponse,
              (200..<300).contains(response.statusCode) else {
            throw UpdateInstallError.downloadFailed
        }
    }

    private static func validateStagedApp(at url: URL, expectedVersion: String) throws {
        guard let bundle = Bundle(url: url),
              bundle.bundleIdentifier == "com.swift3270.app",
              let executableURL = bundle.executableURL,
              FileManager.default.isExecutableFile(atPath: executableURL.path) else {
            throw UpdateInstallError.invalidApplication
        }

        let stagedVersionText = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        guard let stagedVersion = AppVersion(stagedVersionText),
              let releaseVersion = AppVersion(expectedVersion),
              stagedVersion == releaseVersion else {
            throw UpdateInstallError.versionMismatch
        }
    }

    private static func run(_ executable: String, arguments: [String]) async throws {
        try await Task.detached {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = arguments
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else {
                throw UpdateInstallError.unpackFailed
            }
        }.value
    }

    private static func launchReplacementHelper(currentApp: URL, stagedApp: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = [
            "-c",
            """
            while kill -0 "$1" 2>/dev/null; do sleep 0.2; done
            backup="$2.swift3270-backup"
            rm -rf "$backup"
            if mv "$2" "$backup" && mv "$3" "$2"; then
                open "$2"
                rm -rf "$backup"
            else
                if [ ! -e "$2" ] && [ -e "$backup" ]; then mv "$backup" "$2"; fi
                open "$2"
            fi
            """,
            "swift3270-updater",
            String(ProcessInfo.processInfo.processIdentifier),
            currentApp.path,
            stagedApp.path
        ]
        try process.run()
    }
}

struct AppUpdate: Identifiable {
    let id = UUID()
    let version: String
    let title: String
    let changelog: String
    let url: URL
    let downloadURL: URL?
    let checksumURL: URL?

    var canInstall: Bool {
        downloadURL != nil && checksumURL != nil
    }
}

struct AppVersion: Comparable {
    let components: [Int]

    static var current: AppVersion {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        return AppVersion(version ?? "0.1.1") ?? AppVersion(components: [0, 1, 1])
    }

    init?(_ text: String) {
        let normalized = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingVersionPrefix()

        let parts = normalized.split(separator: ".")
        guard !parts.isEmpty else { return nil }

        let parsed = parts.compactMap { part -> Int? in
            let numericPrefix = part.prefix { $0.isNumber }
            return numericPrefix.isEmpty ? nil : Int(numericPrefix)
        }

        guard parsed.count == parts.count else { return nil }
        components = parsed
    }

    private init(components: [Int]) {
        self.components = components
    }

    static func < (lhs: AppVersion, rhs: AppVersion) -> Bool {
        let count = max(lhs.components.count, rhs.components.count)
        for index in 0..<count {
            let left = index < lhs.components.count ? lhs.components[index] : 0
            let right = index < rhs.components.count ? rhs.components[index] : 0
            if left != right {
                return left < right
            }
        }
        return false
    }
}

private struct GitHubRelease: Decodable {
    let tagName: String
    let name: String?
    let body: String?
    let htmlURL: URL
    let draft: Bool
    let assets: [GitHubAsset]

    var displayName: String {
        let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? tagName : trimmed
    }

    var displayBody: String {
        body?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    func asset(named name: String) -> URL? {
        assets.first { $0.name == name }?.downloadURL
    }

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name
        case body
        case htmlURL = "html_url"
        case draft
        case assets
    }
}

private struct GitHubAsset: Decodable {
    let name: String
    let downloadURL: URL

    enum CodingKeys: String, CodingKey {
        case name
        case downloadURL = "browser_download_url"
    }
}

private extension String {
    func trimmingVersionPrefix() -> String {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.lowercased().hasPrefix("v") ? String(trimmed.dropFirst()) : trimmed
    }
}

private enum UpdateInstallError: LocalizedError {
    case downloadFailed
    case invalidChecksum
    case unpackFailed
    case invalidApplication
    case versionMismatch
    case notRunningFromAppBundle
    case applicationFolderNotWritable

    var errorDescription: String? {
        switch self {
        case .downloadFailed: "Het updatepakket kon niet van GitHub worden gedownload."
        case .invalidChecksum: "De checksum van het updatepakket klopt niet. De update is niet geïnstalleerd."
        case .unpackFailed: "Het updatepakket kon niet worden uitgepakt."
        case .invalidApplication: "Het pakket bevat geen geldige Swift3270-app."
        case .versionMismatch: "De versie in het pakket komt niet overeen met de GitHub Release."
        case .notRunningFromAppBundle: "Start Swift3270.app om automatische updates te installeren."
        case .applicationFolderNotWritable: "Swift3270 kan zichzelf in deze map niet vervangen. Verplaats de app naar een schrijfbare map of installeer de update handmatig."
        }
    }
}
