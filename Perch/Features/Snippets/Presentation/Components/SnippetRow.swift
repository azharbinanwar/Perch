import SwiftUI

struct SnippetRow: View {
    @Environment(SnippetViewModel.self) private var vm
    let snippet: Snippet
    let onEdit: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "note.text").foregroundStyle(.secondary).frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(snippet.name).font(.system(size: 13, weight: .medium))
                    if vm.expansionEnabled, let abbreviation = snippet.abbreviation {
                        Chip(text: "\(vm.expansionPrefix.rawValue)\(abbreviation)\(vm.expansionPrefix.rawValue)",
                             size: .small, monospaced: true)
                    }
                }
                Text(snippet.text).lineLimit(2).font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Spacer()
            Button(action: onEdit) { Image(systemName: "pencil") }
                .buttonStyle(.borderless).foregroundStyle(.secondary)
            Button(role: .destructive) { vm.delete(snippet) } label: { Image(systemName: "trash") }
                .buttonStyle(.borderless).foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .contentShape(Rectangle())
        .onTapGesture(perform: onEdit)
    }
}
