import AppKit
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: SessionStore
    @State private var scaleMode: ScaleMode = .fit
    @State private var manualScale = 1.0
    @State private var showConnectDialog = false
    @State private var showNewSessionDialog = false
    @State private var showEditSessionDialog = false
    @State private var showKeypad = false
    @State private var terminalTheme: TerminalTheme = .ibm3279

    var body: some View {
        VStack(spacing: 0) {
            X3270MenuBar(
                session: store.selectedSession,
                showConnectDialog: $showConnectDialog,
                showNewSessionDialog: $showNewSessionDialog,
                showEditSessionDialog: $showEditSessionDialog,
                showKeypad: $showKeypad,
                scaleMode: $scaleMode,
                manualScale: $manualScale,
                terminalTheme: $terminalTheme
            )

            X3270SessionStrip()

            HStack(spacing: 0) {
                X3270TerminalPane(
                    session: store.selectedSession,
                    scaleMode: scaleMode,
                    manualScale: manualScale,
                    terminalTheme: terminalTheme,
                    showConnectDialog: $showConnectDialog,
                    showNewSessionDialog: $showNewSessionDialog,
                    showEditSessionDialog: $showEditSessionDialog
                )
                    .frame(minWidth: 680)

                if showKeypad {
                    X3270KeypadPanel(session: store.selectedSession, showKeypad: $showKeypad)
                        .frame(width: 286)
                        .padding(.trailing, 10)
                        .padding(.vertical, 10)
                }
            }

            X3270StatusBar(session: store.selectedSession)
        }
        .background(X3270Colors.appBackground)
        .sheet(isPresented: $showConnectDialog) {
            X3270ConnectDialog(session: store.selectedSession)
        }
        .sheet(isPresented: $showNewSessionDialog) {
            X3270NewSessionDialog()
        }
        .sheet(isPresented: $showEditSessionDialog) {
            X3270EditSessionDialog(session: store.selectedSession)
        }
        .preferredColorScheme(.dark)
    }
}

private struct X3270TerminalPane: View {
    @ObservedObject var session: TerminalSession
    let scaleMode: ScaleMode
    let manualScale: Double
    let terminalTheme: TerminalTheme
    @Binding var showConnectDialog: Bool
    @Binding var showNewSessionDialog: Bool
    @Binding var showEditSessionDialog: Bool
    @State private var selection: TerminalSelection?

