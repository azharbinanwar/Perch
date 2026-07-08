//
//  KeyCap.swift
//  Perch
//

import SwiftUI

struct KeyCap: View {
    let label: String
    var lit: Bool = false
    var width: CGFloat? = nil
    var minSize: CGFloat = 50

    var body: some View {
        Text(label)
            .font(.system(size: 15, weight: .semibold, design: .rounded))
            .foregroundStyle(lit ? Color.white : .primary)
            .frame(width: width, height: minSize)
            .frame(minWidth: width == nil ? minSize : nil)
            .padding(.horizontal, width == nil ? 12 : 0)
            .background(lit ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(Color.primary.opacity(0.06)),
                        in: RoundedRectangle(cornerRadius: 11))
            .overlay(RoundedRectangle(cornerRadius: 11)
                .stroke(lit ? Color.accentColor : Color.primary.opacity(0.15), lineWidth: lit ? 1.5 : 1))
            .scaleEffect(lit ? 0.95 : 1)
            .shadow(color: lit ? Color.accentColor.opacity(0.4) : .clear, radius: 7)
    }
}
