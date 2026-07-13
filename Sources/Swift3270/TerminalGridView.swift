import SwiftUI

struct TerminalGridView: View {
    let cells: [[TerminalCell]]
    let fontSize: CGFloat
    let cursor: TerminalCursor
    let theme: TerminalTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(normalizedCells.enumerated()), id: \.offset) { row, rowCells in
                TerminalLineView(cells: rowCells, row: row, fontSize: fontSize, cursor: cursor, theme: theme)
                    .frame(height: TerminalMetrics.lineHeight(fontSize))
            }
        }
        .padding(6)
        .background(theme.palette.background)
        .border(theme.palette.border)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    private var normalizedCells: [[TerminalCell]] {
        guard cells.count == 24, cells.allSatisfy({ $0.count == 80 }) else {
            return (0..<24).map { row in
                (0..<80).map { column in
                    TerminalCell.blank(row: row, column: column, foreground: "blue", background: "neutralBlack")
                }
            }
        }

        return cells
    }
}

private struct TerminalLineView: View {
    let cells: [TerminalCell]
    let row: Int
    let fontSize: CGFloat
    let cursor: TerminalCursor
    let theme: TerminalTheme

    var body: some View {
        HStack(spacing: 0) {
            ForEach(cells) { cell in
                let column = cell.column
                let isCursor = cursor.row == row && cursor.column == column

                Text(String(cell.character))
                    .font(.system(size: fontSize, weight: .regular, design: .monospaced))
                    .foregroundStyle(isCursor ? theme.palette.cursorText : foreground(for: cell))
                    .frame(width: TerminalMetrics.cellWidth(fontSize), height: TerminalMetrics.lineHeight(fontSize))
                    .background(background(for: cell, isCursor: isCursor))
            }
        }
    }

    private func foreground(for cell: TerminalCell) -> Color {
        let mapped = theme.palette.foreground(named: cell.foreground)
        if cell.hasGraphicRendition("reverse") {
            return theme.palette.background(named: cell.background) ?? theme.palette.background
        }
        return mapped ?? theme.palette.normal
    }

    private func background(for cell: TerminalCell, isCursor: Bool) -> Color {
        if isCursor {
            return theme.palette.cursor
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
    static func fontSize(container: CGSize, columns: Int, rows: Int, mode: ScaleMode, manualScale: Double) -> CGFloat {
        if mode == .manual {
            return CGFloat(16 * manualScale)
        }

        let horizontalPadding: CGFloat = 64
        let verticalPadding: CGFloat = 72
        let candidateByWidth = max(8, (container.width - horizontalPadding) / CGFloat(columns) / 0.62)
        let candidateByHeight = max(8, (container.height - verticalPadding) / CGFloat(rows) / 1.28)
        return min(24, max(10, min(candidateByWidth, candidateByHeight)))
    }

    static func cellWidth(_ fontSize: CGFloat) -> CGFloat {
        fontSize * 0.62
    }

    static func lineHeight(_ fontSize: CGFloat) -> CGFloat {
        fontSize * 1.28
    }
}
