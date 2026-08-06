import AppKit
import Foundation
import SwiftUI

struct TerminalPluginCapabilities: OptionSet, Hashable, Sendable {
    let rawValue: Int

    static let hostSearch = Self(rawValue: 1 << 0)
    static let trackpadNavigation = Self(rawValue: 1 << 1)
    static let screenHistory = Self(rawValue: 1 << 2)
    static let smartSelection = Self(rawValue: 1 << 3)
    static let clipboard = Self(rawValue: 1 << 4)
    static let developerSplit = Self(rawValue: 1 << 5)
    static let personalization = Self(rawValue: 1 << 6)
}

enum AppAccentTheme: String, CaseIterable, Identifiable {
    static let storageKey = "Swift3270.appearance.accentTheme"

    case blue
    case pink
    case purple
    case green
    case orange
    case cyan

    var id: String { rawValue }

    var label: String {
        switch self {
        case .blue: "Blauw"
        case .pink: "Roze"
        case .purple: "Paars"
        case .green: "Groen"
        case .orange: "Oranje"
        case .cyan: "Cyaan"
        }
    }

    var accent: Color {
        switch self {
        case .blue: Color(red: 0.200, green: 0.560, blue: 1.000)
        case .pink: Color(red: 1.000, green: 0.310, blue: 0.680)
        case .purple: Color(red: 0.650, green: 0.420, blue: 1.000)
        case .green: Color(red: 0.200, green: 0.790, blue: 0.500)
        case .orange: Color(red: 1.000, green: 0.520, blue: 0.180)
        case .cyan: Color(red: 0.100, green: 0.780, blue: 0.900)
        }
    }

    static func color(forStoredValue value: String) -> Color {
        if let preset = AppAccentTheme(rawValue: value) {
            return preset.accent
        }
        return Color(nsColor: nsColor(forStoredValue: value))
    }

    static func hexValue(for color: Color) -> String {
        guard let rgb = NSColor(color).usingColorSpace(.sRGB) else {
            return blue.rawValue
        }
        return String(
            format: "#%02X%02X%02X",
            Int((rgb.redComponent * 255).rounded()),
            Int((rgb.greenComponent * 255).rounded()),
            Int((rgb.blueComponent * 255).rounded())
        )
    }

    static var currentAccent: Color {
        let saved = UserDefaults.standard.string(forKey: storageKey) ?? blue.rawValue
        return color(forStoredValue: saved)
    }

    static var currentContrastingText: Color {
        let saved = UserDefaults.standard.string(forKey: storageKey) ?? blue.rawValue
        let color = nsColor(forStoredValue: saved)
        let luminance = 0.2126 * color.redComponent
            + 0.7152 * color.greenComponent
            + 0.0722 * color.blueComponent
        return luminance > 0.62 ? .black : .white
    }

    private static func nsColor(forStoredValue value: String) -> NSColor {
        if let preset = AppAccentTheme(rawValue: value),
           let color = NSColor(preset.accent).usingColorSpace(.sRGB) {
            return color
        }

        let hex = value.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard hex.count == 6, let number = Int(hex, radix: 16) else {
            return NSColor(AppAccentTheme.blue.accent)
        }
        return NSColor(
            calibratedRed: CGFloat((number >> 16) & 0xff) / 255,
            green: CGFloat((number >> 8) & 0xff) / 255,
            blue: CGFloat(number & 0xff) / 255,
            alpha: 1
        )
    }

    var accentText: Color {
        switch self {
        case .blue: Color(red: 0.740, green: 0.900, blue: 1.000)
        case .pink: Color(red: 1.000, green: 0.790, blue: 0.910)
        case .purple: Color(red: 0.860, green: 0.790, blue: 1.000)
        case .green: Color(red: 0.730, green: 1.000, blue: 0.850)
        case .orange: Color(red: 1.000, green: 0.850, blue: 0.690)
        case .cyan: Color(red: 0.690, green: 0.960, blue: 1.000)
        }
    }

}

struct TerminalPlugin: Identifiable, Hashable {
    let id: String
    let name: String
    let summary: String
    let icon: String
    let version: String
    let capabilities: TerminalPluginCapabilities

