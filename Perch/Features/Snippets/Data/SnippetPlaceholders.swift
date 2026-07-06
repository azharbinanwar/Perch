//
//  SnippetPlaceholders.swift
//  Perch
//
//  Live placeholders inside snippet text, resolved at INSERT time (expansion or popup paste):
//  {date} → today in the user's chosen format · {time} → now · {clipboard} → current clipboard.
//  Unknown {tokens} pass through untouched.
//

import AppKit

enum SnippetPlaceholders {
    /// Selectable {date} formats — pattern is stored, the picker shows a live example.
    static let dateFormats = ["yyyy-MM-dd", "d MMM yyyy", "MM/dd/yyyy", "EEEE, d MMMM yyyy"]
    static let defaultDateFormat = "yyyy-MM-dd"

    /// Live values + {cursor} stripped — for paste paths where the caret can't be moved.
    static func resolve(_ text: String, dateFormat: String) -> String {
        var out = resolveValues(text, dateFormat: dateFormat)
        out = out.replacingOccurrences(of: "{cursor}", with: "")
        return out
    }

    /// Live values + the {cursor} split: returns the final text and how many characters sit
    /// AFTER the cursor position (nil when the snippet has no {cursor}). The expander types
    /// the text, then steps the caret back that many characters.
    static func resolveWithCursor(_ text: String, dateFormat: String) -> (text: String, tail: Int?) {
        var out = resolveValues(text, dateFormat: dateFormat)
        guard let range = out.range(of: "{cursor}") else { return (out, nil) }
        let tail = out.distance(from: range.upperBound, to: out.endIndex)
        out.removeSubrange(range)
        return (out, tail)
    }

    private static func resolveValues(_ text: String, dateFormat: String) -> String {
        guard text.contains("{") else { return text }
        var out = text
        if out.contains("{date}") {
            let formatter = DateFormatter()
            formatter.dateFormat = dateFormat.isEmpty ? defaultDateFormat : dateFormat
            out = out.replacingOccurrences(of: "{date}", with: formatter.string(from: Date()))
        }
        if out.contains("{time}") {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            out = out.replacingOccurrences(of: "{time}", with: formatter.string(from: Date()))
        }
        if out.contains("{clipboard}") {
            let clip = NSPasteboard.general.string(forType: .string) ?? ""
            out = out.replacingOccurrences(of: "{clipboard}", with: clip)
        }
        return out
    }

    /// Today rendered in a pattern — for the settings picker's live examples.
    static func example(_ pattern: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = pattern
        return formatter.string(from: Date())
    }
}