    var body: some View {
        GeometryReader { geometry in
            let fittedSize = TerminalMetrics.fontSize(
                container: geometry.size,
                columns: session.columns,
                rows: session.rows,
                mode: scaleMode,
                manualScale: manualScale
            )

            TerminalGridView(
                cells: session.screenCells,
                fontSize: fittedSize,
                cursor: session.cursor,
                theme: terminalTheme,
                selection: selection
            )
            .overlay(
                TerminalKeyboardCaptureView(
                    fontSize: fittedSize,
                    rows: session.rows,
                    columns: session.columns,
                    onCopy: {
                    copySelectionToClipboard()
                    },
                    onPaste: { text in
                        pasteText(text)
                    },
                    onEvent: { event in
                        handleTerminalEvent(event)
                    }
                )
            )
            .padding(10)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(X3270Colors.terminalFrame)
            .overlay {
                if !session.isConnected {
                    X3270StartScreen(
                        session: session,
                        showConnectDialog: $showConnectDialog,
                        showNewSessionDialog: $showNewSessionDialog,
                        showEditSessionDialog: $showEditSessionDialog
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
                }
            }
            .animation(.easeInOut(duration: 0.18), value: session.isConnected)
        }
    }

    private func handleTerminalEvent(_ event: TerminalKeyEvent) {
        switch event {
        case .selectionStarted(let row, let column):
            let cursor = TerminalCursor(row: row, column: column)
            selection = TerminalSelection(anchor: cursor, focus: cursor)
        case .selectionChanged(let row, let column):
            guard let current = selection else { return }
            selection = TerminalSelection(anchor: current.anchor, focus: TerminalCursor(row: row, column: column))
        case .selectionEnded:
            break
        case .moveCursor:
            selection = nil
            session.handleKeyEvent(event)
        case .text:
            selection = nil
            session.handleKeyEvent(event)
        default:
            session.handleKeyEvent(event)
        }
    }

    private func copySelectionToClipboard() {
        let text = selectedText()
        guard !text.isEmpty else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    private func pasteText(_ text: String) {
        selection = nil
        let normalized = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .replacingOccurrences(of: "\n", with: "\r")
        Task { await session.sendText(normalized) }
    }

    private func selectedText() -> String {
        guard let selection else {
            return fullScreenText()
        }

        let range = selection.normalized
        let rows = session.screenCells
        guard !rows.isEmpty else { return "" }

        return (range.start.row...range.end.row).compactMap { row in
            guard row >= 0, row < rows.count else { return nil }
            let rowCells = rows[row]
            let startColumn = row == range.start.row ? range.start.column : 0
            let endColumn = row == range.end.row ? range.end.column : rowCells.count - 1
            guard startColumn <= endColumn, startColumn < rowCells.count else { return "" }
            let safeEnd = min(endColumn, rowCells.count - 1)
            return String(rowCells[startColumn...safeEnd].map(\.character)).trimmedRight()
        }
        .joined(separator: "\n")
    }

    private func fullScreenText() -> String {
        session.screenCells
            .map { String($0.map(\.character)).trimmedRight() }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private struct X3270MenuBar: View {
    @EnvironmentObject private var store: SessionStore
    @ObservedObject var session: TerminalSession
    @Binding var showConnectDialog: Bool
    @Binding var showNewSessionDialog: Bool
    @Binding var showEditSessionDialog: Bool
    @Binding var showKeypad: Bool
    @Binding var scaleMode: ScaleMode
    @Binding var manualScale: Double
    @Binding var terminalTheme: TerminalTheme

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "terminal.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(X3270Colors.accent)
                Text("Swift3270")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(X3270Colors.primaryText)
            }
            .padding(.trailing, 4)

            menu("File") {
                Button("Transfer File...") {}
                Menu("Printer") {
                    Button("Associate Printer Session") {}
                    Button("Specific LU...") {}
                    Button("Stop Printer") {}
                }
                Divider()
                Button("Trace...") {}
                Button("Screen Trace...") {}
                Button("Print Window...") {}
                Button("Save Options...") {}
                Button("Save Input") {}
                Button("Restore Input") {}
                Divider()
                Button("Disconnect") { Task { await session.disconnect() } }
                    .disabled(!session.isConnected)
                Button("Exit") { NSApplication.shared.terminate(nil) }
            }

            menu("Connect") {
                Button("Other...") { showConnectDialog = true }
                Divider()
                Button("New Session...") { showNewSessionDialog = true }
                Button("Edit Session...") { showEditSessionDialog = true }
                Button("Duplicate Session") { store.duplicateSelectedSession() }
                Button("Close Session") { Task { await store.closeSelectedSession() } }
                    .disabled(store.sessions.count <= 1)
            }

            menu("Options") {
                Menu("Toggles") {
                    Toggle("Keypad", isOn: $showKeypad)
                    Toggle("Cursor Blink", isOn: .constant(false))
                    Toggle("Blank Fill", isOn: .constant(true))
                    Toggle("Show Timing", isOn: .constant(false))
                    Toggle("Scroll Bar", isOn: .constant(false))
                    Toggle("Line Wrap", isOn: .constant(false))
                    Toggle("Overlay Paste", isOn: .constant(true))
                    Toggle("Typeahead", isOn: .constant(true))
                    Toggle("Reconnect", isOn: .constant(false))
                }
                Menu("Fonts") {
                    Button("8-point Font") { scaleMode = .manual; manualScale = 0.7 }
                    Button("12-point Font") { scaleMode = .manual; manualScale = 0.9 }
                    Button("3270 Font (14 point)") { scaleMode = .manual; manualScale = 1.0 }
                    Button("16-point Font") { scaleMode = .manual; manualScale = 1.15 }
                    Button("20-point Font") { scaleMode = .manual; manualScale = 1.4 }
                    Button("24-point Font") { scaleMode = .manual; manualScale = 1.65 }
                    Button("32-point Font") { scaleMode = .manual; manualScale = 2.0 }
                    Button("36-point Font") { scaleMode = .manual; manualScale = 2.25 }
                    Divider()
                    Button("Auto-fit") { scaleMode = .fit }
                }
                Menu("Models") {
                    Button("Model 2 24x80") {}
                    Button("Model 3 32x80") {}
                    Button("Model 4 43x80") {}
                    Button("Model 5 27x132") {}
                    Button("Oversize...") {}
                }
                Menu("Code Page") {
                    Button("cp037 US/International") { session.setCodePage("cp037") }
                    Button("cp500 Belgian/International") { session.setCodePage("cp500") }
                    Button("cp1140 US Euro") { session.setCodePage("cp1140") }
                    Button("cp1148 Belgian Euro") { session.setCodePage("cp1148") }
                    Button("bracket old IBM") { session.setCodePage("bracket") }
                }
                Menu("Colors") {
                    Button("default") { terminalTheme = .ibm3279 }
                    Button("reverse") { terminalTheme = .reverse }
                    Button("bright") { terminalTheme = .bright }
                    Button("GreenScreen") { terminalTheme = .greenScreen }
                }
                Button("Keymap...") {}
                Button("Display Keymap...") {}
                Button("Idle Command...") {}
            }

            Button {
                showConnectDialog = true
            } label: {
                Label(session.isConnected ? "Reconnect" : "Connect", systemImage: "bolt.horizontal.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .padding(.horizontal, 12)
                    .frame(height: 30)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .background(X3270Colors.accent)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            Button {
                showKeypad.toggle()
            } label: {
                Label(showKeypad ? "Hide Keys" : "Keys", systemImage: showKeypad ? "sidebar.right" : "keyboard")
                    .font(.system(size: 12, weight: .medium))
                    .padding(.horizontal, 10)
                    .frame(height: 28)
            }
            .buttonStyle(.plain)
            .foregroundStyle(showKeypad ? X3270Colors.selectedText : X3270Colors.primaryText)
            .background(showKeypad ? X3270Colors.selectedTab : X3270Colors.controlBackground)
            .clipShape(RoundedRectangle(cornerRadius: 7))

            Spacer(minLength: 0)

            HStack(spacing: 8) {
                statusPill(
                    title: session.isConnected ? "Connected" : "Offline",
                    color: session.isConnected ? X3270Colors.success : X3270Colors.mutedText
                )
                if session.profile.useTLS {
                    statusPill(title: "TLS", color: X3270Colors.warning)
                }
                Text(session.displayName)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                    .foregroundStyle(X3270Colors.secondaryText)
            }
            .padding(.horizontal, 8)
        }
        .padding(.horizontal, 10)
        .frame(height: 42)
        .background(X3270Colors.topBar)
    }

    private func menu<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        Menu {
            content()
        } label: {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(X3270Colors.primaryText)
                .padding(.horizontal, 11)
                .frame(height: 30)
        }
        .menuStyle(.borderlessButton)
        .frame(height: 32)
        .background(X3270Colors.controlBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 7)
                .stroke(X3270Colors.border.opacity(0.8), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 7))
    }

    private func statusPill(title: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
            Text(title)
                .font(.system(size: 11, weight: .semibold))
        }
        .foregroundStyle(X3270Colors.primaryText)
        .padding(.horizontal, 9)
        .frame(height: 24)
        .background(X3270Colors.controlBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(X3270Colors.border.opacity(0.7), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

private struct X3270StartScreen: View {
    @ObservedObject var session: TerminalSession
    @Binding var showConnectDialog: Bool
    @Binding var showNewSessionDialog: Bool
    @Binding var showEditSessionDialog: Bool

    private var isConnecting: Bool {
        session.statusText.lowercased().hasPrefix("connecting")
    }

    var body: some View {
        VStack(spacing: 18) {
            ZStack {
                RoundedRectangle(cornerRadius: 22)
                    .fill(X3270Colors.selectedTab)
                    .frame(width: 74, height: 74)
                    .overlay(
                        RoundedRectangle(cornerRadius: 22)
                            .stroke(X3270Colors.accent.opacity(0.75), lineWidth: 1)
                    )
                Image(systemName: "terminal.fill")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(X3270Colors.accentText)
            }

            VStack(spacing: 6) {
                Text(session.displayName)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(X3270Colors.primaryText)
                Text(startMessage)
                    .font(.system(size: 13))
                    .foregroundStyle(X3270Colors.secondaryText)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 10) {
                Button {
                    if isConnecting {
                        return
                    }
                    if session.profile.connectionSpec.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        showConnectDialog = true
                    } else {
                        Task { await session.connect() }
                    }
                } label: {
                    HStack(spacing: 8) {
                        if isConnecting {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "bolt.horizontal.fill")
                        }
                        Text(isConnecting ? "Connecting" : "Connect")
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 132, height: 36)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
                .background(isConnecting ? X3270Colors.mutedText : X3270Colors.accent)
                .clipShape(RoundedRectangle(cornerRadius: 9))

                Button {
                    showEditSessionDialog = true
                } label: {
                    Label("Edit Session", systemImage: "slider.horizontal.3")
                        .font(.system(size: 13, weight: .medium))
                        .frame(width: 132, height: 36)
                }
                .buttonStyle(.plain)
                .foregroundStyle(X3270Colors.primaryText)
                .background(X3270Colors.controlBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 9)
                        .stroke(X3270Colors.border, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 9))
            }

            Button {
                showNewSessionDialog = true
            } label: {
                Label("New Session", systemImage: "plus")
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(.plain)
            .foregroundStyle(X3270Colors.secondaryText)
        }
        .padding(28)
        .frame(width: 430)
        .background(X3270Colors.startPanel)
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(X3270Colors.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: Color.black.opacity(0.35), radius: 18, x: 0, y: 12)
    }

    private var startMessage: String {
        if isConnecting {
            return session.statusText
        }
        if session.statusText.lowercased().contains("failed") {
            return session.statusText
        }
        return connectionDisplay(for: session) ?? "Kies of maak een mainframe sessie."
    }
}

private struct X3270SessionStrip: View {
    @EnvironmentObject private var store: SessionStore
    @State private var showNewSessionDialog = false
    @State private var renameText = ""

    var body: some View {
        HStack(spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(store.sessions) { session in
                        sessionButton(session)
                    }
                }
                .padding(.horizontal, 2)
            }

            Button {
                showNewSessionDialog = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.plain)
            .foregroundStyle(X3270Colors.primaryText)
            .background(X3270Colors.controlBackground)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .help("Nieuwe sessie")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(X3270Colors.appBackground)
        .overlay(Rectangle().frame(height: 1).foregroundStyle(X3270Colors.border), alignment: .bottom)
        .sheet(isPresented: $showNewSessionDialog) {
            X3270NewSessionDialog()
        }
    }

    private func sessionButton(_ session: TerminalSession) -> some View {
        let selected = store.selectedSessionID == session.id

        return HStack(spacing: 8) {
            Button {
                store.selectedSessionID = session.id
            } label: {
                HStack(spacing: 8) {
                    Circle()
                        .fill(session.isConnected ? X3270Colors.success : X3270Colors.mutedText)
                        .frame(width: 8, height: 8)
                    Text(session.displayName)
                        .font(.system(size: 13, weight: selected ? .semibold : .medium))
                        .lineLimit(1)
                    if selected {
                        Text(session.profile.codePage)
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(X3270Colors.secondaryText)
                            .padding(.horizontal, 6)
                            .frame(height: 18)
                            .background(X3270Colors.badgeBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
                .foregroundStyle(selected ? X3270Colors.selectedText : X3270Colors.primaryText)
                .padding(.horizontal, 12)
                .frame(height: 32)
                .background(selected ? X3270Colors.selectedTab : X3270Colors.controlBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(selected ? X3270Colors.accent : X3270Colors.border, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            .contextMenu {
                Button("Rename") {
                    store.selectedSessionID = session.id
                    renameText = session.displayName
                }
                Button("Duplicate") {
                    store.selectedSessionID = session.id
                    store.duplicateSelectedSession()
                }
                Button("Close") {
                    store.selectedSessionID = session.id
                    Task { await store.closeSelectedSession() }
                }
                .disabled(store.sessions.count <= 1)
            }

            if selected {
                Button {
                    renameText = session.displayName
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 11, weight: .medium))
                        .frame(width: 28, height: 30)
                }
                .buttonStyle(.plain)
                .foregroundStyle(X3270Colors.secondaryText)
                .background(X3270Colors.controlBackground)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .sheet(
            isPresented: Binding(
                get: { !renameText.isEmpty && selected },
                set: { if !$0 { renameText = "" } }
            )
        ) {
            X3270RenameSessionDialog(name: $renameText)
        }
    }
}

private struct X3270StatusBar: View {
    @ObservedObject var session: TerminalSession

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 7) {
                Circle()
                    .fill(session.isConnected ? X3270Colors.success : X3270Colors.mutedText)
                    .frame(width: 7, height: 7)
                Text(session.isConnected ? "Connected" : "Offline")
                    .font(.system(size: 12, weight: .semibold))
            }

            Text(session.displayName)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(X3270Colors.primaryText)
                .lineLimit(1)

            if let connection = connectionDisplay(for: session) {
                Text(connection)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(X3270Colors.mutedText)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            Text(session.statusText)
                .lineLimit(1)
                .foregroundStyle(statusColor)

            statusBadge("Model 2")
            statusBadge("\(session.rows)x\(session.columns)")
            if session.profile.useTLS {
                statusBadge("TLS")
            }
        }
        .font(.system(size: 12))
        .foregroundStyle(X3270Colors.primaryText)
        .padding(.horizontal, 12)
        .frame(height: 34)
        .background(X3270Colors.panelBackground)
        .overlay(Rectangle().frame(height: 1).foregroundStyle(X3270Colors.border), alignment: .top)
    }

    private var statusColor: Color {
        let text = session.statusText.lowercased()
        if text.contains("failed") || text.contains("error") {
            return X3270Colors.warning
        }
        if session.isConnected {
            return X3270Colors.secondaryText
        }
        return X3270Colors.mutedText
    }

    private func statusBadge(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .medium, design: .monospaced))
            .foregroundStyle(X3270Colors.secondaryText)
            .padding(.horizontal, 8)
            .frame(height: 22)
            .background(X3270Colors.controlBackground)
            .clipShape(RoundedRectangle(cornerRadius: 7))
    }
}

private struct X3270KeypadPanel: View {
    @ObservedObject var session: TerminalSession
    @Binding var showKeypad: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Keypad")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(X3270Colors.primaryText)
                    Text("3270 actions")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(X3270Colors.mutedText)
                }

                Spacer()

                Button {
                    showKeypad = false
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .semibold))
                        .frame(width: 26, height: 26)
                }
                .buttonStyle(.plain)
                .foregroundStyle(X3270Colors.secondaryText)
                .background(X3270Colors.controlBackground)
                .clipShape(RoundedRectangle(cornerRadius: 7))
            }

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    section("Session") {
                        HStack(spacing: 6) {
                            key("Reset") { await session.sendReset() }
                            key("Clear") { await session.sendClear() }
                            key("Enter", prominent: true) { await session.sendEnter() }
                        }
                    }

