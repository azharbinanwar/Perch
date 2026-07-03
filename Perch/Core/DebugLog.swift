//
//  DebugLog.swift
//  Perch
//
//  Tiny in-app log so diagnostics show inside Perch (a Diagnostics panel) instead of
//  Console.app. Capped ring buffer; newest last. Shared singleton.
//

import Observation
import Foundation

@Observable
final class DebugLog {
    static let shared = DebugLog()

    private(set) var entries: [String] = []
    private let cap = 200

    func log(_ message: String) {
        let line = "\(Self.clock.string(from: Date()))  \(message)"
        if Thread.isMainThread { append(line) }
        else { DispatchQueue.main.async { self.append(line) } }
    }

    func clear() { entries.removeAll() }

    private func append(_ line: String) {
        entries.append(line)
        if entries.count > cap { entries.removeFirst(entries.count - cap) }
    }

    private static let clock: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()
}
