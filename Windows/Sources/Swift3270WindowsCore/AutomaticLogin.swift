import Foundation

public struct AutomaticLoginConfiguration: Equatable, Sendable {
    public var applicationCode: String
    public var userID: String
    public var password: String

    public init(applicationCode: String, userID: String, password: String) {
        self.applicationCode = applicationCode.trimmingCharacters(in: .whitespacesAndNewlines)
        self.userID = userID.trimmingCharacters(in: .whitespacesAndNewlines)
        self.password = password
    }
}

public enum AutomaticLoginCommand: Equatable, Sendable {
    case text(String)
    case tab
    case enter

    public var ws3270Action: String {
        switch self {
        case .text(let value): WS3270Action.string(value)
        case .tab: "Tab"
        case .enter: "Enter"
        }
    }
}

public struct AutomaticLoginPlan: Equatable, Sendable {
    public let key: String
    public let description: String
    public let commands: [AutomaticLoginCommand]

    public init(key: String, description: String, commands: [AutomaticLoginCommand]) {
        self.key = key
        self.description = description
        self.commands = commands
    }
}

public enum AutomaticLoginDetector {
    public static func plan(
        for screen: TerminalScreen,
        configuration: AutomaticLoginConfiguration
    ) -> AutomaticLoginPlan? {
        let upperLines = screen.lines.map { $0.uppercased() }
        let upperScreen = upperLines.joined(separator: "\n")

        if upperScreen.contains("ENTER USER-ID AND PASSWORD OR PASSWORD PHRASE"),
           upperScreen.contains("PASSWORD/PHRASE"),
           let row = upperLines.firstIndex(where: { $0.contains("USER-ID") && $0.contains("==>") }),
           row == screen.cursor.row,
           !configuration.userID.isEmpty,
           !configuration.password.isEmpty {
            return AutomaticLoginPlan(
                key: "cics|\(row)",
                description: "CICS userid en password",
                commands: [
                    .text(configuration.userID),
                    .tab,
                    .text(configuration.password),
                    .enter
                ]
            )
        }

        if upperScreen.contains("ENTER USER-ID AND PASSWORD OR PASSWORD PHRASE"),
           let row = upperLines.firstIndex(where: { $0.contains("PASSWORD/PHRASE") && $0.contains("==>") }),
           row == screen.cursor.row,
           !configuration.password.isEmpty {
            return AutomaticLoginPlan(
                key: "cics-password|\(row)",
                description: "CICS password",
                commands: [.text(configuration.password), .enter]
            )
        }

        let candidates = upperLines.enumerated().compactMap { row, line -> Candidate? in
            if line.contains("KIES UW TOEPASSING") {
                return Candidate(
                    row: row,
                    kind: "application",
                    description: "toepassing",
                    value: configuration.applicationCode
                )
            }
            if line.contains("ENTER USERID") || line.contains("ENTER USER-ID") {
                return Candidate(row: row, kind: "userid", description: "userid", value: configuration.userID)
            }
            if line.contains("PASSPHRASE")
                || line.contains("PASS PHRASE")
                || line.contains("ENTER PASSWORD") {
                return Candidate(row: row, kind: "password", description: "password", value: configuration.password)
            }
            return nil
        }

        guard let candidate = candidates.min(by: {
            abs($0.row - screen.cursor.row) < abs($1.row - screen.cursor.row)
        }),
        isNearCursor(row: candidate.row, cursorRow: screen.cursor.row),
        !candidate.value.isEmpty else {
            return nil
        }

        return AutomaticLoginPlan(
            key: "\(candidate.kind)|\(candidate.row)",
            description: candidate.description,
            commands: [.text(candidate.value), .enter]
        )
    }

    private static func isNearCursor(row: Int, cursorRow: Int) -> Bool {
        abs(row - cursorRow) <= 3
    }

    private struct Candidate {
        let row: Int
        let kind: String
        let description: String
        let value: String
    }
}
