import AppKit
import Foundation

@MainActor
final class UpdateChecker: ObservableObject {
    @Published var availableUpdate: AppUpdate?

    private let releasesURL = URL(string: "https://api.github.com/repos/prosir/Swift3270/releases/latest")!
    private let currentVersion: AppVersion

    init(currentVersion: AppVersion = .current) {
        self.currentVersion = currentVersion
    }

    func checkForUpdates() async {
        var request = URLRequest(url: releasesURL)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("Swift3270", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200..<300).contains(httpResponse.statusCode) else {
                return
            }

            let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
            guard let latestVersion = AppVersion(release.tagName),
                  latestVersion > currentVersion else {
                return
            }

            availableUpdate = AppUpdate(
                version: release.tagName,
                title: release.name.isEmpty ? release.tagName : release.name,
                changelog: release.body.trimmingCharacters(in: .whitespacesAndNewlines),
                url: release.htmlURL
            )
        } catch {
            return
        }
    }
}

struct AppUpdate: Identifiable {
    let id = UUID()
    let version: String
    let title: String
    let changelog: String
    let url: URL
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
            .trimmingPrefix("v")

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
    let name: String
    let body: String
    let htmlURL: URL

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name
        case body
        case htmlURL = "html_url"
    }
}

private extension String {
    func trimmingPrefix(_ prefix: String) -> String {
        hasPrefix(prefix) ? String(dropFirst(prefix.count)) : self
    }
}
