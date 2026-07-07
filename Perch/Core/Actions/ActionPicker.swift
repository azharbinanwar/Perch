//
//  ActionPicker.swifthen 
//  Perch
//
//  Searchable, grouped, multi-column dialog for choosing an action — replaces the long
//  dropdown. Emits the picked kind; the caller resolves any target it needs. Reusable.
//

import SwiftUI

struct ActionPicker: View {
    let onPick: (ActionKind) -> Void
    var excluding: Set<ActionKind> = []   // kinds to hide (e.g. Pass Through is meaningless for Keys)

    @Environment(\.dismiss) private var dismiss
    @State private var search = ""
    @State private var detailKind: ActionKind? 

    private let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Choose Action").font(.headline)
                Spacer()
            }
            .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 8)

            SearchField(placeholder: "Search actions", text: $search, autofocus: true)
                .padding(.horizontal, 16).padding(.bottom, 6)

            Label("Long-press an action to try it first.", systemImage: "hand.tap")
                .font(.system(size: 11)).foregroundStyle(.secondary)
                .padding(.horizontal, 16).padding(.bottom, 8)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(ActionGroup.allCases) { group in
                        let kinds = matches(in: group)
                        if !kinds.isEmpty {
                            SectionLabel(title: group.title)
                            LazyVGrid(columns: columns, spacing: 8) {
                                ForEach(kinds) { kind in cell(kind) }
                            }
                        }
                    }
                }
                .padding(16)
            }
        }
        .frame(width: 540, height: 480)
        .onExitCommand { dismiss() }   // Esc closes — no Done needed (tap picks & dismisses)
    }

    private func matches(in group: ActionGroup) -> [ActionKind] {
        ActionKind.inGroup(group).filter {
            !excluding.contains($0) && (search.isEmpty || $0.title.localizedCaseInsensitiveContains(search))
        }
    }

    private func cell(_ kind: ActionKind) -> some View {
        HStack(spacing: 8) {
            Image(systemName: kind.icon).frame(width: 18).foregroundStyle(.secondary)
            Text(kind.title).font(.system(size: 12)).lineLimit(1)
            Spacer(minLength: 0)
            if let sym = kind.shortcutSymbols {
                Text(sym).font(.system(size: 11, design: .rounded)).foregroundStyle(.tertiary).lineLimit(1)
            }
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

    private func detailCard(_ kind: ActionKind) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(kind.title, systemImage: kind.icon).font(.system(size: 13, weight: .semibold))
            Text(kind.detail).font(.system(size: 12)).foregroundStyle(.secondary)
            Divider()
            if kind.isPremium {
                Text("Premium action.").font(.system(size: 11)).foregroundStyle(.tertiary)
            } else if kind.isTryable {
                Button {
                    ActionRunner.run(Action(kind: kind))
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
