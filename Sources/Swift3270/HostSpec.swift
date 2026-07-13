import Foundation

struct HostSpec {
    let host: String
    let port: Int
    let useTLS: Bool
    let acceptHostnameMismatch: Bool
    let acceptAnyCertificate: Bool
    let luName: String

    static func parse(_ value: String) -> HostSpec {
        var text = value.trimmingCharacters(in: .whitespacesAndNewlines)
        var useTLS = false
        var acceptHostnameMismatch = false
        var acceptAnyCertificate = false

        while text.count >= 2 {
            let prefix = String(text.prefix(2))
            if prefix == "L:" {
                useTLS = true
                text.removeFirst(2)
            } else if prefix == "Y:" {
                acceptHostnameMismatch = true
                text.removeFirst(2)
            } else if prefix == "A:" {
                acceptAnyCertificate = true
                text.removeFirst(2)
            } else {
                break
            }
        }

        if let acceptIndex = text.firstIndex(of: "=") {
            text = String(text[..<acceptIndex])
        }

        var luName = ""
        if let luIndex = text.firstIndex(of: "@") {
            luName = String(text[..<luIndex])
            text = String(text[text.index(after: luIndex)...])
        }

        if let colonIndex = text.lastIndex(of: ":"),
           let port = Int(text[text.index(after: colonIndex)...]) {
            return HostSpec(
                host: String(text[..<colonIndex]),
                port: port,
                useTLS: useTLS,
                acceptHostnameMismatch: acceptHostnameMismatch,
                acceptAnyCertificate: acceptAnyCertificate,
                luName: luName
            )
        }

        return HostSpec(
            host: text,
            port: 23,
            useTLS: useTLS,
            acceptHostnameMismatch: acceptHostnameMismatch,
            acceptAnyCertificate: acceptAnyCertificate,
            luName: luName
        )
    }

    static func build(
        host: String,
        port: Int,
        useTLS: Bool,
        acceptHostnameMismatch: Bool,
        acceptAnyCertificate: Bool,
        luName: String = ""
    ) -> String {
        var prefix = ""
        if useTLS { prefix += "L:" }
        if acceptHostnameMismatch { prefix += "Y:" }
        if acceptAnyCertificate { prefix += "A:" }

        let trimmedLU = luName.trimmingCharacters(in: .whitespacesAndNewlines)
        let target = trimmedLU.isEmpty ? host : "\(trimmedLU)@\(host)"
        return "\(prefix)\(target):\(port)"
    }
}
