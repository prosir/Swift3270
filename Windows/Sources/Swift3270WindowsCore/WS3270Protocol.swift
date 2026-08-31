import Foundation

public struct WS3270Status: Equatable, Sendable {
    public enum KeyboardState: String, Sendable {
        case unlocked = "U"
        case locked = "L"
        case operatorError = "E"
    }

    public let keyboard: KeyboardState
    public let connected: Bool
    public let model: Int
    public let rows: Int
    public let columns: Int
    public let cursorRow: Int
    public let cursorColumn: Int

    public init?(line: String) {
        let fields = line.split(separator: " ", omittingEmptySubsequences: true)
        guard fields.count >= 12,
              let keyboard = KeyboardState(rawValue: String(fields[0])),
              let model = Int(fields[5]),
              let rows = Int(fields[6]),
              let columns = Int(fields[7]),
              let cursorRow = Int(fields[8]),
              let cursorColumn = Int(fields[9]) else {
            return nil
        }
        self.keyboard = keyboard
        connected = fields[3].starts(with: "C(")
        self.model = model
        self.rows = rows
        self.columns = columns
        self.cursorRow = cursorRow
        self.cursorColumn = cursorColumn
    }
}

public struct WS3270Response: Equatable, Sendable {
    public let succeeded: Bool
    public let data: [String]
    public let status: WS3270Status?

    public init(succeeded: Bool, data: [String], status: WS3270Status?) {
        self.succeeded = succeeded
        self.data = data
        self.status = status
    }
}

public struct WS3270ResponseParser: Sendable {
    private var data: [String] = []
    private var status: WS3270Status?

    public init() {}

    public mutating func consume(_ rawLine: String) -> WS3270Response? {
        let line = rawLine.hasSuffix("\r") ? String(rawLine.dropLast()) : rawLine
        if line == "ok" || line == "error" {
            defer {
                data.removeAll(keepingCapacity: true)
                status = nil
            }
            return WS3270Response(succeeded: line == "ok", data: data, status: status)
        }
        if let parsedStatus = WS3270Status(line: line) {
            status = parsedStatus
        } else if line.hasPrefix("data: ") {
            data.append(String(line.dropFirst(6)))
        } else if line.hasPrefix("data:") {
            data.append(String(line.dropFirst(5)))
        } else if !line.isEmpty {
            data.append(line)
        }
        return nil
    }
}

public enum WS3270Action {
    public static func string(_ value: String) -> String {
        let escaped = value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
        return "String(\"\(escaped)\")"
    }
}
