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
