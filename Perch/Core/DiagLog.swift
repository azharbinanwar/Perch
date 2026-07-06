//
//  DiagLog.swift
//  Perch
//
//  Tiny in-app diagnostic log with a Copy button in General — so debugging never needs
//  Console.app or Xcode. Engines append lines; the newest ~200 are kept.
//

import Foundation
import Observation

@Observable
final class DiagLog {
    static let shared = DiagLog()
    private(set) var text = ""
    private var lines = 0
    private init() {}

    func append(_ line: String) {
        // Millisecond timestamp captured at call time (not after the main-queue hop).
        let stamp = String(format: "%.3f", ProcessInfo.processInfo.systemUptime)
        DispatchQueue.main.async {
            self.text += (self.text.isEmpty ? "" : "\n") + "[\(stamp)] " + line
            self.lines += 1
            if self.lines > 200 {   // keep it light — drop the oldest half
                let kept = self.text.split(separator: "\n").suffix(100)
                self.text = kept.joined(separator: "\n")
                self.lines = kept.count
            }
        }
    }

    func clear() {
        DispatchQueue.main.async { self.text = ""; self.lines = 0 }
    }
}
