//
//  Thumbnailer.swift
//  Perch
//
//  Images for the clipboard UI, decoded at the size they're shown and cached with a cap:
//  - small thumbnails for rows/tiles (many, tiny, sharp at icon size)
//  - full images for the preview/carousel (few, high quality, not retained for long)
//  No file bytes are copied — the original on disk is the source.
//

import AppKit
import ImageIO
import QuickLookThumbnailing
import UniformTypeIdentifiers

enum Thumbnailer {
    private static var smallCache = LRUCache<String, NSImage>(capacity: 60)   // rows/tiles
    private static var fullCache  = LRUCache<String, NSImage>(capacity: 6)    // preview/carousel

    private static let imageExtensions: Set<String> =
        ["png", "jpg", "jpeg", "gif", "heic", "heif", "webp", "tiff", "tif", "bmp", "icns"]

    /// Whether a file path points at an image ImageIO can decode directly (rows use this to pick
    /// the fast bitmap path). SVG is excluded — ImageIO can't rasterize it, so it goes to Quick Look.
    static func isImage(_ path: String) -> Bool {
        let ext = (path as NSString).pathExtension.lowercased()
        if ext == "svg" { return false }
        if imageExtensions.contains(ext) { return true }
        guard let type = UTType(filenameExtension: ext) else { return false }
        return type.conforms(to: .image)
    }

    /// Small thumbnail sized to how it's shown (rows/tiles). Image files decode a downsized
    /// bitmap directly (cheap, sharp); other files fall back to Quick Look.
    static func thumbnail(_ path: String, size: CGFloat) async -> NSImage? {
        let scale = NSScreen.main?.backingScaleFactor ?? 2
        let maxPixel = Int(size * scale)
        let key = "\(path)|\(maxPixel)"
        if let cached = smallCache.value(for: key) { return cached }

        let image: NSImage?
        if isImage(path) {
            image = await Task.detached { downsample(path, maxPixel: maxPixel) }.value
        } else {
            image = await quickLook(path, maxPixel: maxPixel, scale: scale)
        }
        if let image { smallCache.set(image, for: key) }
        return image
    }

    /// High-quality image for the large preview/carousel — downsized to a sane ceiling so a
    /// giant photo doesn't sit full-size in RAM. Capped cache: only a few are retained.
    static func fullImage(_ path: String) async -> NSImage? {
        if let cached = fullCache.value(for: path) { return cached }
        let image: NSImage?
        if isImage(path) {
            image = await Task.detached { downsample(path, maxPixel: 2048) }.value
        } else {
            image = await quickLook(path, maxPixel: 1024, scale: NSScreen.main?.backingScaleFactor ?? 2)
        }
        if let image { fullCache.set(image, for: path) }
        return image
    }

    // MARK: - Decoders

    /// Decode only a thumbnail of `maxPixel` from the file — never the full image.
    private static func downsample(_ path: String, maxPixel: Int) -> NSImage? {
        let url = URL(fileURLWithPath: path) as CFURL
        guard let source = CGImageSourceCreateWithURL(url, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
        ]
        guard let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height))
    }

    private static func quickLook(_ path: String, maxPixel: Int, scale: CGFloat) async -> NSImage? {
        let request = QLThumbnailGenerator.Request(
            fileAt: URL(fileURLWithPath: path),
            size: CGSize(width: CGFloat(maxPixel) / scale, height: CGFloat(maxPixel) / scale),
            scale: scale,
            representationTypes: .thumbnail)
        return try? await QLThumbnailGenerator.shared.generateBestRepresentation(for: request).nsImage
    }
}
