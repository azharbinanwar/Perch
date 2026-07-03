//
//  ImageStore.swift
//  Perch
//
//  Stores clipboard image blobs as files in Application Support (never system-purged,
//  so pinned images are safe). A blob dies with its clipboard item.
//

import AppKit

enum ImageStore {
    private static let directory: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("Perch/Images", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    /// Save PNG data, return the blob filename.
    static func save(_ data: Data) -> String? {
        let name = UUID().uuidString + ".png"
        do {
            try data.write(to: directory.appendingPathComponent(name))
            return name
        } catch {
            return nil
        }
    }

    static func data(_ name: String) -> Data? {
        try? Data(contentsOf: directory.appendingPathComponent(name))
    }

    /// Full on-disk path of a blob (for viewers that load images by path).
    static func path(_ name: String) -> String {
        directory.appendingPathComponent(name).path
    }

    static func delete(_ name: String) {
        try? FileManager.default.removeItem(at: directory.appendingPathComponent(name))
    }

    /// Total bytes used by stored image blobs.
    static func diskUsage() -> Int {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
        return names.reduce(0) { sum, name in
            let attrs = try? FileManager.default.attributesOfItem(atPath: directory.appendingPathComponent(name).path)
            return sum + (attrs?[.size] as? Int ?? 0)
        }
    }

    /// Delete any blob on disk that no live item references (e.g. left over from a crash).
    static func pruneOrphans(keeping used: Set<String>) {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
        for name in names where !used.contains(name) {
            try? FileManager.default.removeItem(at: directory.appendingPathComponent(name))
        }
    }

    /// A temp copy with a friendly name, so Finder can paste the image as a file.
    static func pasteURL(_ name: String) -> URL? {
        guard let data = data(name) else { return nil }
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("Perch", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent(name)   // blob's own uuid.png — unique per image
        do {
            try data.write(to: url)
            return url
        } catch {
            return nil
        }
    }
}
