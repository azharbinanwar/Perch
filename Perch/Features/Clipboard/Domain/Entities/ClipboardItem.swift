//
//  ClipboardItem.swift
//  Perch
//

import Foundation

enum ClipboardContent: String, Codable {
    case text
    case image
    case files
}

struct ClipboardItem: Identifiable, Codable, Equatable {
    let id: UUID
    let text: String          // plain text (preview + search). For files: filenames; for image: "Image".
    let copiedAt: Date
    var isPinned: Bool
    let sourceApp: String?
    let richData: Data?       // formatted representation (RTF/HTML) for .text
    let richType: String?
    let content: ClipboardContent
    let imageFiles: [String]? // blob filenames in Application Support for .image (1 or more)
    let filePaths: [String]?  // file paths for .files

    /// First image blob — for the row thumbnail.
    var imageFile: String? { imageFiles?.first }

    init(id: UUID = UUID(), text: String, copiedAt: Date = .now, isPinned: Bool = false,
         sourceApp: String? = nil, richData: Data? = nil, richType: String? = nil,
         content: ClipboardContent = .text, imageFiles: [String]? = nil, filePaths: [String]? = nil) {
        self.id = id
        self.text = text
        self.copiedAt = copiedAt
        self.isPinned = isPinned
        self.sourceApp = sourceApp
        self.richData = richData
        self.richType = richType
        self.content = content
        self.imageFiles = imageFiles
        self.filePaths = filePaths
    }

    // Decode newer fields leniently — items saved before they existed won't have the keys.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        text = try c.decode(String.self, forKey: .text)
        copiedAt = try c.decode(Date.self, forKey: .copiedAt)
        isPinned = try c.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
        sourceApp = try c.decodeIfPresent(String.self, forKey: .sourceApp)
        richData = try c.decodeIfPresent(Data.self, forKey: .richData)
        richType = try c.decodeIfPresent(String.self, forKey: .richType)
        content = try c.decodeIfPresent(ClipboardContent.self, forKey: .content) ?? .text
        // Migrate the old single `imageFile` into the array.
        if let files = try c.decodeIfPresent([String].self, forKey: .imageFiles) {
            imageFiles = files
        } else if let single = try c.decodeIfPresent(String.self, forKey: .imageFile) {
            imageFiles = [single]
        } else {
            imageFiles = nil
        }
        filePaths = try c.decodeIfPresent([String].self, forKey: .filePaths)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(text, forKey: .text)
        try c.encode(copiedAt, forKey: .copiedAt)
        try c.encode(isPinned, forKey: .isPinned)
        try c.encodeIfPresent(sourceApp, forKey: .sourceApp)
        try c.encodeIfPresent(richData, forKey: .richData)
        try c.encodeIfPresent(richType, forKey: .richType)
        try c.encode(content, forKey: .content)
        try c.encodeIfPresent(imageFiles, forKey: .imageFiles)
        try c.encodeIfPresent(filePaths, forKey: .filePaths)
    }

    private enum CodingKeys: String, CodingKey {
        case id, text, copiedAt, isPinned, sourceApp, richData, richType
        case content, imageFiles, imageFile, filePaths
    }
}
