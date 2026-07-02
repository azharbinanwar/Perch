//
//  RemapTabView.swift
//  Perch
//
//  Main-window Keys page: enable, add/remove maps, per-map toggle.
//

import SwiftUI

struct RemapTabView: View {
    @Environment(RemapViewModel.self) private var vm
    @State private var newKey = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Key Remapper").font(.title2.bold())
                Spacer()
                Toggle("", isOn: Binding(get: { vm.isEnabled }, set: { _ in vm.toggleEnabled() }))
                    .toggleStyle(.switch)
                    .labelsHidden()
            }

            Text("Remaps **Ctrl + key → Cmd + key**. Terminal is excluded so Ctrl+C still interrupts.")
                .foregroundStyle(.secondary)

            if vm.needsPermission {
                Label("Needs Accessibility permission — grant it in General.", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
            }

            HStack {
                TextField("key (e.g. c)", text: $newKey)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 120)
                Button("Add") {
                    vm.addRule(keyChar: newKey)
                    newKey = ""
                }
                .disabled(newKey.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            List {
                ForEach(vm.rules) { rule in
                    HStack {
                        Toggle(isOn: Binding(get: { rule.isEnabled }, set: { _ in vm.toggleRule(rule) })) {
                            Text("⌃\(rule.keyChar.uppercased())   →   ⌘\(rule.keyChar.uppercased())")
                                .font(.system(.body, design: .monospaced))
                        }
                        Spacer()
                        Button(role: .destructive) { vm.removeRule(rule) } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                    }
                }
            }
            .listStyle(.inset)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
