//
//  MouseDevice.swift
//  Perch
//
//  A connected pointing device (mouse), from IOKit HID. Used for the readout under the title.
//

import Foundation

struct MouseDevice: Equatable {
    let name: String
    let transport: String    // "USB", "Bluetooth", …
    let buttons: Int

    /// e.g. "Logitech MX Master · Bluetooth · 7 buttons"
    var summary: String {
        var parts = [name]
        let t = transport.replacingOccurrences(of: "Bluetooth Low Energy", with: "Bluetooth")
        if !t.isEmpty { parts.append(t) }
        if buttons > 0 { parts.append("\(buttons) buttons") }
        return parts.joined(separator: " · ")
    }
}
