//
//  UpdateChecker.swift
//  Perch
//
//  Checks the Perch repo's GitHub releases for a newer version, then
//  downloads Perch.dmg, verifies it against Perch.dmg.sha256, and opens
//  the mounted DMG so the user can drag Perch into Applications.
//

import AppKit
import CryptoKit
import Foundation
import Observation

@Observable
@MainActor
final class UpdateChecker {
    static let shared = UpdateChecker()

    enum Phase: Equatable {
        case idle
        case checking
        case upToDate
        case available(version: String)
        case downloading(progress: Double)
        case installing
        case downloaded(version: String)   // fallback: auto-install failed, DMG opened
        case failed(String)
    }

    private(set) var phase: Phase = .idle
    private(set) var lastChecked: Date? {
        didSet { UserDefaults.standard.set(lastChecked, forKey: Self.lastCheckedKey) }
    }

    static let repo = "azharbinanwar/Perch"
    private static let lastCheckedKey = "updates.lastChecked"

    private init() {
        lastChecked = UserDefaults.standard.object(forKey: Self.lastCheckedKey) as? Date
    }

    var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
    }

    // MARK: - Check

    func check() async {
        guard phase != .checking else { return }
        phase = .checking
        do {
            var req = URLRequest(url: URL(string: "https://api.github.com/repos/\(Self.repo)/releases/latest")!)
            req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            req.timeoutInterval = 15
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard (resp as? HTTPURLResponse)?.statusCode == 200 else {
                throw URLError(.badServerResponse)
            }
            struct Release: Decodable { let tag_name: String }
            let release = try JSONDecoder().decode(Release.self, from: data)
            let remote = release.tag_name.hasPrefix("v")
                ? String(release.tag_name.dropFirst())
                : release.tag_name
            lastChecked = .now
            phase = isNewer(remote, than: currentVersion) ? .available(version: remote) : .upToDate
        } catch {
            phase = .failed("Couldn't reach GitHub — check your connection and try again.")
        }
    }

    /// Auto-check on launch, at most once per day. No-op if throttled.
    func checkIfDue() async {
        if let last = lastChecked, Date.now.timeIntervalSince(last) < 86_400 { return }
        await check()
    }

    // MARK: - Download + verify + open

    private(set) var downloadedDMG: URL?

    func downloadAndOpen() async {
        guard case .available(let version) = phase else { return }
        phase = .downloading(progress: 0)
        do {
            let base = "https://github.com/\(Self.repo)/releases/download/v\(version)"

            // 1. Expected checksum (tiny text asset published next to the DMG).
            let expected = try await fetchExpectedChecksum(
                from: URL(string: "\(base)/Perch.dmg.sha256")!
            )

            // 2. Stream the DMG to disk, hashing as we go.
            let dmgURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("Perch-\(version).dmg")
            try? FileManager.default.removeItem(at: dmgURL)

            let (bytes, resp) = try await URLSession.shared.bytes(
                from: URL(string: "\(base)/Perch.dmg")!
            )
            guard (resp as? HTTPURLResponse)?.statusCode == 200 else {
                throw URLError(.badServerResponse)
            }
            let total = resp.expectedContentLength

            FileManager.default.createFile(atPath: dmgURL.path, contents: nil)
            let handle = try FileHandle(forWritingTo: dmgURL)
            defer { try? handle.close() }

            var hasher = SHA256()
            var received: Int64 = 0
            let chunkSize = 128 * 1024
            var buffer = Data()
            buffer.reserveCapacity(chunkSize)

            for try await byte in bytes {
                buffer.append(byte)
                if buffer.count >= chunkSize {
                    hasher.update(data: buffer)
                    try handle.write(contentsOf: buffer)
                    received += Int64(buffer.count)
                    buffer.removeAll(keepingCapacity: true)
                    if total > 0 {
                        phase = .downloading(progress: Double(received) / Double(total))
                    }
                }
            }
            if !buffer.isEmpty {
                hasher.update(data: buffer)
                try handle.write(contentsOf: buffer)
            }

            // 3. Verify before anything touches the user's screen.
            let digest = hasher.finalize().map { String(format: "%02x", $0) }.joined()
            guard digest == expected else {
                try? FileManager.default.removeItem(at: dmgURL)
                phase = .failed("The download didn't match its published checksum — try again.")
                return
            }

            // 4. Auto-install: silent mount → bundle swap → self-relaunch.
            phase = .installing
            do {
                let installed = try await UpdateInstaller.install(dmg: dmgURL)
                UpdateInstaller.relaunch(installed)   // terminates this process
            } catch {
                // Fallback: open the verified DMG for a manual drag-install.
                downloadedDMG = dmgURL
                NSWorkspace.shared.open(dmgURL)
                phase = .downloaded(version: version)
            }
        } catch {
            phase = .failed("Download failed — check your connection and try again.")
        }
    }

    /// Re-open an already-downloaded, already-verified DMG.
    func openDownloadedDMG() {
        guard let url = downloadedDMG,
              FileManager.default.fileExists(atPath: url.path) else {
            // Stale temp file — fall back to a fresh check.
            downloadedDMG = nil
            if case .downloaded(let version) = phase { phase = .available(version: version) }
            return
        }
        NSWorkspace.shared.open(url)
    }

    private func fetchExpectedChecksum(from url: URL) async throws -> String {
        var req = URLRequest(url: url)
        req.timeoutInterval = 15
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard (resp as? HTTPURLResponse)?.statusCode == 200,
              let text = String(data: data, encoding: .utf8),
              let token = text.split(whereSeparator: \.isWhitespace).first,
              token.count == 64, token.allSatisfy(\.isHexDigit) else {
            throw URLError(.cannotParseResponse)
        }
        return token.lowercased()
    }

    // MARK: - Semver

    private func isNewer(_ remote: String, than local: String) -> Bool {
        let r = remote.split(separator: ".").map { Int($0) ?? 0 }
        let l = local.split(separator: ".").map { Int($0) ?? 0 }
        for i in 0..<max(r.count, l.count) {
            let a = i < r.count ? r[i] : 0
            let b = i < l.count ? l[i] : 0
            if a != b { return a > b }
        }
        return false
    }
}
