import Foundation

@MainActor
final class TerminalSession: ObservableObject, Identifiable {
    let id = UUID()
    @Published var profile: SessionProfile
    @Published private(set) var screenLines: [String] = []
    @Published private(set) var screenCells: [[TerminalCell]] = []
    @Published private(set) var cursor = TerminalCursor(row: 0, column: 0)
    @Published private(set) var statusText = "Disconnected"
    @Published private(set) var isConnected = false

    let rows = 24
    let columns = 80

    private var backend: B3270Backend
    private var refreshTask: Task<Void, Never>?
    private var directTextBuffer = ""
    private var directTextFlushTask: Task<Void, Never>?
    var onProfileChanged: (() -> Void)?

    init(profile: SessionProfile) {
        self.profile = profile
        self.backend = Self.makeBackend(codePage: profile.codePage) { _ in }
        resetScreenBuffer()
        backend = Self.makeBackend(codePage: profile.codePage) { [weak self] event in
            guard let session = self else { return }
            Task { @MainActor in session.applyScreenEvent(event) }
        }
    }

    var displayName: String {
        profile.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Sessie" : profile.name
    }

    func connect() async {
        let spec = profile.connectionSpec.trimmingCharacters(in: .whitespacesAndNewlines)
        if spec.isEmpty {
            await connect(host: profile.host, port: profile.port, useTLS: profile.useTLS)
        } else {
            await connect(spec: spec)
        }
    }

    func connect(spec: String) async {
        let parsed = HostSpec.parse(spec)
        profile.connectionSpec = spec
        profile.host = parsed.host
        profile.port = parsed.port
        profile.useTLS = parsed.useTLS
        onProfileChanged?()

        do {
            statusText = "Connecting to \(spec)..."
            resetScreenBuffer()
            rebuildBackend()
            try await backend.start()
            try await backend.connect(spec: spec)
            isConnected = true
            statusText = "Connected to \(spec)"
            await loadInitialSnapshot()
        } catch {
            isConnected = false
            statusText = "Connection failed: \(error.localizedDescription)"
            resetScreenBuffer()
        }
    }

    func connect(host: String, port: Int, useTLS: Bool) async {
        let prefix = useTLS ? "L:" : ""
        profile.connectionSpec = "\(prefix)\(host):\(port)"
        profile.host = host
        profile.port = port
        profile.useTLS = useTLS
        onProfileChanged?()

        do {
            statusText = "Connecting to \(profile.connectionSpec)..."
            resetScreenBuffer()
            rebuildBackend()
            try await backend.start()
            try await backend.connect(host: host, port: port, useTLS: useTLS)
            isConnected = true
            statusText = "Connected to \(profile.connectionSpec)"
            await loadInitialSnapshot()
        } catch {
            isConnected = false
            statusText = "Connection failed: \(error.localizedDescription)"
            resetScreenBuffer()
        }
    }

    func disconnect() async {
        refreshTask?.cancel()
        refreshTask = nil
        directTextFlushTask?.cancel()
        directTextFlushTask = nil
        await backend.stop()
        isConnected = false
        statusText = "Disconnected"
        resetScreenBuffer()
        rebuildBackend()
    }

    func setCodePage(_ codePage: String) {
        profile.codePage = codePage
        onProfileChanged?()
        if isConnected {
            statusText = "Code page \(codePage) selected; reconnect required"
        } else {
            rebuildBackend()
            statusText = "Code page \(codePage)"
        }
    }

    func rename(to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        profile.name = trimmed
        onProfileChanged?()
    }

    func updateProfile(name: String, connectionSpec: String, codePage: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSpec = connectionSpec.trimmingCharacters(in: .whitespacesAndNewlines)
        profile.name = trimmedName.isEmpty ? displayName : trimmedName
        profile.connectionSpec = trimmedSpec
        profile.codePage = codePage

        let parsed = HostSpec.parse(trimmedSpec)
        profile.host = parsed.host
        profile.port = parsed.port
        profile.useTLS = parsed.useTLS
        onProfileChanged?()

        if isConnected {
            statusText = "Session updated; reconnect required for connection/codepage changes"
        } else {
            rebuildBackend()
            statusText = "Session updated"
        }
    }

