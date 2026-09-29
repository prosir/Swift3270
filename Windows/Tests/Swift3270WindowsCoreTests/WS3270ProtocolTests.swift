import Testing
@testable import Swift3270WindowsCore

@Test func parsesScreenResponseAndStatus() {
    var parser = WS3270ResponseParser()
    #expect(parser.consume("data: READY") == nil)
    #expect(parser.consume("data: ") == nil)
    #expect(parser.consume("U F U C(mainframe:23) I 4 43 80 3 12 0x0 0.001") == nil)
    let response = parser.consume("ok")

    #expect(response?.succeeded == true)
    #expect(response?.data == ["READY", ""])
    #expect(response?.status?.rows == 43)
    #expect(response?.status?.columns == 80)
    #expect(response?.status?.cursorRow == 3)
    #expect(response?.status?.cursorColumn == 12)
}

@Test func buildsSafeStringAction() {
    #expect(WS3270Action.string("a\"b\\c") == "String(\"a\\\"b\\\\c\")")
}

@Test func buildsTLSHostWithLU() {
    let host = HostSpec(host: "example.test", port: 992, useTLS: true, luName: "LU01")
    #expect(host.ws3270Target == "L:LU01@example.test:992")
}

@Test func detectsSeparateAutomaticLoginPrompts() {
    let configuration = AutomaticLoginConfiguration(
        applicationCode: "TSOT",
        userID: "USER01",
        password: "secret"
    )
    let applicationScreen = TerminalScreen(
        rows: 24,
        columns: 80,
        lines: ["Kies uw toepassing ==>"],
        cursor: .init(row: 0, column: 24)
    )
    let userScreen = TerminalScreen(
        rows: 24,
        columns: 80,
        lines: ["ENTER USERID -"],
        cursor: .init(row: 0, column: 16)
    )
    let passwordScreen = TerminalScreen(
        rows: 24,
        columns: 80,
        lines: ["ENTER PASSWORD:"],
        cursor: .init(row: 0, column: 16)
    )

    #expect(AutomaticLoginDetector.plan(for: applicationScreen, configuration: configuration)?.commands == [.text("TSOT"), .enter])
    #expect(AutomaticLoginDetector.plan(for: userScreen, configuration: configuration)?.commands == [.text("USER01"), .enter])
    #expect(AutomaticLoginDetector.plan(for: passwordScreen, configuration: configuration)?.commands == [.text("secret"), .enter])
}

@Test func detectsCombinedCICSCredentialsScreen() {
    let configuration = AutomaticLoginConfiguration(
        applicationCode: "CICS",
        userID: "USER01",
        password: "secret"
    )
    let screen = TerminalScreen(
        rows: 24,
        columns: 80,
        lines: [
            "Enter user-ID and password or password phrase:",
            "User-ID             ==>",
            "Password/phrase     ==>",
            "Language            ==> E"
        ],
        cursor: .init(row: 1, column: 24)
    )

    let plan = AutomaticLoginDetector.plan(for: screen, configuration: configuration)
    #expect(plan?.commands == [.text("USER01"), .tab, .text("secret"), .enter])
}

@Test func combinedCICSScreenCanFillOnlyPasswordWhenCursorIsThere() {
    let configuration = AutomaticLoginConfiguration(
        applicationCode: "CICS",
        userID: "USER01",
        password: "secret"
    )
    let screen = TerminalScreen(
        rows: 24,
        columns: 80,
        lines: [
            "Enter user-ID and password or password phrase:",
            "User-ID             ==> USER01",
            "Password/phrase     ==>"
        ],
        cursor: .init(row: 2, column: 24)
    )

    let plan = AutomaticLoginDetector.plan(for: screen, configuration: configuration)
    #expect(plan?.commands == [.text("secret"), .enter])
}

@Test func automaticLoginIgnoresDistantPromptAndMissingValues() {
    let missingPassword = AutomaticLoginConfiguration(applicationCode: "TSOT", userID: "USER01", password: "")
    let screen = TerminalScreen(
        rows: 24,
        columns: 80,
        lines: ["ENTER PASSWORD:"],
        cursor: .init(row: 8, column: 0)
    )

    #expect(AutomaticLoginDetector.plan(for: screen, configuration: missingPassword) == nil)
}

@Test func detectsUniqueCOBOLCompilerErrors() {
    let text = """
    IGYPS2121-S First error
    igyps2121-s repeated
    IGYDS1159-E Second error
    NOT-A-COMPILER-CODE
    """

    #expect(COBOLErrorDetector.codes(in: text) == ["IGYPS2121-S", "IGYDS1159-E"])
}

@Test func normalizesUnicodeScreenByCharacters() {
    let screen = TerminalScreen(rows: 2, columns: 5, lines: ["één", "123456"])

    #expect(screen.lines == ["één  ", "12345"])
}
