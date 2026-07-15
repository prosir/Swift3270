import Foundation

struct TerminalSelection: Equatable {
    var anchor: TerminalCursor
    var focus: TerminalCursor

    var normalized: (start: TerminalCursor, end: TerminalCursor) {
        if anchor.row < focus.row || (anchor.row == focus.row && anchor.column <= focus.column) {
            return (anchor, focus)
        }
        return (focus, anchor)
    }

    func contains(row: Int, column: Int) -> Bool {
        let range = normalized
        if row < range.start.row || row > range.end.row {
            return false
        }
        if row == range.start.row && column < range.start.column {
            return false
        }
        if row == range.end.row && column > range.end.column {
            return false
        }
        return true
    }
}