    static let builtIns: [TerminalPlugin] = [
        TerminalPlugin(
            id: "host-search",
            name: "Host Search",
            summary: "Zoeken via de echte 3270 FIND-opdracht, inclusief vorige en volgende.",
            icon: "magnifyingglass",
            version: "1.0",
            capabilities: .hostSearch
        ),
        TerminalPlugin(
            id: "trackpad-navigation",
            name: "Trackpad Navigation",
            summary: "Twee vingers voor verticaal en horizontaal navigeren in de terminal.",
            icon: "hand.draw",
            version: "1.0",
            capabilities: .trackpadNavigation
        ),
        TerminalPlugin(
            id: "screen-history",
            name: "Screen History",
            summary: "Bekijk eerdere stabiele terminalschermen met Option en twee vingers.",
            icon: "clock.arrow.circlepath",
            version: "1.0",
            capabilities: .screenHistory
        ),
        TerminalPlugin(
            id: "smart-selection",
            name: "Smart Selection",
            summary: "Selecteer tekst door te slepen en woorden met dubbelklik.",
            icon: "selection.pin.in.out",
            version: "1.0",
            capabilities: .smartSelection
        ),
        TerminalPlugin(
            id: "clipboard",
            name: "Terminal Clipboard",
            summary: "Kopieer en plak terminalinhoud met de standaard macOS-sneltoetsen.",
            icon: "doc.on.clipboard",
            version: "1.0",
            capabilities: .clipboard
        ),
        TerminalPlugin(
            id: "developer-split",
            name: "Developer Split",
            summary: "Werk met twee geopende 3270-sessies naast elkaar in hetzelfde venster.",
            icon: "rectangle.split.2x1",
            version: "1.0",
            capabilities: .developerSplit
        ),
        TerminalPlugin(
            id: "personalize",
            name: "Personalize",
            summary: "Kies een eigen accentkleur voor knoppen, tabs en actieve onderdelen.",
            icon: "paintpalette.fill",
            version: "1.0",
            capabilities: .personalization
        )
    ]
}

@MainActor
final class TerminalPluginStore: ObservableObject {
    private static let enabledPluginIDsKey = "Swift3270.enabledTerminalPlugins.v1"
    private static let personalizeMigrationKey = "Swift3270.plugin.personalizeIntroduced"

    @Published private(set) var enabledPluginIDs: Set<String> {
        didSet {
            UserDefaults.standard.set(Array(enabledPluginIDs).sorted(), forKey: Self.enabledPluginIDsKey)
        }
    }

    let plugins = TerminalPlugin.builtIns

    init() {
        var initialIDs: Set<String>
        if let saved = UserDefaults.standard.array(forKey: Self.enabledPluginIDsKey) as? [String] {
            initialIDs = Set(saved)
        } else {
            initialIDs = Set(TerminalPlugin.builtIns.map(\.id))
        }

        if !UserDefaults.standard.bool(forKey: Self.personalizeMigrationKey) {
            initialIDs.insert("personalize")
            UserDefaults.standard.set(true, forKey: Self.personalizeMigrationKey)
        }
        enabledPluginIDs = initialIDs
    }

    var activeCapabilities: TerminalPluginCapabilities {
        plugins.reduce(into: TerminalPluginCapabilities()) { result, plugin in
            if enabledPluginIDs.contains(plugin.id) {
                result.formUnion(plugin.capabilities)
            }
        }
    }

    var enabledCount: Int {
        plugins.lazy.filter { self.enabledPluginIDs.contains($0.id) }.count
    }

    func isEnabled(_ plugin: TerminalPlugin) -> Bool {
        enabledPluginIDs.contains(plugin.id)
    }

    func isEnabled(capability: TerminalPluginCapabilities) -> Bool {
        activeCapabilities.contains(capability)
    }

    func setEnabled(_ enabled: Bool, plugin: TerminalPlugin) {
        if enabled {
            enabledPluginIDs.insert(plugin.id)
        } else {
            enabledPluginIDs.remove(plugin.id)
        }
    }

    func binding(for plugin: TerminalPlugin) -> Binding<Bool> {
        Binding(
            get: { self.isEnabled(plugin) },
            set: { self.setEnabled($0, plugin: plugin) }
        )
    }

    func enableAll() {
        enabledPluginIDs = Set(plugins.map(\.id))
    }
}
