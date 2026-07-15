import AppKit
import Foundation

@MainActor
final class UpdateChecker: ObservableObject {
    @Published var availableUpdate: AppUpdate?

    private let releasesURL = URL(string: "https://api.github.com/repos/prosir/Swift3270/releases")!
    private let tagsURL = URL(string: "https://api.github.com/repos/prosir/Swift3270/tags")!
    private let currentVersion: AppVersion

    init(currentVersion: AppVersion = .current) {
        self.currentVersion = currentVersion
    }

    func checkForUpdates() async {
        if let release = await latestReleaseUpdate() {
            availableUpdate = release
            return
        }

        availableUpdate = await latestTagUpdate()
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
                            url: release.htmlURL
                        )
                    )
                }
                .max { $0.version < $1.version }?
                .update
        } catch {
            return nil
        }
    }

    private func latestTagUpdate() async -> AppUpdate? {
        do {
            let tags = try await fetch([GitHubTag].self, from: tagsURL)
            return tags
                .compactMap { tag -> (version: AppVersion, update: AppUpdate)? in
                    guard let version = AppVersion(tag.name), version > currentVersion else { return nil }
                    return (
                        version,
                        AppUpdate(
                            version: tag.name,
                            title: tag.name,
                            changelog: "Er staat een nieuwere tag op GitHub, maar er zijn geen release notes gevonden. Maak een GitHub Release aan voor deze tag om hier de changelog te tonen.",
                            url: URL(string: "https://github.com/prosir/Swift3270/releases/tag/\(tag.name)")!
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
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("Swift3270", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }

        return try JSONDecoder().decode(T.self, from: data)
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

    var displayName: String {
        let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? tagName : trimmed
    }

    var displayBody: String {
        body?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name
        case body
        case htmlURL = "html_url"
        case draft
    }
}

private struct GitHubTag: Decodable {
    let name: String
}

private extension String {
    func trimmingVersionPrefix() -> String {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.lowercased().hasPrefix("v") ? String(trimmed.dropFirst()) : trimmed
    }
}
