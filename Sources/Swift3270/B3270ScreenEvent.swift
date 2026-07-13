import Foundation

struct B3270ScreenEvent {
    var cursor: TerminalCursor?
    var clearsScreen = false
    var eraseForeground: String?
    var eraseBackground: String?
    var rowChanges: [RowChange]
    var hasExplicitAttributes = false

    struct RowChange {
        var row: Int
        var changes: [CellChange]
    }

    struct CellChange {
        var column: Int
        var text: String?
        var count: Int?
        var foreground: String?
        var background: String?
        var highlighting: String?
    }

    init?(object: [String: Any]) {
        if let erase = object["erase"] as? [String: Any] {
            clearsScreen = true
            eraseForeground = erase["fg"] as? String
            eraseBackground = erase["bg"] as? String
            rowChanges = []
            return
        }

        guard let screen = object["screen"] as? [String: Any] else { return nil }

        if let cursorObject = screen["cursor"] as? [String: Any],
           let enabled = cursorObject["enabled"] as? Bool,
           enabled,
           let row = cursorObject["row"] as? Int,
           let column = cursorObject["column"] as? Int {
            cursor = TerminalCursor(row: max(0, row - 1), column: max(0, column - 1))
        }

        rowChanges = []
        var explicitAttributesSeen = false
        if let rows = screen["rows"] as? [[String: Any]] {
            rowChanges = rows.compactMap { rowObject in
                guard let row = rowObject["row"] as? Int,
                      let changes = rowObject["changes"] as? [[String: Any]] else {
                    return nil
                }

                let rowForeground = rowObject.firstString(for: ["fg", "foreground", "color"])
                let rowBackground = rowObject.firstString(for: ["bg", "background"])
                let rowHighlighting = rowObject.firstString(for: ["gr", "highlighting", "highlight"])
                if rowForeground != nil || rowBackground != nil || rowHighlighting != nil {
                    explicitAttributesSeen = true
                }

                return RowChange(
                    row: max(0, row - 1),
                    changes: changes.compactMap { changeObject in
                        guard let column = changeObject["column"] as? Int else {
                            return nil
                        }
                        let text = changeObject["text"] as? String
                        let count = changeObject["count"] as? Int
                        guard text != nil || count != nil else { return nil }
                        let foreground = changeObject.firstString(for: ["fg", "foreground", "color"]) ?? rowForeground
                        let background = changeObject.firstString(for: ["bg", "background"]) ?? rowBackground
                        let highlighting = changeObject.firstString(for: ["gr", "highlighting", "highlight"]) ?? rowHighlighting
                        if foreground != nil || background != nil || highlighting != nil {
                            explicitAttributesSeen = true
                        }
                        return CellChange(
                            column: max(0, column - 1),
                            text: text,
                            count: count,
                            foreground: foreground,
                            background: background,
                            highlighting: highlighting
                        )
                    }
                )
            }
        }
        hasExplicitAttributes = explicitAttributesSeen

        if !clearsScreen && cursor == nil && rowChanges.isEmpty {
            return nil
        }
    }
}

private extension Dictionary where Key == String, Value == Any {
    func firstString(for keys: [String]) -> String? {
        for key in keys {
            if let value = self[key] as? String, !value.isEmpty {
                return value
            }
        }
        return nil
    }
}
