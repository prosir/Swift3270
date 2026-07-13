import SwiftUI

@main
struct Swift3270App: App {
    @StateObject private var sessionStore = SessionStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(sessionStore)
                .frame(minWidth: 1120, minHeight: 720)
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandMenu("3270") {
                Button("New Session") { sessionStore.addSession() }
                    .keyboardShortcut("n", modifiers: [.command, .shift])
                Button("Duplicate Session") { sessionStore.duplicateSelectedSession() }
                    .keyboardShortcut("d", modifiers: [.command, .shift])
                Button("Close Session") { Task { await sessionStore.closeSelectedSession() } }
                    .keyboardShortcut("w", modifiers: [.command])
                    .disabled(sessionStore.sessions.count <= 1)
                Divider()
                Button("Enter") { Task { await sessionStore.selectedSession.sendEnter() } }
                    .keyboardShortcut(.return, modifiers: [])
                Button("Clear") { Task { await sessionStore.selectedSession.sendClear() } }
                    .keyboardShortcut("k", modifiers: [.command])
                Button("Reset") { Task { await sessionStore.selectedSession.sendReset() } }
                Button("Erase EOF") { Task { await sessionStore.selectedSession.sendEraseEOF() } }
                Divider()
                ForEach(1...24, id: \.self) { index in
                    Button("PF\(index)") { Task { await sessionStore.selectedSession.sendPF(index) } }
                }
                Divider()
                Button("PA1") { Task { await sessionStore.selectedSession.sendPA(1) } }
                Button("PA2") { Task { await sessionStore.selectedSession.sendPA(2) } }
                Button("PA3") { Task { await sessionStore.selectedSession.sendPA(3) } }
                Button("Attn") { Task { await sessionStore.selectedSession.sendAttn() } }
                Button("SysReq") { Task { await sessionStore.selectedSession.sendSysReq() } }
            }
        }
    }
}
