import Foundation

public enum COBOLErrorDetector {
    public static func codes(in text: String, limit: Int = 10) -> [String] {
        guard limit > 0 else { return [] }
        let pattern = #"\bIGY[A-Z0-9]{2}[0-9]{4}-[IWESU]\b"#
        guard let expression = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return []
        }

        let nsText = text as NSString
        var seen = Set<String>()
        var result: [String] = []
        for match in expression.matches(in: text, range: NSRange(location: 0, length: nsText.length)) {
            let code = nsText.substring(with: match.range).uppercased()
            if seen.insert(code).inserted {
                result.append(code)
                if result.count == limit { break }
            }
        }
        return result
    }
}
