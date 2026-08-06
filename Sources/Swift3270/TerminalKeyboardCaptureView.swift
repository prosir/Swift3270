import AppKit
import SwiftUI

struct TerminalKeyboardCaptureView: NSViewRepresentable {
    let fontSize: CGFloat
    let lineHeight: CGFloat
    let rows: Int
    let columns: Int
    var onCopy: () -> Void
    var onPaste: (String) -> Void
    var onFind: () -> Void
    var onHistoryScroll: (Int) -> Void
    var onEvent: (TerminalKeyEvent) -> Void

    func makeNSView(context: Context) -> KeyCaptureNSView {
        let view = KeyCaptureNSView()
        view.fontSize = fontSize
        view.lineHeight = lineHeight
        view.rows = rows
        view.columns = columns
        view.onCopy = onCopy
        view.onPaste = onPaste
        view.onFind = onFind
        view.onHistoryScroll = onHistoryScroll
        view.onEvent = onEvent
        DispatchQueue.main.async {
            view.window?.makeFirstResponder(view)
        }
        return view
    }

    func updateNSView(_ nsView: KeyCaptureNSView, context: Context) {
        nsView.fontSize = fontSize
        nsView.lineHeight = lineHeight
        nsView.rows = rows
        nsView.columns = columns
        nsView.onCopy = onCopy
        nsView.onPaste = onPaste
        nsView.onFind = onFind
        nsView.onHistoryScroll = onHistoryScroll
        nsView.onEvent = onEvent
    }
}

enum TerminalKeyEvent {
    case text(String)
    case enter
    case erase
    case delete
    case eraseEOF
    case tab
    case backTab
    case reset
    case left
    case right
    case up
    case down
    case home
    case end
    case pageUp
    case pageDown
    case attn
    case sysReq
    case moveCursor(row: Int, column: Int)
    case selectionStarted(row: Int, column: Int)
    case selectionChanged(row: Int, column: Int)
    case selectionEnded
    case selectWord(row: Int, column: Int)
    case pf(Int)
}

