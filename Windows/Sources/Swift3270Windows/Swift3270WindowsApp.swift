import SwiftCrossUI
import WinUIBackend

@main
struct Swift3270WindowsApp: App {
    @State private var model = WindowsAppModel()

    var body: some Scene {
        WindowGroup("Swift3270") {
            ContentView()
                .environment(model)
        }
        .defaultSize(width: 1180, height: 820)
        .windowResizability(.contentMinSize)
    }
}

struct ContentView: View {
    @Environment(WindowsAppModel.self) private var model

    var body: some View {
        VStack(spacing: 0) {
            connectionBar
                .padding(10)

            loginBar
                .padding(8)

            terminal

            terminalToolsBar
                .padding(6)

            actionBar
                .padding(8)

            statusBar
                .padding(8)
        }
        .background(Color(red: 0.025, green: 0.035, blue: 0.055))
    }

    private var connectionBar: some View {
        HStack(spacing: 8) {
            TextField("Host", text: model.$host)
                .frame(minWidth: 180)
            TextField("Poort", text: model.$port)
                .frame(width: 72)
            TextField("LU (optioneel)", text: model.$luName)
                .frame(width: 120)
            Toggle("TLS", isOn: model.$useTLS)
            Picker(of: TerminalModel.allCases, selection: model.$selectedModel)
                .disabled(model.connected)
            TextField("Oversize, bv. 80x43", text: model.$oversize)
                .frame(width: 145)
                .disabled(model.connected)
            TextField("ws3270.exe", text: model.$executable)
                .frame(width: 130)
                .disabled(model.connected)
            Button(model.connected ? "Opnieuw verbinden" : "Verbinden") {
                model.connect()
            }
            .disabled(model.connecting)
            Button("Disconnect") {
                model.disconnect()
            }
            .disabled(!model.connected)
        }
    }

    private var loginBar: some View {
        HStack(spacing: 8) {
            Text("Automatische login")
                .foregroundColor(.gray)
            TextField("Toepassing (TSOT/COF1R1)", text: model.$applicationCode)
                .frame(width: 190)
            TextField("User-ID", text: model.$userID)
                .frame(width: 150)
            SecureField("Password/phrase", text: model.$password)
                .frame(width: 180)
            Toggle("Automatisch invullen + Enter", isOn: model.$automaticLoginEnabled)
            Text("Password blijft alleen in het geheugen")
                .foregroundColor(.gray)
        }
    }

    private var terminal: some View {
#if os(Windows)
        WindowsTerminalView(
            text: model.displayedScreen.text,
            onAction: { model.send($0) },
            onCharacter: { model.typeCharacter($0) },
            onPaste: { model.pasteText($0) }
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
#else
        ScrollView(.horizontal) {
            ScrollView(.vertical) {
                Text(model.displayedScreen.text)
                    .font(.system(size: 16).monospaced())
                    .foregroundColor(Color(red: 0.42, green: 1.0, blue: 0.31))
                    .textSelectionEnabled(true)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(12)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.black)
#endif
    }

    private var terminalToolsBar: some View {
        HStack(spacing: 8) {
            Text(model.historyLabel)
                .foregroundColor(model.historyOffset == 0 ? .green : .gray)
            Button("Ouder") { model.showOlderScreen() }
                .disabled(model.historyOffset + 1 >= model.screenHistory.count)
            Button("Nieuwer") { model.showNewerScreen() }
                .disabled(model.historyOffset == 0)
            Button("Live") { model.showLiveScreen() }
                .disabled(model.historyOffset == 0)

            if !model.cobolErrors.isEmpty {
                Text("COBOL:")
                    .foregroundColor(.gray)
                ForEach(model.cobolErrors, id: \.self) { code in
                    Button(code) { model.lookupCOBOLError(code) }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var actionBar: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                Button("Enter") { model.send("Enter") }
                Button("Clear") { model.send("Clear") }
                Button("Reset") { model.send("Reset") }
                Button("Tab") { model.send("Tab") }
                Button("Backtab") { model.send("BackTab") }
                Button(model.insertMode ? "Insert aan" : "Insert uit") { model.toggleInsert() }
                Button("←") { model.send("Left") }
                Button("↑") { model.send("Up") }
                Button("↓") { model.send("Down") }
                Button("→") { model.send("Right") }
            }
            HStack(spacing: 4) {
                ForEach(1...12, id: \.self) { number in
                    Button("F\(number)") { model.send("PF(\(number))") }
                }
            }
            HStack(spacing: 4) {
                ForEach(13...24, id: \.self) { number in
                    Button("F\(number)") { model.send("PF(\(number))") }
                }
            }
            HStack(spacing: 6) {
                Button("PA1") { model.send("PA(1)") }
                Button("PA2") { model.send("PA(2)") }
                Button("PA3") { model.send("PA(3)") }
                Button("Attn") { model.send("Attn") }
                Button("SysReq") { model.send("SysReq") }
                Button("Erase EOF") { model.send("EraseEOF") }
                Button("FieldMark") { model.send("FieldMark") }
                Button("Dup") { model.send("Dup") }
                Button("Home") { model.send("Home") }
                Button("Field End") { model.send("FieldEnd") }
            }
            HStack(spacing: 8) {
                TextField("Tekst naar huidig 3270-veld", text: model.$commandText)
                    .onSubmit { model.sendCommandText() }
                Button("Stuur + Enter") { model.sendCommandText() }
            }
        }
        .disabled(!model.connected)
    }

    private var statusBar: some View {
        HStack {
            Text(model.statusText)
                .foregroundColor(model.connected ? .green : .gray)
            Text("Model \(model.selectedModel?.rawValue ?? 4) · \(model.displayedScreen.rows)x\(model.displayedScreen.columns)")
                .foregroundColor(.gray)
            Text("Regel \(model.displayedScreen.cursor.row + 1), kolom \(model.displayedScreen.cursor.column + 1)")
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
