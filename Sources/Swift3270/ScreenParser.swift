import Foundation

enum ScreenParser {
    static func lines(from response: String, rows: Int, columns: Int) -> [String] {
        let payload = response
            .components(separatedBy: .newlines)
            .filter { !$0.hasPrefix("data:") && $0 != "ok" && !$0.hasPrefix("U ") }

        let screen = payload.joined(separator: "\n")
        let split = screen.components(separatedBy: .newlines)

        if split.count >= rows {
            return Array(split.prefix(rows)).map { normalize($0, columns: columns) }
        }

        let padded = split + Array(repeating: "", count: max(0, rows - split.count))
        return padded.prefix(rows).map { normalize($0, columns: columns) }
    }

    static func cursor(from response: String) -> TerminalCursor? {
        let fields = response
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }

        guard fields.count >= 3,
              let row = Int(fields[fields.count - 2]),
              let column = Int(fields[fields.count - 1]) else {
            return nil
        }

        return TerminalCursor(row: max(0, row - 1), column: max(0, column - 1))
    }

    private static func normalize(_ line: String, columns: Int) -> String {
        String(line.padding(toLength: columns, withPad: " ", startingAt: 0).prefix(columns))
    }
}
