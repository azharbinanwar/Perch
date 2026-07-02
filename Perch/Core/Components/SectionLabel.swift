//
//  SectionLabel.swift
//  Perch
//
//  Reusable small uppercase section header (+ optional trailing hint).
//

import SwiftUI

struct SectionLabel: View {
    let title: String
    var hint: String? = nil

    var body: some View {
        HStack {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.tertiary)
            Spacer()
            if let hint {
                Text(hint)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 6)
        .padding(.bottom, 2)
    }
}
