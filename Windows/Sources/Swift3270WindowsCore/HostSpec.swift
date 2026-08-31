import Foundation

public struct HostSpec: Equatable, Sendable {
    public let host: String
    public let port: Int
    public let useTLS: Bool
    public let luName: String

    public init(host: String, port: Int, useTLS: Bool, luName: String = "") {
        self.host = host
        self.port = port
        self.useTLS = useTLS
        self.luName = luName
    }

    public var ws3270Target: String {
        let trimmedHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedLU = luName.trimmingCharacters(in: .whitespacesAndNewlines)
        let target = trimmedLU.isEmpty ? trimmedHost : "\(trimmedLU)@\(trimmedHost)"
        return "\(useTLS ? "L:" : "")\(target):\(port)"
    }
}
