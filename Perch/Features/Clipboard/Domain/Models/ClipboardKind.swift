//
//  ClipboardKind.swift
//  Perch
//
//  Lightweight detection of what a copied item is, for smart rendering.
//  All checks are cheap and run on the plain text.
//

import SwiftUI

enum ClipboardKind: Equatable {
    case text
    case link(domain: String)
    case color(Color)
    case email
    case code

    static func detect(_ raw: String) -> ClipboardKind {
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if let color = parseColor(s) { return .color(color) }
        if let domain = linkDomain(s) { return .link(domain: domain) }
        if isEmail(s) { return .email }
        if looksLikeCode(raw) { return .code }
        return .text
    }

    // MARK: - Color

    private static func parseColor(_ s: String) -> Color? {
        if s.hasPrefix("#") { return hexColor(String(s.dropFirst())) }
        if s.lowercased().hasPrefix("rgb") { return rgbColor(s) }
        return nil
    }

    private static func hexColor(_ hex: String) -> Color? {
        guard [3, 6, 8].contains(hex.count), hex.allSatisfy(\.isHexDigit) else { return nil }
        let full = hex.count == 3 ? hex.map { "\($0)\($0)" }.joined() : hex
        guard let v = UInt64(full, radix: 16) else { return nil }
        if full.count == 8 {
            return Color(.sRGB, red: d(v >> 24), green: d(v >> 16), blue: d(v >> 8), opacity: d(v))
        }
        return Color(.sRGB, red: d(v >> 16), green: d(v >> 8), blue: d(v), opacity: 1)
    }

    private static func d(_ v: UInt64) -> Double { Double(v & 0xFF) / 255 }

    private static func rgbColor(_ s: String) -> Color? {
        let nums = s.components(separatedBy: CharacterSet(charactersIn: "0123456789.").inverted)
            .compactMap(Double.init)
        guard nums.count >= 3 else { return nil }
        let a = nums.count >= 4 ? nums[3] : 1
        return Color(.sRGB, red: nums[0] / 255, green: nums[1] / 255, blue: nums[2] / 255, opacity: a)
    }

    // MARK: - Link / email / code

    private static func linkDomain(_ s: String) -> String? {
        guard !s.contains(where: \.isWhitespace), s.lowercased().hasPrefix("http"),
              let url = URL(string: s), let host = url.host else { return nil }
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }

    private static func isEmail(_ s: String) -> Bool {
        guard !s.contains(where: \.isWhitespace) else { return false }
        return s.range(of: #"^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$"#,
                       options: [.regularExpression, .caseInsensitive]) != nil
    }

    private static func looksLikeCode(_ text: String) -> Bool {
        guard text.contains("\n") else { return false }
        let symbols = CharacterSet(charactersIn: "{};<>=")
        let count = text.unicodeScalars.filter { symbols.contains($0) }.count
        return count >= 3
    }
}
