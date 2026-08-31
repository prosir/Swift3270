import Foundation

public struct TerminalCursor: Equatable, Sendable {
    public var row: Int
    public var column: Int

    public init(row: Int, column: Int) {
        self.row = row
        self.column = column
    }
}

public struct TerminalScreen: Equatable, Sendable {
    public var rows: Int
    public var columns: Int
    public var lines: [String]
    public var cursor: TerminalCursor

    public init(rows: Int = 24, columns: Int = 80, lines: [String] = [], cursor: TerminalCursor = .init(row: 0, column: 0)) {
        self.rows = rows
        self.columns = columns
        self.lines = Self.normalize(lines, rows: rows, columns: columns)
        self.cursor = cursor
    }

    public var text: String {
        lines.joined(separator: "\n")
    }

    public mutating func update(lines: [String], status: WS3270Status?) {
        if let status {
            rows = status.rows
            columns = status.columns
            cursor = .init(row: status.cursorRow, column: status.cursorColumn)
        }
        self.lines = Self.normalize(lines, rows: rows, columns: columns)
    }

    private static func normalize(_ lines: [String], rows: Int, columns: Int) -> [String] {
        let normalized = lines.prefix(rows).map { line in
            String(line.padding(toLength: columns, withPad: " ", startingAt: 0).prefix(columns))
        }
        return normalized + Array(repeating: String(repeating: " ", count: columns), count: max(0, rows - normalized.count))
    }
}