                    section("Program function") {
                        Grid(horizontalSpacing: 6, verticalSpacing: 6) {
                            ForEach(0..<6, id: \.self) { row in
                                GridRow {
                                    ForEach(1...4, id: \.self) { column in
                                        let pf = row * 4 + column
                                        key("PF\(pf)") { await session.sendPF(pf) }
                                    }
                                }
                            }
                        }
                    }

                    section("Attention") {
                        HStack(spacing: 6) {
                            key("PA1") { await session.sendPA(1) }
                            key("PA2") { await session.sendPA(2) }
                            key("PA3") { await session.sendPA(3) }
                        }
                    }

                    section("Navigate") {
                        Grid(horizontalSpacing: 6, verticalSpacing: 6) {
                            GridRow {
                                spacerKey()
                                key("Up") { session.handleKeyEvent(.up) }
                                spacerKey()
                            }
                            GridRow {
                                key("Left") { session.handleKeyEvent(.left) }
                                key("Home") { session.handleKeyEvent(.home) }
                                key("Right") { session.handleKeyEvent(.right) }
                            }
                            GridRow {
                                key("PgUp") { session.handleKeyEvent(.pageUp) }
                                key("Down") { session.handleKeyEvent(.down) }
                                key("PgDn") { session.handleKeyEvent(.pageDown) }
                            }
                        }
                    }

