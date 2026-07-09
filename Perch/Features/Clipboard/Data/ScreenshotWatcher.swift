import AppKit
import CoreServices

// Watches the macOS screenshot folder and fires when a new screenshot FILE lands (⌘⇧4/3 in
// save-to-file mode). Event-driven via a directory DispatchSource — idle until a file appears.
final class ScreenshotWatcher {
    var onScreenshot: ((Data) -> Void)?     // image screenshot → captured as an image item
    var onRecording: ((String) -> Void)?    // screen recording → captured as a file item (path)

    private var source: DispatchSource?
    private var fd: Int32 = -1
    private var watchedPath = ""
    private var knownFiles: Set<String> = []   // so a screenshot only fires once

    /// The folder to watch: the user override, else the OS setting, else ~/Desktop.
    static func resolvedFolder(override: String?) -> String {
        if let o = override, !o.isEmpty { return (o as NSString).expandingTildeInPath }
        let loc = UserDefaults(suiteName: "com.apple.screencapture")?.string(forKey: "location")
        if let loc, !loc.isEmpty { return (loc as NSString).expandingTildeInPath }
        return (NSHomeDirectory() as NSString).appendingPathComponent("Desktop")
    }

    func start(folder: String) {
        // Re-resolve every start so a changed location re-points cleanly.
        if source != nil, folder == watchedPath { return }
        stop()
        watchedPath = folder
        knownFiles = Set((try? FileManager.default.contentsOfDirectory(atPath: folder)) ?? [])

        fd = open(folder, O_EVTONLY)
        guard fd >= 0 else { return }   // no access (denied) → no-op; retried on next start
        let src = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd, eventMask: .write, queue: .main) as? DispatchSource
        source = src
        src?.setEventHandler { [weak self] in self?.scan() }
        src?.setCancelHandler { [weak self] in
            if let fd = self?.fd, fd >= 0 { close(fd) }
            self?.fd = -1
        }
        src?.resume()
    }

    func stop() {
        source?.cancel()
        source = nil
        watchedPath = ""
    }

    private static let imageExtensions: Set<String> = ["png", "jpg", "jpeg", "heic", "tiff", "gif"]
    private static let videoExtensions: Set<String> = ["mov", "mp4", "m4v"]

    // A directory write fired — find files we haven't seen and ingest new screenshots / recordings.
    private func scan() {
        let current = Set((try? FileManager.default.contentsOfDirectory(atPath: watchedPath)) ?? [])
        let added = current.subtracting(knownFiles)
        knownFiles = current
        for name in added {
            let ext = (name as NSString).pathExtension.lowercased()
            guard Self.imageExtensions.contains(ext) || Self.videoExtensions.contains(ext) else { continue }
            ingest((watchedPath as NSString).appendingPathComponent(name),
                   isVideo: Self.videoExtensions.contains(ext), attempt: 0)
        }
    }

    // The Spotlight screenshot tag can lag the file write (worse for big full-screen/recordings), so
    // we retry a few times. No size cap — images are read into ImageStore, videos kept as a path.
    private func ingest(_ path: String, isVideo: Bool, attempt: Int) {
        DispatchQueue.main.asyncAfter(deadline: .now() + (attempt == 0 ? 0.3 : 0.8)) { [weak self] in
            guard let self else { return }
            if Self.isScreenshot(path) {
                if isVideo {
                    self.onRecording?(path)   // file link — QuickLook renders the thumbnail
                } else if let data = try? Data(contentsOf: URL(fileURLWithPath: path)) {
                    self.onScreenshot?(data)
                }
            } else if attempt < 4 {
                self.ingest(path, isVideo: isVideo, attempt: attempt + 1)   // tag not set yet — retry
            }
        }
    }

    // True only for real macOS screenshots (Spotlight tags them kMDItemIsScreenCapture = 1).
    private static func isScreenshot(_ path: String) -> Bool {
        guard let item = MDItemCreate(nil, path as CFString),
              let value = MDItemCopyAttribute(item, "kMDItemIsScreenCapture" as CFString) as? Bool
        else { return false }
        return value
    }
}
