//
//  SearchField.swift
//  Perch
//
//  Reusable native-style search box.
//

import SwiftUI

struct SearchField: View {
    let placeholder: String
    @Binding var text: String
    var autofocus = false
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField(placeholder, text: $text).textFieldStyle(.plain).focused($focused)
            if !text.isEmpty {
                Button { text = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(Color(nsColor: .textBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
        .onAppear {
            // Slight delay: focusing during the sheet's present animation often doesn't take.
            if autofocus { DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { focused = true } }
        }
    }
}
