import SwiftCrossUI

#if os(Windows)
import UWP
import WinUI
import WinUIBackend

struct WindowsTerminalView {
    let text: String
    let onAction: (String) -> Void
    let onCharacter: (Character) -> Void
    let onPaste: @MainActor @Sendable (String) -> Void
}

extension WindowsTerminalView: WinUIElementRepresentable {
    func makeWinUIElement(context: Context) -> TextBox {
        let terminal = TextBox()
        terminal.isReadOnly = true
        terminal.acceptsReturn = true
        terminal.textWrapping = .noWrap
        terminal.isSpellCheckEnabled = false
        terminal.isTextPredictionEnabled = false
        terminal.fontFamily = FontFamily("Cascadia Mono")
        terminal.fontSize = 16

        let foreground = SolidColorBrush()
        foreground.color = UWP.Color(a: 255, r: 107, g: 255, b: 79)
        terminal.foreground = foreground

        let background = SolidColorBrush()
        background.color = UWP.Color(a: 255, r: 0, g: 0, b: 0)
        terminal.background = background

        ScrollViewer.setHorizontalScrollBarVisibility(terminal, .auto)
        ScrollViewer.setVerticalScrollBarVisibility(terminal, .auto)

        terminal.keyDown.addHandler { _, event in
            guard let event else { return }
            if event.key == .v, isKeyDown(.control) {
                event.handled = true
                pasteClipboardText()
                return
            }
            guard let action = action(for: event.key, shiftDown: isKeyDown(.shift)) else { return }
            event.handled = true
            onAction(action)
        }
        terminal.characterReceived.addHandler { _, event in
            guard let event else { return }
            let character = event.character
            guard character.unicodeScalars.first.map({ $0.value >= 32 }) == true else { return }
            event.handled = true
            onCharacter(character)
        }
        return terminal
    }

    private func isKeyDown(_ key: UWP.VirtualKey) -> Bool {
        guard let window = UWP.CoreWindow.getForCurrentThread(),
              let state = try? window.getKeyState(key) else { return false }
        return state.rawValue & UWP.CoreVirtualKeyStates.down.rawValue != 0
    }

    private func pasteClipboardText() {
        let paste = onPaste
        guard let content = UWP.Clipboard.getContent(),
              (try? content.contains(UWP.StandardDataFormats.text)) == true,
              let operation = try? content.getTextAsync() else { return }

        // Use the native WinRT completion callback so the non-Sendable COM
        // operation never crosses a Swift concurrency boundary.
        operation.completed = { operation, status in
            guard status == .completed,
                  let operation,
                  let value = try? operation.getResults(),
                  !value.isEmpty else { return }
            Task { @MainActor in
                paste(value)
            }
        }
    }

    func updateWinUIElement(_ terminal: TextBox, context: Context) {
        guard terminal.text != text else { return }
        let selectionStart = terminal.selectionStart
        let selectionLength = terminal.selectionLength
        terminal.text = text
        if selectionStart >= 0, selectionStart + selectionLength <= Int32(text.utf16.count) {
            try? terminal.select(selectionStart, selectionLength)
        }
    }

    private func action(for key: UWP.VirtualKey, shiftDown: Bool) -> String? {
        if key == .enter { return "Enter" }
        if key == .tab { return shiftDown ? "BackTab" : "Tab" }
        if key == .back { return "BackSpace" }
        if key == .delete { return "Delete" }
        if key == .left { return "Left" }
        if key == .right { return "Right" }
        if key == .up { return "Up" }
        if key == .down { return "Down" }
        if key == .home { return "Home" }
        if key == .end { return "FieldEnd" }
        if key == .insert { return "ToggleInsert" }
        if key == .escape { return "Reset" }
        if key == .pageUp { return "PF(7)" }
        if key == .pageDown { return "PF(8)" }
        if key == .f1 { return "PF(\(shiftDown ? 13 : 1))" }
        if key == .f2 { return "PF(\(shiftDown ? 14 : 2))" }
        if key == .f3 { return "PF(\(shiftDown ? 15 : 3))" }
        if key == .f4 { return "PF(\(shiftDown ? 16 : 4))" }
        if key == .f5 { return "PF(\(shiftDown ? 17 : 5))" }
        if key == .f6 { return "PF(\(shiftDown ? 18 : 6))" }
        if key == .f7 { return "PF(\(shiftDown ? 19 : 7))" }
        if key == .f8 { return "PF(\(shiftDown ? 20 : 8))" }
        if key == .f9 { return "PF(\(shiftDown ? 21 : 9))" }
        if key == .f10 { return "PF(\(shiftDown ? 22 : 10))" }
        if key == .f11 { return "PF(\(shiftDown ? 23 : 11))" }
        if key == .f12 { return "PF(\(shiftDown ? 24 : 12))" }
        if key == .f13 { return "PF(13)" }
        if key == .f14 { return "PF(14)" }
        if key == .f15 { return "PF(15)" }
        if key == .f16 { return "PF(16)" }
        if key == .f17 { return "PF(17)" }
        if key == .f18 { return "PF(18)" }
        if key == .f19 { return "PF(19)" }
        if key == .f20 { return "PF(20)" }
        if key == .f21 { return "PF(21)" }
        if key == .f22 { return "PF(22)" }
        if key == .f23 { return "PF(23)" }
        if key == .f24 { return "PF(24)" }
        return nil
    }
}
#endif
