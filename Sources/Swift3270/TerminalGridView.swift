import AppKit
import SwiftUI

struct TerminalGridView: View {
    let cells: [[TerminalCell]]
    let fontSize: CGFloat
    let lineHeight: CGFloat
    let cursor: TerminalCursor
    let theme: TerminalTheme
    let selection: TerminalSelection?

    var body: some View {
        let cellWidth = TerminalMetrics.cellWidth(fontSize)
        let rowCount = max(1, cells.count)
        let columnCount = max(1, cells.map(\.count).max() ?? 80)
        let gridWidth = CGFloat(columnCount) * cellWidth
        let gridHeight = CGFloat(rowCount) * lineHeight

        Canvas { context, _ in
            let rows = normalizedCells
            for row in rows.indices {
                for cell in rows[row] {
                    let column = cell.column
                    let isCursor = cursor.row == row && cursor.column == column
                    let isSelected = selection?.contains(row: row, column: column) == true
                    let rect = CGRect(
                        x: 6 + CGFloat(column) * cellWidth,
                        y: 6 + CGFloat(row) * lineHeight,
                        width: cellWidth,
                        height: lineHeight
                    )

                    let background = background(for: cell, isCursor: isCursor, isSelected: isSelected)
                    context.fill(Path(rect), with: .color(background))

                    var text = context.resolve(
                        Text(String(cell.character))
                            .font(.system(size: fontSize, weight: .regular, design: .monospaced))
                    )
                    text.shading = .color(textColor(for: cell, isCursor: isCursor, isSelected: isSelected))
                    context.draw(text, at: CGPoint(x: rect.midX, y: rect.midY), anchor: .center)

                    if cell.hasGraphicRendition("underscore") || cell.hasGraphicRendition("underline") {
                        var underline = Path()
                        underline.move(to: CGPoint(x: rect.minX + 1, y: rect.maxY - 2))
                        underline.addLine(to: CGPoint(x: rect.maxX - 1, y: rect.maxY - 2))
                        context.stroke(underline, with: .color(theme.palette.underscore), lineWidth: 1)
                    }
                }
            }
        }
        .frame(width: gridWidth + 12, height: gridHeight + 12)
        .background(theme.palette.background)
        .border(theme.palette.border)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    private var normalizedCells: [[TerminalCell]] {
        guard !cells.isEmpty, let columns = cells.first?.count, columns > 0,
              cells.allSatisfy({ $0.count == columns }) else {
            return (0..<24).map { row in
                (0..<80).map { column in
                    TerminalCell.blank(row: row, column: column, foreground: "blue", background: "neutralBlack")
                }
            }
        }

        return cells
    }

    private func textColor(for cell: TerminalCell, isCursor: Bool, isSelected: Bool) -> Color {
        if isCursor {
            return theme.palette.cursorText
        }
        if isSelected {
            return Color.black
        }
        return foreground(for: cell)
    }

    private func foreground(for cell: TerminalCell) -> Color {
        let mapped = theme.palette.foreground(named: cell.foreground)
        if cell.hasGraphicRendition("reverse") {
            return theme.palette.background(named: cell.background) ?? theme.palette.background
        }
        return mapped ?? theme.palette.normal
    }

    private func background(for cell: TerminalCell, isCursor: Bool, isSelected: Bool) -> Color {
        if isCursor {
            return theme.palette.cursor
        }

        if isSelected {
            return Color(red: 0.74, green: 0.90, blue: 1.00)
        }

        if cell.hasGraphicRendition("reverse") {
            return theme.palette.foreground(named: cell.foreground) ?? theme.palette.normal
        }

        return theme.palette.background(named: cell.background) ?? Color.clear
    }
}

private extension TerminalCell {
    func hasGraphicRendition(_ value: String) -> Bool {
        highlighting?
            .split(separator: ",")
            .contains { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == value } == true
    }
}

struct TerminalPalette {
    let background: Color
    let border: Color
    let normal: Color
    let status: Color
    let underscore: Color
    let cursor: Color
    let cursorText: Color

    func foreground(named name: String?) -> Color? {
        guard let name else { return nil }
        switch TerminalColorName.normalize(name) {
        case "blue": return Color(red: 0.40, green: 0.72, blue: 1.00)
        case "red": return Color(red: 1.00, green: 0.38, blue: 0.34)
        case "pink", "magenta": return Color(red: 1.00, green: 0.48, blue: 0.98)
        case "green": return Color(red: 0.55, green: 1.00, blue: 0.42)
        case "turquoise", "cyan": return Color(red: 0.38, green: 1.00, blue: 1.00)
        case "yellow": return Color(red: 1.00, green: 0.92, blue: 0.26)
        case "neutralwhite", "white": return Color(red: 0.98, green: 1.00, blue: 0.98)
        case "black", "neutralblack": return Color(red: 0.64, green: 0.70, blue: 0.76)
        default: return nil
        }
    }

