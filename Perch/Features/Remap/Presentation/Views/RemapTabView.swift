//
//  RemapTabView.swift
//  Perch
//
//  Keys page: a general remapper. Each rule maps an input combo → an output combo, recorded
//  by pressing the keys. Matches the app's grouped, native style.
//

import SwiftUI

struct RemapTabView: View {
    @Environment(RemapViewModel.self) private var vm
    @State private var trusted = Permissions.isAccessibilityTrusted
    @State private var addingRule = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Keys").font(.title2.bold())
                if !trusted {
                    AccessibilityBanner(message: "Grant Accessibility so key remapping can work.")
                }
                mappingsGroup
            }
            .padding(20)
        }
        .onAppear { trusted = Permissions.isAccessibilityTrusted }
        .sheet(isPresented: $addingRule, onDismiss: { vm.clearDraft() }) { captureSheet }
    }

    private var mappingsGroup: some View {
        GroupBox("Remap keys") {
            VStack(alignment: .leading, spacing: 12) {
                SettingRow(title: "Enable remapping",
                           subtitle: "Rewrites each input shortcut to its output. Terminal is excluded so Ctrl+C still interrupts.") {
                    Toggle("", isOn: Binding(get: { vm.isEnabled }, set: { _ in vm.toggleEnabled() }))
                        .toggleStyle(.switch).labelsHidden()
                }
                if vm.needsPermission {
                    Label("Needs Accessibility — grant it in General.", systemImage: "exclamationmark.triangle.fill")
                        .font(.system(size: 12)).foregroundStyle(.orange)
                }
                Divider()

                VStack(spacing: 0) {
                    ForEach(Array(vm.rules.enumerated()), id: \.element.id) { index, rule in
                        if index > 0 { Divider() }
                        ruleRow(rule)
                    }
                }
                .cardBorder()

                HStack {
                    Spacer()
                    Button {
                        vm.clearDraft()
                        addingRule = true
                    } label: { Label("Add mapping", systemImage: "plus") }
                }
            }
            .padding(6)
            .opacity(vm.isEnabled ? 1 : 0.5)
        }
    }

    private func ruleRow(_ rule: RemapRule) -> some View {
        HStack(spacing: 10) {
            Toggle("", isOn: Binding(get: { rule.isEnabled }, set: { _ in vm.toggleRule(rule) }))
                .toggleStyle(.switch).labelsHidden().scaleEffect(0.85)
            comboChip(rule.input.displayName)
            Image(systemName: "arrow.right").font(.system(size: 11)).foregroundStyle(.secondary)
            comboChip(rule.output.displayName)
            Spacer()
            Button(role: .destructive) { vm.removeRule(rule) } label: {
                Image(systemName: "trash").font(.system(size: 12)).foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 10).padding(.vertical, 8)
    }

    // MARK: - Add-mapping sheet

    private var captureSheet: some View {
        VStack(spacing: 18) {
            Text("Add a key mapping").font(.headline)
            Text("Record the shortcut to change, then what it should become.")
                .font(.system(size: 12)).foregroundStyle(.secondary).multilineTextAlignment(.center)

            HStack(spacing: 14) {
                captureField(title: "From", combo: vm.draftInput, active: vm.recording == .input) { vm.record(.input) }
                Image(systemName: "arrow.right").foregroundStyle(.secondary)
                captureField(title: "To", combo: vm.draftOutput, active: vm.recording == .output) { vm.record(.output) }
            }

            if let input = vm.draftInput, vm.draftOutput != nil, vm.rules.contains(where: { $0.input == input }) {
                Text("\(input.displayName) is already mapped.")
                    .font(.system(size: 11)).foregroundStyle(.orange)
            }

            HStack {
                Button("Cancel") { addingRule = false }.keyboardShortcut(.cancelAction)
                Spacer()
                Button("Add") { vm.addDraft(); addingRule = false }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!vm.canAddDraft)
            }
        }
        .padding(24)
        .frame(width: 420)
    }

    private func captureField(title: String, combo: KeyCombo?, active: Bool, record: @escaping () -> Void) -> some View {
        VStack(spacing: 6) {
            Text(title.uppercased()).font(.system(size: 10, weight: .semibold)).foregroundStyle(.tertiary)
            Button(action: record) {
                Text(active ? "Press keys…" : (combo?.displayName ?? "Record"))
                    .font(.system(size: 15, weight: .medium))
                    .frame(width: 130, height: 44)
                    .background(RoundedRectangle(cornerRadius: 8)
                        .fill(active ? Color.accentColor.opacity(0.15) : Color.gray.opacity(0.12)))
                    .overlay(RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(active ? Color.accentColor : Color.gray.opacity(0.4), lineWidth: active ? 1.5 : 1))
            }
            .buttonStyle(.plain)
        }
    }

    private func comboChip(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .medium, design: .rounded))
            .padding(.horizontal, 10).padding(.vertical, 4)
            .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 6))
    }
}

private extension View {
    func cardBorder() -> some View {
        background(RoundedRectangle(cornerRadius: 8).fill(.quaternary.opacity(0.2)))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.quaternary.opacity(0.5)))
    }
}