                    section("Edit") {
                        Grid(horizontalSpacing: 6, verticalSpacing: 6) {
                            GridRow {
                                key("Delete") { session.handleKeyEvent(.delete) }
                                key("Erase") { session.handleKeyEvent(.erase) }
                                key("End") { await session.sendEraseEOF() }
                            }
                            GridRow {
                                key("BackTab") { session.handleKeyEvent(.backTab) }
                                key("Dup") { await session.sendDup() }
                                key("Field") { await session.sendFieldMark() }
                            }
                            GridRow {
                                key("Attn") { await session.sendAttn() }
                                key("SysReq") { await session.sendSysReq() }
                                spacerKey()
                            }
                        }
                    }
                }
                .padding(.bottom, 2)
            }
        }
        .padding(14)
        .background(X3270Colors.panelBackground.opacity(0.98))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(X3270Colors.border.opacity(0.9), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(X3270Colors.mutedText)
                .textCase(.uppercase)

            content()
        }
    }

    private func spacerKey() -> some View {
        Color.clear
            .frame(width: 58, height: 27)
    }

    private func key(_ title: String, prominent: Bool = false, action: @escaping () async -> Void) -> some View {
        Button {
            Task { await action() }
        } label: {
            Text(title)
                .font(.system(size: 11, weight: prominent ? .semibold : .medium))
                .foregroundStyle(prominent ? X3270Colors.selectedText : X3270Colors.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(width: 58, height: 27)
                .background(prominent ? X3270Colors.accent : X3270Colors.controlBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(prominent ? X3270Colors.accent.opacity(0.5) : X3270Colors.border.opacity(0.7), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .contentShape(RoundedRectangle(cornerRadius: 6))
            }
        .buttonStyle(.plain)
    }
}

private struct X3270ConnectionFields: View {
    @Binding var hostName: String
    @Binding var portText: String
    @Binding var luName: String
    @Binding var useTLS: Bool
    @Binding var acceptHostnameMismatch: Bool
    @Binding var acceptAnyCertificate: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    fieldLabel("Hostname")
                    TextField("mainframe.example.com", text: $hostName)
                        .modernTextField(monospaced: true)
                }

                VStack(alignment: .leading, spacing: 8) {
                    fieldLabel("Poort")
                    TextField("23", text: $portText)
                        .modernTextField(monospaced: true)
                        .frame(width: 96)
                        .onChange(of: portText) { value in
                            let digits = value.filter(\.isNumber)
                            if digits != value {
                                portText = digits
                            }
                        }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                fieldLabel("LU naam")
                TextField("Optioneel", text: $luName)
                    .modernTextField(monospaced: true)
            }

            VStack(alignment: .leading, spacing: 9) {
                Toggle("TLS gebruiken", isOn: $useTLS)
                Toggle("Hostname mismatch accepteren", isOn: $acceptHostnameMismatch)
                    .disabled(!useTLS)
                Toggle("Elk certificaat accepteren", isOn: $acceptAnyCertificate)
                    .disabled(!useTLS)
            }
            .font(.system(size: 12))
            .foregroundStyle(X3270Colors.primaryText)
            .padding(12)
            .background(X3270Colors.controlBackground)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .onChange(of: useTLS) { enabled in
                if !enabled {
                    acceptHostnameMismatch = false
                    acceptAnyCertificate = false
                }
            }
        }
    }

    private func fieldLabel(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(X3270Colors.primaryText)
    }
}

