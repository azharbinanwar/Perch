//
//  AppPickerSheet.swift
//  Perch
//
//  Reusable searchable, multi-select app picker. Returns the chosen bundle ids.
//

import SwiftUI

struct AppPickerSheet: View {
    var allowsMultipleSelection = true   // false = tap an app to pick it and close (e.g. "Open App")
    let onAdd: ([String]) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var search = ""
    @State private var selected: Set<String> = []

    private let apps = AppCatalog.installedApps()

    private var filtered: [AppCatalog.App] {
        search.isEmpty ? apps : apps.filter { $0.name.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(allowsMultipleSelection ? "Add Apps" : "Choose App").font(.headline)
                Spacer()
            }
            .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 8)

            SearchField(placeholder: "Search apps", text: $search, autofocus: true)
                .padding(.horizontal, 16).padding(.bottom, 8)

            Divider()

            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(filtered) { row($0) }
                }
                .padding(8)
            }

            Divider()

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                if allowsMultipleSelection {
                    Button(selected.isEmpty ? "Add" : "Add \(selected.count)") {
                        onAdd(Array(selected))
                        dismiss()
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(selected.isEmpty)
                }
            }
            .padding(12)
        }
        .frame(width: 540, height: 480)
    }

    private func row(_ app: AppCatalog.App) -> some View {
        let isSelected = selected.contains(app.id)
        return HStack(spacing: 10) {
            Image(nsImage: app.icon).resizable().frame(width: 28, height: 28)
            Text(app.name).font(.system(size: 13))
            Spacer()
            if allowsMultipleSelection {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(isSelected ? AnyShapeStyle(.selection) : AnyShapeStyle(.clear))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .contentShape(Rectangle())
        .onTapGesture {
            if allowsMultipleSelection {
                if isSelected { selected.remove(app.id) } else { selected.insert(app.id) }
            } else {
                onAdd([app.id]); dismiss()   // single-select: pick and close immediately
            }
        }
    }
}
