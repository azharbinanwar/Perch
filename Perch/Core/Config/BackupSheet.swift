//
//  BackupSheet.swift
//  Perch
//
//  One dialog for both Export and Import: tick which sections to carry, each with a live count.
//  Export writes only the ticked sections; Import replaces only the ticked ones (the rest of
//  your current settings are left untouched).
//

import SwiftUI

/// Wrapper so a PerchConfig can drive `.sheet(item:)`.
struct BackupRequest: Identifiable {
    let id = UUID()
    let mode: BackupSheet.Mode
    let config: PerchConfig
}

struct BackupSheet: View {
    enum Mode { case export, importing }

    let mode: Mode
    let config: PerchConfig
    let onConfirm: (Set<ConfigSection>) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selected: Set<ConfigSection>
    @State private var showClipboardNote = false

    init(mode: Mode, config: PerchConfig, onConfirm: @escaping (Set<ConfigSection>) -> Void) {
        self.mode = mode
        self.config = config
        self.onConfirm = onConfirm
        // Default: everything that actually has something in it.
        _selected = State(initialValue: Set(ConfigSection.allCases.filter { $0.hasContent(in: config) }))
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text(mode == .export ? "Export Settings" : "Import Settings").font(.headline)
                Text(mode == .export
                     ? "Choose what to save to the file."
                     : "Choose what to bring in. Unchecked sections keep your current settings.")
                    .font(.system(size: 12)).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 10)

            Divider()

            ScrollView {
                VStack(spacing: 2) {
                    ForEach(ConfigSection.allCases) { row($0) }
                }
                .padding(8)
            }

            Divider()

            HStack {
                Button(allSelected ? "Deselect All" : "Select All") { toggleAll() }
                    .buttonStyle(.link)
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button(confirmTitle) { onConfirm(selected); dismiss() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(selected.isEmpty)
            }
            .padding(12)
        }
        .frame(width: 540, height: 480)   // match the app/action picker sheets
    }

    private var allSelected: Bool {
        selected.count == ConfigSection.allCases.filter { $0.hasContent(in: config) }.count
    }

    private func toggleAll() {
        selected = allSelected ? [] : Set(ConfigSection.allCases.filter { $0.hasContent(in: config) })
    }

    private var confirmTitle: String {
        let verb = mode == .export ? "Export" : "Import"
        return selected.isEmpty ? verb : "\(verb) \(selected.count)"
    }

    private func row(_ s: ConfigSection) -> some View {
        let on = selected.contains(s)
        let empty = !s.hasContent(in: config)
        return HStack(spacing: 12) {
            Image(systemName: on ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(on ? Color.accentColor : .secondary)
            Image(systemName: s.icon).frame(width: 22).foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(s.title).font(.system(size: 13, weight: .medium))
                Text(empty ? "nothing to \(mode == .export ? "export" : "import")" : s.summary(in: config))
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Spacer()
            if mode == .export, s == .clipboard {
                Button { showClipboardNote = true } label: {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 13)).foregroundStyle(.orange)
                }
                .buttonStyle(.borderless)
                .help("Only text is exported — images and files are skipped.")
                .popover(isPresented: $showClipboardNote, arrowEdge: .bottom) {
                    Text("Only text items are exported.\n\nImages and files are skipped so the backup stays small and portable.")
                        .font(.system(size: 12))
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(12).frame(width: 240)
                }
            }
        }
        .padding(.vertical, 7).padding(.horizontal, 8)
        .background(on ? AnyShapeStyle(.selection) : AnyShapeStyle(.clear))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .contentShape(Rectangle())
        .opacity(empty ? 0.45 : 1)
        .onTapGesture {
            guard !empty else { return }
            if on { selected.remove(s) } else { selected.insert(s) }
        }
    }
}