private func connectionFields(
    spec: String,
    fallbackHost: String,
    fallbackPort: Int,
    fallbackTLS: Bool
) -> (host: String, port: String, lu: String, tls: Bool, acceptHostnameMismatch: Bool, acceptAnyCertificate: Bool) {
    let trimmed = spec.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.isEmpty {
        return (
            host: fallbackHost,
            port: "\(fallbackPort == 0 ? 23 : fallbackPort)",
            lu: "",
            tls: fallbackTLS,
            acceptHostnameMismatch: false,
            acceptAnyCertificate: false
        )
    }

    let parsed = HostSpec.parse(trimmed)
    return (
        host: parsed.host,
        port: "\(parsed.port)",
        lu: parsed.luName,
        tls: parsed.useTLS,
        acceptHostnameMismatch: parsed.acceptHostnameMismatch,
        acceptAnyCertificate: parsed.acceptAnyCertificate
    )
}

private func connectionSpecFromFields(
    hostName: String,
    portText: String,
    luName: String,
    useTLS: Bool,
    acceptHostnameMismatch: Bool,
    acceptAnyCertificate: Bool
) -> String? {
    let host = hostName.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !host.isEmpty,
          let port = Int(portText),
          (1...65535).contains(port) else {
        return nil
    }

    return HostSpec.build(
        host: host,
        port: port,
        useTLS: useTLS,
        acceptHostnameMismatch: useTLS && acceptHostnameMismatch,
        acceptAnyCertificate: useTLS && acceptAnyCertificate,
        luName: luName
    )
}

