//
//  InfoNote.swift
//  Perch
//
//  Reusable subtle info line: an SF Symbol + secondary text.
//

import SwiftUI

struct InfoNote: View {
    let systemImage: String
    let text: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
            Text(text)
            Spacer()
        }
        .font(.system(size: 11))
        .foregroundStyle(.secondary)
    }
}
