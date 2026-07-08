//
//  SnippetSettingsSheet.swift
//  Perch
//
//  All expansion configuration in one place — moved out of the tab so the snippet list
//  stays the hero. Standard sheet layout (header / content / footer) like the app's others.
//

import SwiftUI

struct SnippetSettingsSheet: View {
    @Environment(SnippetViewModel.self) private var vm
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Text Expansion").font(.headline)
                Text("How abbreviations behave when you type them in other apps.")
                    .font(.system(size: 12)).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20).padding(.top, 18).padding(.bottom, 14)

            Divider()

            ScrollView {
                VStack(spacing: 10) {
                    if vm.expansionEnabled {
                        SettingRow(title: "Trigger prefix",
                                   subtitle: "Wraps every abbreviation, so normal typing never expands by accident.",
                                   icon: "textformat") {
                            Picker("", selection: Binding(get: { vm.expansionPrefix }, set: { vm.setExpansionPrefix($0) })) {
                                ForEach(ExpansionPrefix.allCases) { prefix in
                                    Text(prefix.rawValue).font(.system(.body, design: .monospaced)).tag(prefix)
                                }
                            }
                            .labelsHidden().frame(width: 80)
                        }
                        Divider()
                        SettingRow(title: "Date format",
                                   subtitle: "How the {date} placeholder is written when a snippet is inserted.",
                                   icon: "calendar") {
                            Picker("", selection: Binding(get: { vm.dateFormat }, set: { vm.setDateFormat($0) })) {
                                ForEach(SnippetPlaceholders.dateFormats, id: \.self) { pattern in
                                    Text(SnippetPlaceholders.example(pattern)).tag(pattern)
                                }
                            }
                            .labelsHidden().frame(width: 190)
                        }
                        Divider()
                        AppExcludeList(
                            title: "Don't expand here",
                            subtitle: "Abbreviations are ignored while these apps are focused.",
                            icon: "hand.raised.slash",
                            bundleIDs: vm.excludedApps,
                            onAdd: { vm.addExcludedApps([$0]) },
                            onRemove: { vm.removeExcludedApp($0) }
                        )
                        Label("Placeholders: {date} · {time} · {clipboard} — replaced with live values the moment a snippet is inserted. {cursor} puts the caret there after expansion.",
                              systemImage: "curlybraces")
                            .font(.system(size: 11)).foregroundStyle(.secondary)
                    } else {
                        ContentUnavailableView(
                            "Expansion is off",
                            systemImage: "text.badge.xmark",
                            description: Text("Turn on “Enable Snippets” to set the trigger prefix, date format, and excluded apps."))
                    }
                }
                .padding(20)
            }

            Divider()

            HStack {
                Spacer()
                Button("Done") { dismiss() }.keyboardShortcut(.defaultAction)
            }
            .padding(16)
        }
        .frame(width: 540, height: 480)
    }
}