@MainActor
private func connectionDisplay(for session: TerminalSession) -> String? {
    let spec = session.profile.connectionSpec.trimmingCharacters(in: .whitespacesAndNewlines)
    let host: String
    let port: Int
    let lu: String

    if spec.isEmpty {
        host = session.profile.host
        port = session.profile.port
        lu = ""
    } else {
        let parsed = HostSpec.parse(spec)
        host = parsed.host
        port = parsed.port
        lu = parsed.luName
    }

    guard !host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
    let target = lu.isEmpty ? host : "\(lu)@\(host)"
    return "\(target):\(port)"
}

private struct X3270NewSessionDialog: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: SessionStore
    @State private var name = ""
    @State private var hostName = ""
    @State private var portText = "23"
    @State private var luName = ""
    @State private var useTLS = false
    @State private var acceptHostnameMismatch = false
    @State private var acceptAnyCertificate = false
    @State private var codePage = "cp037"

    private let codePages = [
        ("cp037", "US/International"),
        ("cp500", "Belgian/International"),
        ("cp1140", "US Euro"),
        ("cp1148", "Belgian Euro"),
        ("bracket", "Old IBM")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Nieuwe sessie")
                        .font(.system(size: 20, weight: .semibold))
                    Text("Maak een eigen profiel dat automatisch bewaard blijft.")
                        .font(.system(size: 12))
                        .foregroundStyle(X3270Colors.secondaryText)
                }
                Spacer()
            }

            VStack(alignment: .leading, spacing: 8) {
                fieldLabel("Naam")
                TextField("Bijvoorbeeld Productie, Acceptatie, Werk", text: $name)
                    .modernTextField()
            }

            X3270ConnectionFields(
                hostName: $hostName,
                portText: $portText,
                luName: $luName,
                useTLS: $useTLS,
                acceptHostnameMismatch: $acceptHostnameMismatch,
                acceptAnyCertificate: $acceptAnyCertificate
            )

            VStack(alignment: .leading, spacing: 8) {
                fieldLabel("Codepage")
                Picker("", selection: $codePage) {
                    ForEach(codePages, id: \.0) { value, label in
                        Text("\(value) - \(label)").tag(value)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Create") { create() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canSubmit)
            }
        }
        .padding(22)
        .frame(width: 480)
        .background(X3270Colors.panelBackground)
    }

    private func fieldLabel(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(X3270Colors.primaryText)
    }

    private func create() {
        guard let spec = connectionSpecFromFields(
            hostName: hostName,
            portText: portText,
            luName: luName,
            useTLS: useTLS,
            acceptHostnameMismatch: acceptHostnameMismatch,
            acceptAnyCertificate: acceptAnyCertificate
        ) else { return }
        store.addSession(name: name, connectionSpec: spec, codePage: codePage)
        dismiss()
    }

    private var canSubmit: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && connectionSpecFromFields(
                hostName: hostName,
                portText: portText,
                luName: luName,
                useTLS: useTLS,
                acceptHostnameMismatch: acceptHostnameMismatch,
                acceptAnyCertificate: acceptAnyCertificate
            ) != nil
    }
}

