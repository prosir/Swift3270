import Foundation

actor B3270Backend {
    private var process: Process?
    private var input: Pipe?
    private var output: Pipe?
    private var errorOutput: Pipe?
    private var pendingText = ""
    private var pendingRunResults: [Result<B3270RunResult, Error>] = []
    private var commandInFlight = false
    private let codePage: String
    private let screenEventHandler: @Sendable (B3270ScreenEvent) -> Void

    init(
        codePage: String = "cp037",
        screenEventHandler: @escaping @Sendable (B3270ScreenEvent) -> Void = { _ in }
    ) {
        let override = ProcessInfo.processInfo.environment["SWIFT3270_CODEPAGE"]?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.codePage = override?.isEmpty == false ? override! : codePage
        self.screenEventHandler = screenEventHandler
    }

    func start() throws {
        if process?.isRunning == true { return }
        guard let executableURL = BinaryLocator.findB3270() else {
            throw B3270Error.missingBinary
        }

        let process = Process()
        let input = Pipe()
        let output = Pipe()
        let errorOutput = Pipe()

        process.executableURL = executableURL
        process.arguments = ["-json", "-nowrapperdoc", "-model", "2", "-utf8", "-codepage", codePage]
        process.standardInput = input
        process.standardOutput = output
        process.standardError = errorOutput

        try process.run()
        self.process = process
        self.input = input
        self.output = output
        self.errorOutput = errorOutput
        pendingText = ""
        pendingRunResults = []

        output.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            Task { await self?.acceptOutput(data) }
        }

        errorOutput.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            Task { await self?.discardErrorOutput() }
        }
    }

    private func discardErrorOutput() {}

    func connect(host: String, port: Int, useTLS: Bool) async throws {
        let prefix = useTLS ? "L:" : ""
        try await connect(spec: "\(prefix)\(host):\(port)")
    }

    func connect(spec: String) async throws {
        _ = try await run(action: "Connect", args: [spec], timeout: 45.0)
    }

    func ascii() async throws -> [String] {
        let result = try await run(action: "Ascii")
        return result.text ?? []
    }

    func enter() async throws {
        _ = try await run(action: "Enter")
    }

    func clear() async throws {
        _ = try await run(action: "Clear")
    }

    func sendText(_ text: String) async throws {
        _ = try await run(action: "String", args: [text])
    }

    func erase() async throws {
        _ = try await run(action: "Erase")
    }

    func delete() async throws {
        _ = try await run(action: "Delete")
    }

    func eraseEOF() async throws {
        _ = try await run(action: "EraseEOF")
    }

    func tab() async throws {
        _ = try await run(action: "Tab")
    }

    func backTab() async throws {
        _ = try await run(action: "BackTab")
    }

    func left() async throws {
        _ = try await run(action: "Left")
    }

    func right() async throws {
        _ = try await run(action: "Right")
    }

    func up() async throws {
        _ = try await run(action: "Up")
    }

    func down() async throws {
        _ = try await run(action: "Down")
    }

    func home() async throws {
        _ = try await run(action: "Home")
    }

    func end() async throws {
        _ = try await run(action: "End")
    }

    func moveCursor(row: Int, column: Int) async throws {
        _ = try await run(action: "MoveCursor", args: ["\(row)", "\(column)"])
    }

    func reset() async throws {
        _ = try await run(action: "Reset")
    }

    func fieldMark() async throws {
        _ = try await run(action: "FieldMark")
    }

    func dup() async throws {
        _ = try await run(action: "Dup")
    }

    func attn() async throws {
        _ = try await run(action: "Attn")
    }

    func sysReq() async throws {
        _ = try await run(action: "SysReq")
    }

    func pf(_ index: Int) async throws {
        _ = try await run(action: "PF", args: ["\(index)"])
    }

    func pa(_ index: Int) async throws {
        _ = try await run(action: "PA", args: ["\(index)"])
    }

    @discardableResult
    func run(action: String, args: [String] = [], timeout: TimeInterval = 5.0) async throws -> B3270RunResult {
        try await acquireCommandSlot(timeout: timeout)
        defer { commandInFlight = false }

        guard let input, process?.isRunning == true else {
            throw B3270Error.notRunning
        }

        var actionObject: [String: Any] = ["action": action]
        if !args.isEmpty {
            actionObject["args"] = args
        }

        let request: [String: Any] = [
            "run": [
                "actions": [actionObject]
            ]
        ]

        let data = try JSONSerialization.data(withJSONObject: request)
        try input.fileHandleForWriting.write(contentsOf: data + Data([0x0a]))

        return try await nextRunResult(timeout: timeout)
    }

    func stop() {
        output?.fileHandleForReading.readabilityHandler = nil
        errorOutput?.fileHandleForReading.readabilityHandler = nil
        if process?.isRunning == true {
            process?.terminate()
        }
        process = nil
        input = nil
        output = nil
        errorOutput = nil
        pendingText = ""
        pendingRunResults = []
        commandInFlight = false
    }

    private func acquireCommandSlot(timeout: TimeInterval) async throws {
        let deadline = Date().addingTimeInterval(timeout)

        while Date() < deadline {
            if !commandInFlight {
                commandInFlight = true
                return
            }

            try? await Task.sleep(for: .milliseconds(5))
        }

        throw B3270Error.timeout(timeout)
    }

    private func acceptOutput(_ data: Data) {
        guard let chunk = String(data: data, encoding: .utf8) else { return }
        pendingText += chunk

        while let newline = pendingText.firstIndex(of: "\n") {
            let line = sanitizeJsonLine(String(pendingText[..<newline]))
            pendingText.removeSubrange(...newline)

            guard !line.isEmpty,
                  let lineData = line.data(using: .utf8),
                  let object = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any] else {
                continue
            }

            if let screenEvent = B3270ScreenEvent(object: object) {
                screenEventHandler(screenEvent)
            }

            guard let result = object["run-result"] as? [String: Any] else {
                continue
            }

            pendingRunResults.append(Result { try B3270RunResult(dictionary: result) })
        }
    }

    private func nextRunResult(timeout: TimeInterval) async throws -> B3270RunResult {
        let deadline = Date().addingTimeInterval(timeout)

        while Date() < deadline {
            if !pendingRunResults.isEmpty {
                let result = pendingRunResults.removeFirst()
                return try result.get()
            }

            try? await Task.sleep(for: .milliseconds(5))
        }

        throw B3270Error.timeout(timeout)
    }

    private func sanitizeJsonLine(_ rawLine: String) -> String {
        var line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
        line = line.replacingOccurrences(of: "\u{feff}", with: "")

        if let objectStart = line.firstIndex(of: "{") {
            line = String(line[objectStart...])
        }

        return normalizeDecimalComma(in: line)
    }

    private func normalizeDecimalComma(in line: String) -> String {
        let pattern = #"("time"\s*:\s*\d+),(\d+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return line }
        let range = NSRange(line.startIndex..<line.endIndex, in: line)
        return regex.stringByReplacingMatches(
            in: line,
            range: range,
            withTemplate: "$1.$2"
        )
    }

}

enum B3270Error: LocalizedError {
    case missingBinary
    case notRunning
    case commandFailed(String)
    case timeout(TimeInterval)

    var errorDescription: String? {
        switch self {
        case .missingBinary:
            return "b3270 is niet gevonden. Installeer x3270 via Homebrew of zet SWIFT3270_B3270_PATH."
        case .notRunning:
            return "b3270 is niet gestart"
        case .commandFailed(let message):
            return message
        case .timeout(let seconds):
            return "b3270 gaf binnen \(Int(seconds)) seconden geen antwoord"
        }
    }
}

struct B3270RunResult {
    let success: Bool
    let text: [String]?

    init(dictionary: [String: Any]) throws {
        success = dictionary["success"] as? Bool ?? false
        text = dictionary["text"] as? [String]

        if !success {
            let message = (dictionary["text"] as? [String])?.joined(separator: "\n")
                ?? (dictionary["error"] as? String)
                ?? "b3270 command failed"
            throw B3270Error.commandFailed(message)
        }
    }
}
