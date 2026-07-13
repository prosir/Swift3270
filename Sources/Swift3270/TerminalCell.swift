import Foundation

struct TerminalCell: Equatable, Identifiable {
    var id: Int { row * 1_000 + column }
    var row: Int
    var column: Int
    var character: Character
    var foreground: String?
    var background: String?
    var highlighting: String?

    static func blank(row: Int, column: Int, foreground: String? = nil, background: String? = nil) -> TerminalCell {
        TerminalCell(
            row: row,
            column: column,
            character: " ",
            foreground: foreground,
            background: background,
            highlighting: nil
        )
    }
}
