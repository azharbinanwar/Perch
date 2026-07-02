//
//  ClipboardItem.swift
//  Perch
//

import Foundation

struct ClipboardItem: Identifiable, Codable, Equatable {
    let id: UUID
    let text: String          // plain text — used for preview + search (always present)
    let copiedAt: Date
    var isPinned: Bool
    let sourceApp: String?    // bundle id of the app it was copied from
    let richData: Data?       // formatted representation (RTF/HTML), when the copy had one
    let richType: String?     // pasteboard type of richData, e.g. "public.rtf"

    init(id: UUID = UUID(), text: String, copiedAt: Date = .now, isPinned: Bool = false,
         sourceApp: String? = nil, richData: Data? = nil, richType: String? = nil) {
        self.id = id
        self.text = text
        self.copiedAt = copiedAt
        self.isPinned = isPinned
        self.sourceApp = sourceApp
        self.richData = richData
        self.richType = richType
    }

    // Decode the newer fields leniently — items saved before they existed won't have the keys.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        text = try c.decode(String.self, forKey: .text)
        copiedAt = try c.decode(Date.self, forKey: .copiedAt)
        isPinned = try c.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
        sourceApp = try c.decodeIfPresent(String.self, forKey: .sourceApp)
        richData = try c.decodeIfPresent(Data.self, forKey: .richData)
        richType = try c.decodeIfPresent(String.self, forKey: .richType)
    }
}