private struct X3270RenameSessionDialog: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: SessionStore
    @Binding var name: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Sessie hernoemen")
                .font(.system(size: 20, weight: .semibold))

            TextField("Sessienaam", text: $name)
                .modernTextField()
                .onSubmit { save() }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Save") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(22)
        .frame(width: 420)
        .background(X3270Colors.panelBackground)
    }

    private func save() {
        store.renameSelectedSession(name)
        dismiss()
    }
}

private struct X3270EditSessionDialog: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: SessionStore
    @ObservedObject var session: TerminalSession
    @State private var name = ""
    @State private var hostName = ""
    @State private var portText = "23"
    @State private var luName = ""
    @State private var useTLS = false
    @State private var acceptHostnameMismatch = false
    @State private var acceptAnyCertificate = false
    @State private var codePage = "cp037"

    private let codePages = [
        ("cp037", "US/International"),
        ("cp500", "Belgian/International"),
        ("cp1140", "US Euro"),
        ("cp1148", "Belgian Euro"),
        ("bracket", "Old IBM")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Sessie bewerken")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(X3270Colors.primaryText)
                Text(session.isConnected ? "Wijzigingen in connectie/codepage gelden na reconnect." : "Wijzigingen worden direct bewaard.")
                    .font(.system(size: 12))
                    .foregroundStyle(X3270Colors.secondaryText)
            }

            VStack(alignment: .leading, spacing: 8) {
                fieldLabel("Naam")
                TextField("Sessienaam", text: $name)
                    .modernTextField()
            }

            X3270ConnectionFields(
                hostName: $hostName,
                portText: $portText,
                luName: $luName,
                useTLS: $useTLS,
                acceptHostnameMismatch: $acceptHostnameMismatch,
                acceptAnyCertificate: $acceptAnyCertificate
            )

            VStack(alignment: .leading, spacing: 8) {
                fieldLabel("Codepage")
                Picker("", selection: $codePage) {
                    ForEach(codePages, id: \.0) { value, label in
                        Text("\(value) - \(label)").tag(value)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Save") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canSubmit)
            }
        }
        .padding(22)
        .frame(width: 500)
        .background(X3270Colors.panelBackground)
        .onAppear {
            name = session.displayName
            let fields = connectionFields(
                spec: session.profile.connectionSpec,
                fallbackHost: session.profile.host,
                fallbackPort: session.profile.port,
                fallbackTLS: session.profile.useTLS
            )
            hostName = fields.host
            portText = fields.port
            luName = fields.lu
            useTLS = fields.tls
            acceptHostnameMismatch = fields.acceptHostnameMismatch
            acceptAnyCertificate = fields.acceptAnyCertificate
            codePage = session.profile.codePage
        }
    }

    private func fieldLabel(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(X3270Colors.primaryText)
    }

    private func save() {
        guard let spec = connectionSpecFromFields(
            hostName: hostName,
            portText: portText,
            luName: luName,
            useTLS: useTLS,
            acceptHostnameMismatch: acceptHostnameMismatch,
            acceptAnyCertificate: acceptAnyCertificate
        ) else { return }
        store.updateSelectedSession(name: name, connectionSpec: spec, codePage: codePage)
        dismiss()
    }

    private var canSubmit: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && connectionSpecFromFields(
                hostName: hostName,
                portText: portText,
                luName: luName,
                useTLS: useTLS,
                acceptHostnameMismatch: acceptHostnameMismatch,
                acceptAnyCertificate: acceptAnyCertificate
            ) != nil
    }
}

