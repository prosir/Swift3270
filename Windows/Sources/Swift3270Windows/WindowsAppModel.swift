import Foundation
import SwiftCrossUI
import Swift3270WindowsCore

enum TerminalModel: Int, CaseIterable, CustomStringConvertible, Sendable {
    case model2 = 2
    case model3 = 3
    case model4 = 4
    case model5 = 5

    var description: String {
        switch self {
        case .model2: "Model 2 · 24x80"
        case .model3: "Model 3 · 32x80"
        case .model4: "Model 4 · 43x80"
        case .model5: "Model 5 · 27x132"
        }
    }
}

@MainActor
@ObservableObject
final class WindowsAppModel {
    var host = ""
    var port = "23"
    var luName = ""
    var useTLS = false
    var selectedModel: TerminalModel? = .model4
    var oversize = ""
    var executable = "ws3270.exe"
    var commandText = ""
    var statusText = "Niet verbonden"
    var connected = false
    var insertMode = false
    var screen = TerminalScreen(rows: 43, columns: 80)

    @ObservationIgnored private let backend = WS3270Backend()

    init() {
        let defaults = UserDefaults.standard
        host = defaults.string(forKey: "windows.host") ?? ""
        port = defaults.string(forKey: "windows.port") ?? "23"
        luName = defaults.string(forKey: "windows.lu") ?? ""
        useTLS = defaults.bool(forKey: "windows.tls")
        executable = defaults.string(forKey: "windows.ws3270") ?? "ws3270.exe"
        oversize = defaults.string(forKey: "windows.oversize") ?? ""
        if let storedModel = defaults.object(forKey: "windows.model") as? Int {
            selectedModel = TerminalModel(rawValue: storedModel) ?? .model4
        }
    }

    func connect() {
        let trimmedHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedHost.isEmpty, let parsedPort = Int(port), (1...65_535).contains(parsedPort) else {
            statusText = "Vul een geldige host en poort in"
            return
        }

        savePreferences()
        let model = selectedModel ?? .model4
        let hostSpec = HostSpec(host: trimmedHost, port: parsedPort, useTLS: useTLS, luName: luName)
        statusText = "Verbinden met \(trimmedHost)…"

        Task {
            if !(await backend.isRunning) {
                await backend.start(
                    configuration: .init(
                        executable: executable,
                        model: model.rawValue,
                        oversize: oversize.trimmingCharacters(in: .whitespacesAndNewlines)
                    )
                ) { [weak self] event in
                    Task { @MainActor in
                        self?.handle(event)
                    }
                }
            }
            await backend.sendAndRefresh("Connect(\(hostSpec.ws3270Target))")
        }
    }

    func disconnect() {
        Task { await backend.sendAndRefresh("Disconnect") }
    }

    func closeEngine() {
        Task { await backend.stop() }
    }

    func send(_ action: String) {
        Task { await backend.sendAndRefresh(action) }
    }

    func typeCharacter(_ character: Character) {
        Task { await backend.send(WS3270Action.string(String(character))) }
    }

    func sendCommandText() {
        let value = commandText
        guard !value.isEmpty else {
            send("Enter")
            return
        }
        commandText = ""
        Task {
            await backend.send(WS3270Action.string(value))
            await backend.sendAndRefresh("Enter")
        }
    }

    func toggleInsert() {
        insertMode.toggle()
        send("ToggleInsert")
    }

    private func handle(_ event: WS3270Event) {
        switch event {
        case .response(let command, let response):
            if let status = response.status {
                connected = status.connected
                switch status.keyboard {
                case .unlocked:
                    statusText = status.connected ? "Verbonden · gereed" : "Niet verbonden"
                case .locked:
                    statusText = status.connected ? "Host verwerkt opdracht…" : "Niet verbonden"
                case .operatorError:
                    statusText = "Operatorfout · druk Reset"
                }
            }
            if command == "Ascii", response.succeeded {
                screen.update(lines: response.data, status: response.status)
            } else if !response.succeeded {
                statusText = response.data.last ?? "Opdracht mislukt"
            }
        case .stopped(let error):
            connected = false
            statusText = error.map { "ws3270 gestopt: \($0)" } ?? "ws3270 gestopt"
        }
    }

    private func savePreferences() {
        let defaults = UserDefaults.standard
        defaults.set(host, forKey: "windows.host")
        defaults.set(port, forKey: "windows.port")
        defaults.set(luName, forKey: "windows.lu")
        defaults.set(useTLS, forKey: "windows.tls")
        defaults.set(executable, forKey: "windows.ws3270")
        defaults.set(oversize, forKey: "windows.oversize")
        defaults.set((selectedModel ?? .model4).rawValue, forKey: "windows.model")
    }
}