    private func rebuildBackend() {
        backend = Self.makeBackend(codePage: profile.codePage) { [weak self] event in
            guard let session = self else { return }
            Task { @MainActor in
                session.applyScreenEvent(event)
            }
        }
    }

    func sendEnter() async {
        await send(label: "Enter") { try await backend.enter() }
    }

    func sendClear() async {
        await send(label: "Clear") { try await backend.clear() }
    }

    func sendReset() async {
        await send(label: "Reset") { try await backend.reset() }
    }

    func sendPF(_ index: Int) async {
        await send(label: "PF\(index)") { try await backend.pf(index) }
    }

    func sendPA(_ index: Int) async {
        await send(label: "PA\(index)") { try await backend.pa(index) }
    }

    func sendEraseEOF() async {
        await send(label: "EraseEOF") { try await backend.eraseEOF() }
    }

    func sendFieldMark() async {
        await send(label: "FieldMark") { try await backend.fieldMark() }
    }

    func sendDup() async {
        await send(label: "Dup") { try await backend.dup() }
    }

    func sendAttn() async {
        await send(label: "Attn") { try await backend.attn() }
    }

    func sendSysReq() async {
        await send(label: "SysReq") { try await backend.sysReq() }
    }

    func sendText(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .newlines)
        guard !trimmed.isEmpty else { return }
        await send(label: "Text") { try await backend.sendText(trimmed) }
    }

    func handleKeyEvent(_ event: TerminalKeyEvent) {
        Task {
            switch event {
            case .text(let text):
                bufferDirectText(text)
            case .enter:
                await flushDirectText()
                await sendEnter()
            case .erase:
                await flushDirectText()
                await send(label: "Erase") { try await backend.erase() }
            case .delete:
                await flushDirectText()
                await send(label: "Delete") { try await backend.delete() }
            case .eraseEOF:
                await flushDirectText()
                await sendEraseEOF()
            case .tab:
                await flushDirectText()
                await send(label: "Tab") { try await backend.tab() }
            case .backTab:
                await flushDirectText()
                await send(label: "BackTab") { try await backend.backTab() }
            case .left:
                await flushDirectText()
                await send(label: "Left") { try await backend.left() }
            case .right:
                await flushDirectText()
                await send(label: "Right") { try await backend.right() }
            case .up:
                await flushDirectText()
                await send(label: "Up") { try await backend.up() }
            case .down:
                await flushDirectText()
                await send(label: "Down") { try await backend.down() }
            case .home:
                await flushDirectText()
                await send(label: "Home") { try await backend.home() }
            case .end:
                await flushDirectText()
                await sendEraseEOF()
            case .pageUp:
                await flushDirectText()
                await sendPF(7)
            case .pageDown:
                await flushDirectText()
                await sendPF(8)
            case .attn:
                await flushDirectText()
                await sendAttn()
            case .sysReq:
                await flushDirectText()
                await sendSysReq()
            case .moveCursor(let row, let column):
                await flushDirectText()
                await send(label: "MoveCursor") { try await backend.moveCursor(row: row, column: column) }
            case .reset:
                await flushDirectText()
                await send(label: "Reset") { try await backend.reset() }
            case .pf(let index):
                await flushDirectText()
                await sendPF(index)
            }
        }
    }

    private func bufferDirectText(_ text: String) {
        directTextBuffer += text
        directTextFlushTask?.cancel()
        directTextFlushTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(8))
            await self?.flushDirectText()
        }
    }

    private func flushDirectText() async {
        directTextFlushTask?.cancel()
        directTextFlushTask = nil
        let text = directTextBuffer
        directTextBuffer = ""
        guard !text.isEmpty, isConnected else { return }

        do {
            try await backend.sendText(text)
        } catch {
            statusText = "Type failed: \(error.localizedDescription)"
        }
    }

    private func send(label: String, operation: () async throws -> Void) async {
        guard isConnected else {
            statusText = "\(label) queued for connected sessions"
            return
        }

        do {
            try await operation()
        } catch {
            statusText = "Command failed: \(error.localizedDescription)"
        }
    }

    private static func makeBackend(
        codePage: String,
        screenEventHandler: @escaping @Sendable (B3270ScreenEvent) -> Void
    ) -> B3270Backend {
        B3270Backend(
            codePage: codePage,
            screenEventHandler: screenEventHandler
        )
    }

    private func applyScreenEvent(_ event: B3270ScreenEvent) {
        if event.clearsScreen {
            resetScreenBuffer(foreground: event.eraseForeground, background: event.eraseBackground)
        }

        if let cursor = event.cursor {
            self.cursor = cursor
        }

        guard !event.rowChanges.isEmpty else { return }

        var cells = normalizedCells()

        for rowChange in event.rowChanges where rowChange.row >= 0 && rowChange.row < rows {
            for change in rowChange.changes where change.column >= 0 && change.column < columns {
                let attributes = resolvedAttributes(
                    for: change,
                    row: rowChange.row,
                    in: cells
                )
                let width = change.count ?? change.text?.count ?? 0

                for offset in 0..<width {
                    let column = change.column + offset
                    guard column < columns else { break }
                    cells[rowChange.row][column].foreground = attributes.foreground
                    cells[rowChange.row][column].background = attributes.background
                    cells[rowChange.row][column].highlighting = attributes.highlighting
                }

                if let text = change.text {
                    for (offset, character) in text.enumerated() {
                        let column = change.column + offset
                        guard column < columns else { break }
                        cells[rowChange.row][column].character = character
                    }
                }
            }
        }

        setScreenCells(cells)
    }

    private func resolvedAttributes(
        for change: B3270ScreenEvent.CellChange,
        row: Int,
        in cells: [[TerminalCell]]
    ) -> (foreground: String?, background: String?, highlighting: String?) {
        let start = min(max(change.column, 0), columns - 1)
        let base = cells[row][start]
        return (
            foreground: change.foreground ?? base.foreground ?? "blue",
            background: change.background ?? base.background ?? "neutralBlack",
            highlighting: change.highlighting ?? base.highlighting
        )
    }

    private func resetScreenBuffer(foreground: String? = "blue", background: String? = "neutralBlack") {
        setScreenCells(
            (0..<rows).map { row in
                (0..<columns).map { column in
                    TerminalCell.blank(row: row, column: column, foreground: foreground, background: background)
                }
            }
        )
        cursor = TerminalCursor(row: 0, column: 0)
    }

    private func loadInitialSnapshot() async {
        do {
            let ascii = try await backend.ascii()
            applyTextSnapshotPreservingAttributes(
                ScreenParser.lines(from: ascii.joined(separator: "\n"), rows: rows, columns: columns)
            )
        } catch {
            statusText = "Initial screen load failed: \(error.localizedDescription)"
        }
    }

    private func setScreenLines(_ lines: [String], foreground: String?, background: String?) {
        setScreenCells(
            (0..<rows).map { row in
                let line = row < lines.count ? lines[row] : ""
                let characters = Array(line.padding(toLength: columns, withPad: " ", startingAt: 0).prefix(columns))
                return (0..<columns).map { column in
                    TerminalCell(
                        row: row,
                        column: column,
                        character: characters[column],
                        foreground: foreground,
                        background: background,
                        highlighting: nil
                    )
                }
            }
        )
    }

    private func setScreenCells(_ cells: [[TerminalCell]]) {
        screenCells = cells
        screenLines = cells.map { row in String(row.map(\.character)) }
    }

    private func applyTextSnapshotPreservingAttributes(_ lines: [String]) {
        var cells = normalizedCells()
        for row in 0..<rows {
            let line = row < lines.count ? lines[row] : ""
            let characters = Array(line.padding(toLength: columns, withPad: " ", startingAt: 0).prefix(columns))
            for column in 0..<columns {
                cells[row][column].character = characters[column]
            }
        }
        setScreenCells(cells)
    }

    private func normalizedCells() -> [[TerminalCell]] {
        guard screenCells.count == rows, screenCells.allSatisfy({ $0.count == columns }) else {
            return (0..<rows).map { row in
                let line = row < screenLines.count ? screenLines[row] : ""
                let characters = Array(line.padding(toLength: columns, withPad: " ", startingAt: 0).prefix(columns))
                return (0..<columns).map { column in
                    TerminalCell(
                        row: row,
                        column: column,
                        character: characters[column],
                        foreground: "blue",
                        background: "neutralBlack",
                        highlighting: nil
                    )
                }
            }
        }

        return screenCells
    }
}

struct TerminalCursor: Equatable {
    let row: Int
    let column: Int
}
