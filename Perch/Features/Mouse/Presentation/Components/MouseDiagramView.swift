//
//  MouseDiagramView.swift
//  Perch
//
//  A generic mouse picture with clickable buttons. Tapping a button reports it to the parent;
//  mapped and selected buttons are tinted with the app accent. Themed with system colors so it
//  matches the rest of the app. macOS can't know the real device shape — this is a representative
//  mouse, hotspots mapped to standard button numbers by the parent.
//

import SwiftUI

struct MouseDiagramView: View {
    @Binding var selected: String
    var isMapped: (String) -> Bool
    var isActive: (String) -> Bool     // detected/base buttons are solid; others are faint ghosts
    var holdIDs: Set<String> = []      // layer keys — drawn amber with a HOLD tag, not selectable
    var onSelect: (String) -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            body(96, 96, 96, 96).frame(width: 200, height: 330).offset(x: 30, y: 0)
            Rectangle().fill(Color.primary.opacity(0.12)).frame(width: 1, height: 114).offset(x: 129.5, y: 10)
            Rectangle().fill(Color.primary.opacity(0.07)).frame(width: 184, height: 1).offset(x: 38, y: 128)

            hotspot("left", 90, 118, 36, 6, (92, 8, 8, 8))
            hotspot("right", 90, 118, 134, 6, (8, 8, 8, 92))
            hotspot("middle", 26, 60, 117, 32, (13, 13, 13, 13)) {
                VStack(spacing: 5) { ForEach(0..<3) { _ in Capsule().fill(.secondary).frame(width: 12, height: 1.5) } }
            }
            hotspot("top", 28, 18, 116, 100, (6, 6, 6, 6))
            hotspot("fwd", 16, 42, 22, 134, (8, 8, 8, 8), "5")
            hotspot("back", 16, 42, 22, 184, (8, 8, 8, 8), "4")
            // Mirrored right-side extras (for mice with buttons on both sides).
            hotspot("rup", 16, 42, 222, 134, (8, 8, 8, 8), "6")
            hotspot("rdn", 16, 42, 222, 184, (8, 8, 8, 8), "7")
        }
        .frame(width: 260, height: 330)   // 260 balances the side-button overhang (22px each side)
    }

    private func body(_ tl: CGFloat, _ tr: CGFloat, _ br: CGFloat, _ bl: CGFloat) -> some View {
        shape(tl, tr, br, bl).fill(Color.primary.opacity(0.05))
            .overlay(shape(tl, tr, br, bl).stroke(Color.primary.opacity(0.12), lineWidth: 1))
    }

    private func hotspot(_ id: String, _ w: CGFloat, _ h: CGFloat, _ x: CGFloat, _ y: CGFloat,
                         _ radii: (CGFloat, CGFloat, CGFloat, CGFloat), _ label: String? = nil,
                         @ViewBuilder content: () -> some View = { EmptyView() }) -> some View {
        let hold = holdIDs.contains(id)
        let sel = selected == id && !hold
        let mapped = isMapped(id)
        let fill: Color = hold ? Color.orange.opacity(0.3)
                               : sel ? Color.accentColor.opacity(0.25)
                                     : (mapped ? Color.accentColor.opacity(0.15) : Color.primary.opacity(0.06))
        let stroke: Color = hold ? Color.orange : (sel ? Color.accentColor : Color.primary.opacity(0.15))
        // Base buttons always show; extras only once detected (hidden otherwise).
        return Group {
            if isActive(id) {
                shape(radii.0, radii.3, radii.2, radii.1)
                    .fill(fill)
                    .overlay(shape(radii.0, radii.3, radii.2, radii.1).stroke(stroke, lineWidth: (sel || hold) ? 1.5 : 1))
                    .overlay {
                        if let label { Text(label).font(.system(size: 9, weight: .bold)).foregroundStyle(.secondary) }
                        content()
                    }
                    .overlay(alignment: .top) {
                        if hold {
                            // A proper floating callout: fixed natural size, centered above the
                            // button, never squeezed by narrow hotspots.
                            Text("HOLD")
                                .font(.system(size: 8.5, weight: .bold))
                                .kerning(0.6)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 7).padding(.vertical, 2)
                                .background(Color.orange, in: RoundedRectangle(cornerRadius: 4))
                                .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
                                .fixedSize()
                                .offset(y: -22)   // clear gap between the tag and the button, like the design
                        }
                    }
                    .frame(width: w, height: h)
                    .contentShape(Rectangle())
                    .onTapGesture { if !hold { onSelect(id) } }
                    .position(x: x + w / 2, y: y + h / 2)   // position (not offset) so hit-testing follows
            }
        }
    }

    private func shape(_ tl: CGFloat, _ tr: CGFloat, _ br: CGFloat, _ bl: CGFloat) -> UnevenRoundedRectangle {
        UnevenRoundedRectangle(topLeadingRadius: tl, bottomLeadingRadius: bl,
                               bottomTrailingRadius: br, topTrailingRadius: tr)
    }
}
