//
//  MouseTabView.swift
//  Perch
//

import SwiftUI

struct MouseTabView: View {
    @Environment(MouseViewModel.self) private var mouse

    private var trusted: Bool { AccessibilityService.shared.isTrusted }
    private var monitoring: Bool { InputMonitoringService.shared.isTrusted }
    private var moduleActive: Bool { trusted && mouse.masterEnabled }
    // We can only be sure there's no mouse when Input Monitoring is on (detection needs it).
    private var showNoMouse: Bool { moduleActive && monitoring && !mouse.hasMouse }
    @State private var showingReset = false
    @State private var showingMouseIntro = false
    @State private var showingMonitorIntro = false
    @State private var addingProfile = false
    @State private var profileIntroShowing = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    PageHeader("Mouse", subtitle: mouse.deviceSubtitle)
                    Spacer()
                    if trusted && mouse.masterEnabled {
                        HeaderIconButton(icon: "arrow.counterclockwise",
                                         help: "Reset Mouse settings to default — your mappings, gestures and profiles aren't affected") {
                            showingReset = true
                        }
                    }
                }
                if !trusted {
                    PermissionTile(
                        icon: "cursorarrow.click",
                        title: "Accessibility needed",
                        message: "Perch needs Accessibility to remap your mouse buttons, gestures and scroll.",
                        onGrant: { AccessibilityService.shared.request() },
                        onShowIntro: { showingMouseIntro = true })
                }
                if !monitoring {
                    PermissionTile(
                        icon: "cable.connector",
                        title: "Input Monitoring (optional)",
                        message: "Allow Input Monitoring to see your connected mouse and its details. Remapping works without it.",
                        grantTitle: "Allow",
                        onGrant: { InputMonitoringService.shared.openSettings() },
                        onShowIntro: { showingMonitorIntro = true })
                }
                SettingGroup {
                    SettingRow(title: "Enable Mouse",
                               subtitle: "Master switch for the whole tab — buttons, scroll, pointer and gestures. Applies to all mice.",
                               icon: "magicmouse") {
                        SwitchToggle(isOn: mouse.masterEnabled) { mouse.setMasterEnabled($0) }
                    }
                }
                .disabled(!trusted)
                .opacity(trusted ? 1 : 0.5)
                Group {
                    if showNoMouse {
                        ContentUnavailableView("No mouse connected",
                                               systemImage: "magicmouse",
                                               description: Text("Connect a mouse to configure buttons, scroll and gestures."))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                    } else {
                    SettingGroup {
                        AppProfileStrip(
                            items: [AppProfileStrip.Item(bundleID: nil, name: "All apps")]
                                + mouse.appProfiles.map { AppProfileStrip.Item(bundleID: $0.appBundleID, name: $0.displayName) },
                            selectedBundleID: mouse.editingBundleID,
                            subtitle: mouse.isEditingDefault
                                ? "Applies to every app without its own profile."
                                : "Active only while \(mouse.editingProfileName) is frontmost.",
                            onSelect: { mouse.selectProfile($0) },
                            onAdd: { addingProfile = true },
                            onRemove: { bundleID in mouse.selectProfile(bundleID); mouse.removeEditingProfile() },
                            onInfo: { profileIntroShowing = true }
                        )
                    }
                    ButtonsGroup()
                    MouseShiftGroup()
                    SettingGroup {
                        SettingRow(title: "Swap primary & secondary buttons",
                                   subtitle: "Left-handed use — left click becomes right click and vice versa.",
                                   icon: "arrow.left.arrow.right") {
                            SwitchToggle(isOn: mouse.swapButtons) { mouse.setSwapButtons($0) }
                        }
                    }
                    .opacity(mouse.isEnabled ? 1 : 0.5)
                    .disabled(!mouse.isEnabled)
                    PointerGroup()
                    ScrollGroup()
                    ReliabilityGroup()
                    }
                }
                .opacity(moduleActive ? 1 : 0.4)
                .disabled(!moduleActive)
            }
            .padding(20)
        }
        .sheet(isPresented: $showingMouseIntro) {
            ShowcaseSheet(title: "Mouse", content: AnyView(MouseIntroView()))
        }
        .sheet(isPresented: $showingMonitorIntro) {
            ShowcaseSheet(title: "Input Monitoring", content: AnyView(InputMonitoringIntroView()))
        }
        .onAppear {
            AccessibilityService.shared.refresh()
            mouse.refreshDevices()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            mouse.refreshDevices()   // granted Input Monitoring in System Settings → detect on return
        }
        .onDisappear { mouse.stopScan() }
        .sheet(isPresented: $addingProfile) {
            AppPickerSheet { ids in ids.forEach { mouse.addProfile(bundleID: $0) } }
        }
        .sheet(isPresented: $profileIntroShowing) { MouseProfileIntroSheet() }
        .alert("Reset Mouse to default?", isPresented: $showingReset) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) {
                ConfigService.resetAll(prefix: "mouse.")
                mouse.reload()
            }
        } message: {
            Text("""
            This clears everything on the Mouse tab and can't be undone:
            • All button mappings and gestures
            • Detected & added buttons
            • Every per-app profile
            • Pointer, scrolling and reliability settings
            """)
        }
    }

}