    func background(named name: String?) -> Color? {
        guard let name else { return nil }
        switch TerminalColorName.normalize(name) {
        case "neutralblack", "black": return background
        case "blue": return Color(red: 0.02, green: 0.08, blue: 0.24)
        case "red": return Color(red: 0.26, green: 0.03, blue: 0.03)
        case "pink", "magenta": return Color(red: 0.24, green: 0.03, blue: 0.22)
        case "green": return Color(red: 0.02, green: 0.18, blue: 0.04)
        case "turquoise", "cyan": return Color(red: 0.02, green: 0.18, blue: 0.20)
        case "yellow": return Color(red: 0.24, green: 0.20, blue: 0.03)
        case "neutralwhite", "white": return Color(red: 0.92, green: 0.94, blue: 0.90)
        default: return nil
        }
    }
}

private enum TerminalColorName {
    static func normalize(_ name: String) -> String {
        name
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: " ", with: "")
            .lowercased()
    }
}

enum TerminalTheme: String, CaseIterable, Identifiable {
    case ibm3279
    case greenScreen
    case reverse
    case bright

    var id: String { rawValue }

    var label: String {
        switch self {
        case .ibm3279: return "default"
        case .greenScreen: return "GreenScreen"
        case .reverse: return "reverse"
        case .bright: return "bright"
        }
    }

    var palette: TerminalPalette {
        switch self {
        case .ibm3279:
            return TerminalPalette(
                background: Color(red: 0.005, green: 0.008, blue: 0.012),
                border: Color(red: 0.22, green: 0.30, blue: 0.36),
                normal: Color(red: 0.40, green: 0.72, blue: 1.00),
                status: Color(red: 0.24, green: 0.92, blue: 1.00),
                underscore: Color(red: 0.98, green: 1.00, blue: 0.98),
                cursor: Color(red: 0.82, green: 1.00, blue: 0.48),
                cursorText: Color.black
            )
        case .greenScreen:
            return TerminalPalette(
                background: Color(red: 0.02, green: 0.03, blue: 0.02),
                border: Color(red: 0.10, green: 0.24, blue: 0.12),
                normal: Color(red: 0.13, green: 0.78, blue: 0.13),
                status: Color(red: 0.44, green: 1.00, blue: 0.44),
                underscore: Color(red: 0.44, green: 1.00, blue: 0.44),
                cursor: Color(red: 0.30, green: 0.95, blue: 0.30),
                cursorText: Color.black
            )
        case .reverse:
            return TerminalPalette(
                background: Color(red: 0.86, green: 0.88, blue: 0.84),
                border: Color(red: 0.28, green: 0.30, blue: 0.28),
                normal: Color(red: 0.02, green: 0.17, blue: 0.04),
                status: Color(red: 0.00, green: 0.23, blue: 0.54),
                underscore: Color(red: 0.08, green: 0.08, blue: 0.08),
                cursor: Color(red: 0.02, green: 0.17, blue: 0.04),
                cursorText: Color.white
            )
        case .bright:
            return TerminalPalette(
                background: Color.black,
                border: Color(red: 0.24, green: 0.30, blue: 0.27),
                normal: Color(red: 0.78, green: 1.00, blue: 0.48),
                status: Color(red: 0.45, green: 1.00, blue: 1.00),
                underscore: Color.white,
                cursor: Color(red: 0.95, green: 1.00, blue: 0.55),
                cursorText: Color.black
            )
        }
    }
}

enum TerminalMetrics {
    private static let baseFontSize: CGFloat = 16
    private static let minimumFontSize: CGFloat = 10
    private static let maximumFitFontSize: CGFloat = 38
    private static let terminalHorizontalChrome: CGFloat = 36
    private static let terminalVerticalChrome: CGFloat = 36
    private static let cellWidthRatio: CGFloat = 0.62
    private static let lineHeightRatio: CGFloat = 1.28

    static func fontSize(container: CGSize, columns: Int, rows: Int, mode: ScaleMode, manualScale: Double) -> CGFloat {
        if mode == .manual {
            return snap(CGFloat(baseFontSize * manualScale))
        }

        let columns = max(1, columns)
        let rows = max(1, rows)
        let availableWidth = max(1, container.width - terminalHorizontalChrome)
        let availableHeight = max(1, container.height - terminalVerticalChrome)
        let candidateByWidth = availableWidth / CGFloat(columns) / cellWidthRatio
        let candidateByHeight = availableHeight / CGFloat(rows) / lineHeightRatio
        let fitted = min(maximumFitFontSize, max(minimumFontSize, min(candidateByWidth, candidateByHeight)))
        return snap(fitted)
    }

    static func cellWidth(_ fontSize: CGFloat) -> CGFloat {
        snap(fontSize * cellWidthRatio)
    }

    static func lineHeight(_ fontSize: CGFloat) -> CGFloat {
        snap(fontSize * lineHeightRatio)
    }

    static func lineHeight(
        containerHeight: CGFloat,
        rows: Int,
        fontSize: CGFloat,
        mode: ScaleMode
    ) -> CGFloat {
        guard mode == .fit else { return lineHeight(fontSize) }
        let availableHeight = max(1, containerHeight - 32)
        return snap(availableHeight / CGFloat(max(1, rows)))
    }

    private static func snap(_ value: CGFloat) -> CGFloat {
        let scale = NSScreen.main?.backingScaleFactor ?? 2
        return (value * scale).rounded(.down) / scale
    }
}
