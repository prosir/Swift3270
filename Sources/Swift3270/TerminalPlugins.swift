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
        )
    ]
}

@MainActor
final class TerminalPluginStore: ObservableObject {
    private static let enabledPluginIDsKey = "Swift3270.enabledTerminalPlugins.v1"

    @Published private(set) var enabledPluginIDs: Set<String> {
        didSet {
            UserDefaults.standard.set(Array(enabledPluginIDs).sorted(), forKey: Self.enabledPluginIDsKey)
        }
    }

    let plugins = TerminalPlugin.builtIns

    init() {
        if let saved = UserDefaults.standard.array(forKey: Self.enabledPluginIDsKey) as? [String] {
            enabledPluginIDs = Set(saved)
        } else {
            enabledPluginIDs = Set(TerminalPlugin.builtIns.map(\.id))
        }
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
