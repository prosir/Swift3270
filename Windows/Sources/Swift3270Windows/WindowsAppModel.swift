import Foundation
import SwiftCrossUI
import Swift3270WindowsCore

#if os(Windows)
import UWP
import WindowsFoundation
#endif

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
    var applicationCode = ""
    var userID = ""
    var password = ""
    var automaticLoginEnabled = false
    var statusText = "Niet verbonden"
    var connected = false
    var connecting = false
    var insertMode = false
    var screen = TerminalScreen(rows: 43, columns: 80)
    var screenHistory: [TerminalScreen] = []
    var historyOffset = 0

    var displayedScreen: TerminalScreen {
        guard !screenHistory.isEmpty else { return screen }
        let index = max(0, screenHistory.count - 1 - historyOffset)
        return screenHistory[index]
    }

    var cobolErrors: [String] {
        COBOLErrorDetector.codes(in: displayedScreen.text)
    }

    var historyLabel: String {
        historyOffset == 0 ? "Live" : "Geschiedenis −\(historyOffset)"
    }

    @ObservationIgnored private let backend = WS3270Backend()
    @ObservationIgnored private var automaticLoginTask: Task<Void, Never>?
    @ObservationIgnored private var lastAutomaticLoginKey: String?
    @ObservationIgnored private var pendingAutomaticLoginKey: String?

    init() {
        let defaults = UserDefaults.standard
        host = defaults.string(forKey: "windows.host") ?? ""
        port = defaults.string(forKey: "windows.port") ?? "23"
        luName = defaults.string(forKey: "windows.lu") ?? ""
        useTLS = defaults.bool(forKey: "windows.tls")
        executable = defaults.string(forKey: "windows.ws3270") ?? "ws3270.exe"
        oversize = defaults.string(forKey: "windows.oversize") ?? ""
        applicationCode = defaults.string(forKey: "windows.login.application") ?? ""
        userID = defaults.string(forKey: "windows.login.userid") ?? ""
        automaticLoginEnabled = defaults.bool(forKey: "windows.login.automatic")
        if let storedModel = defaults.object(forKey: "windows.model") as? Int {
            selectedModel = TerminalModel(rawValue: storedModel) ?? .model4
        }
    }

    func connect() {
        guard !connecting else { return }
        let trimmedHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedHost.isEmpty, let parsedPort = Int(port), (1...65_535).contains(parsedPort) else {
            statusText = "Vul een geldige host en poort in"
            return
        }

        savePreferences()
        let model = selectedModel ?? .model4
        let hostSpec = HostSpec(host: trimmedHost, port: parsedPort, useTLS: useTLS, luName: luName)
        statusText = "Verbinden met \(trimmedHost)…"
        connecting = true
        lastAutomaticLoginKey = nil
        pendingAutomaticLoginKey = nil
        screenHistory.removeAll(keepingCapacity: true)
        historyOffset = 0

        Task {
            if await backend.isRunning {
                if connected {
                    await backend.send("Disconnect")
                    try? await Task.sleep(for: .milliseconds(200))
                }
            } else {
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
        statusText = "Verbinding verbreken…"
        automaticLoginTask?.cancel()
        pendingAutomaticLoginKey = nil
        Task { await backend.sendAndRefresh("Disconnect") }
    }

    func closeEngine() {
        automaticLoginTask?.cancel()
        pendingAutomaticLoginKey = nil
        Task { await backend.stop() }
    }

    func send(_ action: String) {
        guard connected else { return }
        Task { await backend.sendAndRefresh(action) }
    }

    func typeCharacter(_ character: Character) {
        guard connected else { return }
        Task { await backend.send(WS3270Action.string(String(character))) }
    }

    func pasteText(_ text: String) {
        let normalized = text
            .replacingOccurrences(of: "\r\n", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
        guard connected, !normalized.isEmpty else { return }
        Task { await backend.send(WS3270Action.string(normalized)) }
    }

    func sendCommandText() {
        guard connected else { return }
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

    func showOlderScreen() {
        guard historyOffset + 1 < screenHistory.count else { return }
        historyOffset += 1
    }

    func showNewerScreen() {
        historyOffset = max(0, historyOffset - 1)
    }

    func showLiveScreen() {
        historyOffset = 0
    }

    func lookupCOBOLError(_ code: String) {
        guard let query = "site:ibm.com/docs \(code) IBM COBOL"
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return }
#if os(Windows)
        let uri = WindowsFoundation.Uri("https://www.google.com/search?q=\(query)")
        Task {
            _ = try? await UWP.Launcher.launchUriAsync(uri).get()
        }
#else
        statusText = "COBOL-documentatie: \(code)"
#endif
    }

    private func handle(_ event: WS3270Event) {
        switch event {
        case .response(let command, let response):
            if command?.hasPrefix("Connect(") == true {
                connecting = false
            }
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
                captureScreenHistory()
                scheduleAutomaticLogin()
            } else if !response.succeeded {
                if command?.hasPrefix("Connect(") == true {
                    connecting = false
                }
                statusText = response.data.last ?? "Opdracht mislukt"
            }
        case .stopped(let error):
            connected = false
            connecting = false
            automaticLoginTask?.cancel()
            pendingAutomaticLoginKey = nil
            statusText = error.map { "ws3270 gestopt: \($0)" } ?? "ws3270 gestopt"
        }
    }

    private func captureScreenHistory() {
        let hasContent = screen.lines.contains { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        guard hasContent, screenHistory.last != screen else { return }
        if historyOffset > 0 {
            historyOffset += 1
        }
        screenHistory.append(screen)
        if screenHistory.count > 50 {
            let removed = screenHistory.count - 50
            screenHistory.removeFirst(removed)
            historyOffset = min(historyOffset, max(0, screenHistory.count - 1))
        }
    }

    private func scheduleAutomaticLogin() {
        guard connected, automaticLoginEnabled else {
            automaticLoginTask?.cancel()
            pendingAutomaticLoginKey = nil
            lastAutomaticLoginKey = nil
            return
        }

        let configuration = AutomaticLoginConfiguration(
            applicationCode: applicationCode,
            userID: userID,
            password: password
        )
        guard let plan = AutomaticLoginDetector.plan(for: screen, configuration: configuration) else {
            automaticLoginTask?.cancel()
            pendingAutomaticLoginKey = nil
            lastAutomaticLoginKey = nil
            return
        }
        guard plan.key != lastAutomaticLoginKey else { return }
        guard plan.key != pendingAutomaticLoginKey else { return }

        automaticLoginTask?.cancel()
        pendingAutomaticLoginKey = plan.key
        automaticLoginTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(700))
            guard !Task.isCancelled, let self else { return }
            pendingAutomaticLoginKey = nil
            lastAutomaticLoginKey = plan.key
            for command in plan.commands {
                await backend.send(command.ws3270Action)
            }
            await backend.send("Ascii")
            statusText = "Automatische login: \(plan.description) ingevuld"
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
        defaults.set(applicationCode, forKey: "windows.login.application")
        defaults.set(userID, forKey: "windows.login.userid")
        defaults.set(automaticLoginEnabled, forKey: "windows.login.automatic")
        defaults.set((selectedModel ?? .model4).rawValue, forKey: "windows.model")
    }
}