final class KeyCaptureNSView: NSView {
    var fontSize: CGFloat = 16
    var lineHeight: CGFloat = 20
    var rows: Int = 24
    var columns: Int = 80
    var onCopy: (() -> Void)?
    var onPaste: ((String) -> Void)?
    var onFind: (() -> Void)?
    var onHistoryScroll: ((Int) -> Void)?
    var onEvent: ((TerminalKeyEvent) -> Void)?
    private var selectionAnchor: (row: Int, column: Int)?
    private var mouseDownPoint: NSPoint?
    private var didDragSelection = false
    private var ignoreNextMouseUp = false
    private let selectionDragThreshold: CGFloat = 4
    private var accumulatedScrollX: CGFloat = 0
    private var accumulatedScrollY: CGFloat = 0
    private var lastScrollActionAt = Date.distantPast
    private let trackpadScrollThreshold: CGFloat = 24
    private let scrollActionInterval: TimeInterval = 0.16

    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        DispatchQueue.main.async {
            self.window?.makeFirstResponder(self)
        }
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        let point = convert(event.locationInWindow, from: nil)
        if let position = terminalPosition(for: point) {
            if event.clickCount == 2 {
                ignoreNextMouseUp = true
                selectionAnchor = nil
                mouseDownPoint = nil
                didDragSelection = false
                onEvent?(.selectWord(row: position.row, column: position.column))
                return
            }
            selectionAnchor = position
            mouseDownPoint = point
            didDragSelection = false
        }
    }

    override func mouseDragged(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        guard didDragSelection || hasMovedPastSelectionThreshold(point) else { return }
        guard let position = terminalPosition(for: point) else { return }
        if !didDragSelection, let anchor = selectionAnchor {
            onEvent?(.selectionStarted(row: anchor.row, column: anchor.column))
        }
        didDragSelection = true
        onEvent?(.selectionChanged(row: position.row, column: position.column))
    }

    override func mouseUp(with event: NSEvent) {
        if ignoreNextMouseUp {
            ignoreNextMouseUp = false
            return
        }
        defer {
            selectionAnchor = nil
            mouseDownPoint = nil
            didDragSelection = false
        }

        if didDragSelection {
            onEvent?(.selectionEnded)
        } else {
            let point = convert(event.locationInWindow, from: nil)
            guard let position = terminalPosition(for: point) ?? selectionAnchor else { return }
            onEvent?(.moveCursor(row: position.row, column: position.column))
        }
    }

    override func scrollWheel(with event: NSEvent) {
        window?.makeFirstResponder(self)

        if event.phase == .began {
            accumulatedScrollX = 0
            accumulatedScrollY = 0
        }

        // Momentum can otherwise keep sending PF keys after the fingers have
        // already left the trackpad.
        guard event.momentumPhase == [] else { return }

        accumulatedScrollX += event.scrollingDeltaX
        accumulatedScrollY += event.scrollingDeltaY

        let now = Date()
        guard now.timeIntervalSince(lastScrollActionAt) >= scrollActionInterval else { return }

        let horizontal = abs(accumulatedScrollX)
        let vertical = abs(accumulatedScrollY)
        let threshold = event.hasPreciseScrollingDeltas ? trackpadScrollThreshold : 1

        if vertical >= threshold, vertical >= horizontal {
            if event.modifierFlags.contains(.option) {
                onHistoryScroll?(accumulatedScrollY > 0 ? 1 : -1)
            } else {
                onEvent?(accumulatedScrollY > 0 ? .pageUp : .pageDown)
            }
            accumulatedScrollX = 0
            accumulatedScrollY = 0
            lastScrollActionAt = now
        } else if horizontal >= threshold {
            onEvent?(.pf(accumulatedScrollX > 0 ? 10 : 11))
            accumulatedScrollX = 0
            accumulatedScrollY = 0
            lastScrollActionAt = now
        }

        if event.phase == .ended || event.phase == .cancelled {
            accumulatedScrollX = 0
            accumulatedScrollY = 0
        }
    }

    override func keyDown(with event: NSEvent) {
        if event.modifierFlags.contains(.command) {
            if event.charactersIgnoringModifiers?.lowercased() == "c" {
                onCopy?()
                return
            }
            if event.charactersIgnoringModifiers?.lowercased() == "v" {
                if let text = NSPasteboard.general.string(forType: .string), !text.isEmpty {
                    onPaste?(text)
                }
                return
            }
            if event.charactersIgnoringModifiers?.lowercased() == "f" {
                onFind?()
                return
            }
            super.keyDown(with: event)
            return
        }

        if let mapped = mappedEvent(for: event) {
            onEvent?(mapped)
            return
        }

        guard let characters = event.characters, !characters.isEmpty else { return }
        let scalars = characters.unicodeScalars
        guard scalars.allSatisfy({ !CharacterSet.controlCharacters.contains($0) }) else { return }
        onEvent?(.text(characters))
    }

    private func mappedEvent(for event: NSEvent) -> TerminalKeyEvent? {
        switch event.keyCode {
        case 36, 76:
            return .enter
        case 51:
            return .erase
        case 117 where event.modifierFlags.contains(.option):
            return .eraseEOF
        case 117:
            return .delete
        case 48:
            return event.modifierFlags.contains(.shift) ? .backTab : .tab
        case 53:
            return .reset
        case 123 where event.modifierFlags.contains(.control):
            return .attn
        case 124 where event.modifierFlags.contains(.control):
            return .sysReq
        case 123:
            return .left
        case 124:
            return .right
        case 125:
            return .down
        case 126:
            return .up
        case 115:
            return .home
        case 119:
            return .end
        case 116:
            return .pageUp
        case 121:
            return .pageDown
        case 122:
            return .pf(event.modifierFlags.contains(.shift) ? 13 : 1)
        case 120:
            return .pf(event.modifierFlags.contains(.shift) ? 14 : 2)
        case 99:
            return .pf(event.modifierFlags.contains(.shift) ? 15 : 3)
        case 118:
            return .pf(event.modifierFlags.contains(.shift) ? 16 : 4)
        case 96:
            return .pf(event.modifierFlags.contains(.shift) ? 17 : 5)
        case 97:
            return .pf(event.modifierFlags.contains(.shift) ? 18 : 6)
        case 98:
            return .pf(event.modifierFlags.contains(.shift) ? 19 : 7)
        case 100:
            return .pf(event.modifierFlags.contains(.shift) ? 20 : 8)
        case 101:
            return .pf(event.modifierFlags.contains(.shift) ? 21 : 9)
        case 109:
            return .pf(event.modifierFlags.contains(.shift) ? 22 : 10)
        case 103:
            return .pf(event.modifierFlags.contains(.shift) ? 23 : 11)
        case 111:
            return .pf(event.modifierFlags.contains(.shift) ? 24 : 12)
        default:
            return nil
        }
    }

    private func terminalPosition(for point: NSPoint) -> (row: Int, column: Int)? {
        let cellWidth = TerminalMetrics.cellWidth(fontSize)
        let gridWidth = CGFloat(columns) * cellWidth
        let gridHeight = CGFloat(rows) * lineHeight
        let originX = max(0, (bounds.width - gridWidth) / 2)
        let originY = max(0, (bounds.height - gridHeight) / 2)
        let x = point.x - originX
        let y = bounds.height - point.y - originY
        guard x >= 0, y >= 0, x < gridWidth, y < gridHeight else { return nil }
        return (
            row: min(rows - 1, max(0, Int(y / lineHeight))),
            column: min(columns - 1, max(0, Int(x / cellWidth)))
        )
    }

    private func hasMovedPastSelectionThreshold(_ point: NSPoint) -> Bool {
        guard let mouseDownPoint else { return false }
        return abs(point.x - mouseDownPoint.x) >= selectionDragThreshold ||
            abs(point.y - mouseDownPoint.y) >= selectionDragThreshold
    }
}
