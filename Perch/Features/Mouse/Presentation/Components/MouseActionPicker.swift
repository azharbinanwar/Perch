//
//  MouseActionPicker.swift
//  Perch
//
//  Searchable, grouped, multi-column dialog for choosing an action — replaces the long
//  dropdown. Emits the picked kind; the caller resolves any target it needs. Reusable.
//

import SwiftUI

struct MouseActionPicker: View {
    let onPick: (MouseActionKind) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var search = ""
    @State private var detailKind: MouseActionKind?

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 10)]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Choose Action").font(.headline)
                Spacer()
                Button("Done") { dismiss() }.keyboardShortcut(.cancelAction)
            }
            .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 8)

            SearchField(placeholder: "Search actions", text: $search)
                .padding(.horizontal, 16).padding(.bottom, 6)

            Label("Long-press an action to try it first.", systemImage: "hand.tap")
                .font(.system(size: 11)).foregroundStyle(.secondary)
                .padding(.horizontal, 16).padding(.bottom, 8)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(MouseActionGroup.allCases) { group in
                        let kinds = matches(in: group)
                        if !kinds.isEmpty {
                            SectionLabel(title: group.title)
                            LazyVGrid(columns: columns, spacing: 10) {
                                ForEach(kinds) { kind in cell(kind) }
                            }
                        }
                    }
                }
                .padding(16)
            }
        }
        .frame(width: 540, height: 480)
    }

    private func matches(in group: MouseActionGroup) -> [MouseActionKind] {
        MouseActionKind.inGroup(group).filter {
            search.isEmpty || $0.title.localizedCaseInsensitiveContains(search)
        }
    }

    private func cell(_ kind: MouseActionKind) -> some View {
        HStack(spacing: 8) {
            Image(systemName: kind.icon).frame(width: 18).foregroundStyle(.secondary)
            Text(kind.title).font(.system(size: 12)).lineLimit(1)
            Spacer(minLength: 0)
            if kind.isPremium {
                Image(systemName: "lock.fill").font(.system(size: 9)).foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 10).padding(.vertical, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 7))
        .contentShape(Rectangle())
        .opacity(kind.isPremium ? 0.5 : 1)
        // tap = choose · long-press = show details (with Try when it's self-contained)
        .onTapGesture { guard !kind.isPremium else { return }; onPick(kind); dismiss() }
        .onLongPressGesture { detailKind = kind }
        .popover(isPresented: Binding(get: { detailKind == kind }, set: { if !$0 { detailKind = nil } })) {
            detailCard(kind)
        }
    }

    private func detailCard(_ kind: MouseActionKind) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(kind.title, systemImage: kind.icon).font(.system(size: 13, weight: .semibold))
            Text(kind.detail).font(.system(size: 12)).foregroundStyle(.secondary)
            Divider()
            if kind.isPremium {
                Text("Premium action.").font(.system(size: 11)).foregroundStyle(.tertiary)
            } else if kind.isTryable {
                Button {
                    MouseActionRunner.run(MouseAction(kind: kind))
                } label: {
                    Label("Try it", systemImage: "play.fill").font(.system(size: 12))
                }
            } else {
                Text("Can't preview here — it acts on whatever you have focused. Assign it, then use the button in the app.")
                    .font(.system(size: 11)).foregroundStyle(.tertiary)
            }
        }
        .padding(14)
        .frame(width: 240)
    }
}
