import SwiftUI

struct ActionPicker: View {
    let onPick: (ActionKind) -> Void
    var excluding: Set<ActionKind> = []   // kinds to hide (e.g. Pass Through is meaningless for Keys)

    @Environment(\.dismiss) private var dismiss
    @State private var search = ""
    @State private var detailKind: ActionKind?
    @State private var selection = 0      // keyboard highlight — index into visibleKinds

    private let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

    /// All matching kinds in on-screen order (group by group) — the arrow keys walk this.
    private var visibleKinds: [ActionKind] {
        ActionGroup.allCases.flatMap { matches(in: $0) }
    }

    private var highlighted: ActionKind? {
        let kinds = visibleKinds
        guard kinds.indices.contains(selection) else { return kinds.first }
        return kinds[selection]
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Choose Action").font(.headline)
                Spacer()
            }
            .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 8)

            SearchField(placeholder: "Search actions", text: $search, autofocus: true,
                        onSubmit: { pickHighlighted() })
                .padding(.horizontal, 16).padding(.bottom, 8)

            Divider()

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(ActionGroup.allCases) { group in
                            let kinds = matches(in: group)
                            if !kinds.isEmpty {
                                SectionLabel(title: group.title)
                                LazyVGrid(columns: columns, spacing: 8) {
                                    ForEach(kinds) { kind in cell(kind).id(kind) }
                                }
                            }
                        }
                    }
                    .padding(16)
                }
                .onChange(of: selection) {
                    if let kind = highlighted { withAnimation(.easeOut(duration: 0.1)) { proxy.scrollTo(kind, anchor: .center) } }
                }
            }

            Divider()

            HStack {
                Label("Long-press an action to try it first.", systemImage: "hand.tap")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
                Spacer()
                KeyHint(keys: "↑ ↓", label: "navigate")
                KeyHint(keys: "⏎", label: "pick")
                Button("Close") { dismiss() }.keyboardShortcut(.cancelAction)
            }
            .padding(12)
        }
        .frame(width: 540, height: 480)
        .onChange(of: search) { selection = 0 }   // Return always picks the top match after filtering
        .onKeyPress(.upArrow)   { moveSelection(-1); return .handled }
        .onKeyPress(.downArrow) { moveSelection(+1); return .handled }
    }

    private func moveSelection(_ delta: Int) {
        let count = visibleKinds.count
        guard count > 0 else { return }
        selection = min(max(selection + delta, 0), count - 1)
    }

    private func pickHighlighted() {
        guard let kind = highlighted, !kind.isPremium else { return }
        onPick(kind)
        dismiss()
    }

    private func matches(in group: ActionGroup) -> [ActionKind] {
        ActionKind.inGroup(group).filter {
            !excluding.contains($0) && (search.isEmpty || $0.title.localizedCaseInsensitiveContains(search))
        }
    }

    private func cell(_ kind: ActionKind) -> some View {
        let isHighlighted = kind == highlighted
        return HStack(spacing: 8) {
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
        .background(
            isHighlighted ? AnyShapeStyle(Color.accentColor.opacity(0.18)) : AnyShapeStyle(.quaternary.opacity(0.3)),
            in: RoundedRectangle(cornerRadius: 7)
        )
        .overlay(RoundedRectangle(cornerRadius: 7).stroke(isHighlighted ? Color.accentColor.opacity(0.6) : .clear, lineWidth: 1))
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