private struct X3270ConnectDialog: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var session: TerminalSession
    @State private var hostName = ""
    @State private var portText = "23"
    @State private var luName = ""
    @State private var useTLS = false
    @State private var acceptHostnameMismatch = false
    @State private var acceptAnyCertificate = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Connect")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(X3270Colors.primaryText)
                Text("Vul de mainframe host in; de x3270-prefixes worden automatisch gezet.")
                    .font(.system(size: 12))
                    .foregroundStyle(X3270Colors.secondaryText)
            }

            X3270ConnectionFields(
                hostName: $hostName,
                portText: $portText,
                luName: $luName,
                useTLS: $useTLS,
                acceptHostnameMismatch: $acceptHostnameMismatch,
                acceptAnyCertificate: $acceptAnyCertificate
            )

            HStack {
                Spacer()
                Button("Connect") { connect() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(connectionSpec == nil)
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                    .foregroundStyle(.red)
            }
        }
        .padding(22)
        .frame(width: 520)
        .background(X3270Colors.panelBackground)
        .onAppear {
            let fields = connectionFields(
                spec: session.profile.connectionSpec,
                fallbackHost: session.profile.host,
                fallbackPort: session.profile.port,
                fallbackTLS: session.profile.useTLS
            )
            hostName = fields.host
            portText = fields.port
            luName = fields.lu
            useTLS = fields.tls
            acceptHostnameMismatch = fields.acceptHostnameMismatch
            acceptAnyCertificate = fields.acceptAnyCertificate
        }
    }

    private func connect() {
        guard let spec = connectionSpec else { return }
        Task { await session.connect(spec: spec) }
        dismiss()
    }

    private var connectionSpec: String? {
        connectionSpecFromFields(
            hostName: hostName,
            portText: portText,
            luName: luName,
            useTLS: useTLS,
            acceptHostnameMismatch: acceptHostnameMismatch,
            acceptAnyCertificate: acceptAnyCertificate
        )
    }
}

private enum X3270Colors {
    static let appBackground = Color(red: 0.035, green: 0.043, blue: 0.060)
    static let topBar = Color(red: 0.060, green: 0.072, blue: 0.098)
    static let panelBackground = Color(red: 0.075, green: 0.088, blue: 0.118)
    static let controlBackground = Color(red: 0.110, green: 0.130, blue: 0.170)
    static let terminalFrame = Color(red: 0.010, green: 0.014, blue: 0.022)
    static let startPanel = Color(red: 0.070, green: 0.084, blue: 0.116)
    static let selectedTab = Color(red: 0.120, green: 0.220, blue: 0.390)
    static let badgeBackground = Color(red: 0.100, green: 0.175, blue: 0.280)
    static let border = Color(red: 0.320, green: 0.370, blue: 0.470)
    static let accent = Color(red: 0.200, green: 0.560, blue: 1.000)
    static let accentText = Color(red: 0.740, green: 0.900, blue: 1.000)
    static let success = Color(red: 0.220, green: 0.820, blue: 0.470)
    static let warning = Color(red: 1.000, green: 0.720, blue: 0.220)
    static let primaryText = Color(red: 0.940, green: 0.965, blue: 1.000)
    static let secondaryText = Color(red: 0.750, green: 0.805, blue: 0.890)
    static let mutedText = Color(red: 0.500, green: 0.570, blue: 0.680)
    static let selectedText = Color.white

    static let windowGrey = appBackground
    static let menuGrey = controlBackground
    static let keypadGrey = panelBackground
    static let borderGrey = border
}

private extension View {
    func modernTextField(monospaced: Bool = false) -> some View {
        self
            .textFieldStyle(.plain)
            .font(.system(size: 13, design: monospaced ? .monospaced : .default))
            .foregroundStyle(X3270Colors.primaryText)
            .tint(X3270Colors.accent)
            .padding(.horizontal, 10)
            .frame(height: 34)
            .background(X3270Colors.controlBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(X3270Colors.border, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private extension String {
    func trimmedRight() -> String {
        var text = self
        while text.last == " " {
            text.removeLast()
        }
        return text
    }
}

enum ScaleMode: String, CaseIterable, Identifiable {
    case fit
    case manual

    var id: String { rawValue }
    var label: String { self == .fit ? "Fit" : "Manual" }
}
