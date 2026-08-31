import Foundation

struct TerminalSelection: Equatable {
    var anchor: TerminalCursor
    var focus: TerminalCursor
    var isRectangular = true

    var normalized: (start: TerminalCursor, end: TerminalCursor) {
        if !isRectangular,
           anchor.row < focus.row || (anchor.row == focus.row && anchor.column <= focus.column) {
            return (anchor, focus)
        } else if !isRectangular {
            return (focus, anchor)
        }
        return (
            TerminalCursor(
                row: min(anchor.row, focus.row),
                column: min(anchor.column, focus.column)
            ),
            TerminalCursor(
                row: max(anchor.row, focus.row),
                column: max(anchor.column, focus.column)
            )
        )
    }

    func contains(row: Int, column: Int) -> Bool {
        let range = normalized
        if row < range.start.row || row > range.end.row {
            return false
        }
        if isRectangular {
            return column >= range.start.column && column <= range.end.column
        }
        if row == range.start.row && column < range.start.column { return false }
        if row == range.end.row && column > range.end.column { return false }
        return true
    }
}
