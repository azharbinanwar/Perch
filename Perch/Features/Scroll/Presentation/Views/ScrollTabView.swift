//
//  ScrollTabView.swift
//  Perch
//

import SwiftUI

struct ScrollTabView: View {
    @Environment(ScrollViewModel.self) private var vm

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Scroll").font(.title2.bold())
                Spacer()
                Toggle("", isOn: Binding(get: { vm.isEnabled }, set: { _ in vm.toggle() }))
                    .toggleStyle(.switch)
                    .labelsHidden()
            }

            Text("Reverses external **mouse** scroll direction. The trackpad is left untouched.")
                .foregroundStyle(.secondary)

            if vm.needsPermission {
                Label("Needs Accessibility permission — grant it in General.", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
            }

            Spacer()
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
