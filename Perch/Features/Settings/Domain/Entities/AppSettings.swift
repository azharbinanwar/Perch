//
//  AppSettings.swift
//  Perch
//
//  App-level preferences: menu-peek count, launch-at-login, open-window-at-launch, show-in-dock.
//  (The clipboard's own "keep up to" size lives in ClipboardViewModel.)
//

import Foundation

/// App-wide appearance. "system" follows macOS; light/dark force it everywhere (all windows).
enum AppTheme: String, Codable, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

struct AppSettings: Codable, Equatable {
    var menuItemCount: Int    // items shown in the menu-bar dropdown (kept small)
    var openAtLogin: Bool
    var openWindowAtLaunch: Bool   // show the main window on launch, else menu-bar only
    var showInDock: Bool           // also keep a Dock icon (else .accessory / menu-bar only)
    var theme: AppTheme            // system / light / dark

    init(menuItemCount: Int = 10, openAtLogin: Bool = true,
         openWindowAtLaunch: Bool = false, showInDock: Bool = false,
         theme: AppTheme = .system) {
        self.menuItemCount = menuItemCount
        self.openAtLogin = openAtLogin
        self.openWindowAtLaunch = openWindowAtLaunch
        self.showInDock = showInDock
        self.theme = theme
    }

    static let `default` = AppSettings()

    // Lenient decode — settings saved before newer keys existed keep loading.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        menuItemCount = try c.decodeIfPresent(Int.self, forKey: .menuItemCount) ?? 10
        openAtLogin = try c.decodeIfPresent(Bool.self, forKey: .openAtLogin) ?? true
        openWindowAtLaunch = try c.decodeIfPresent(Bool.self, forKey: .openWindowAtLaunch) ?? false
        showInDock = try c.decodeIfPresent(Bool.self, forKey: .showInDock) ?? false
        theme = try c.decodeIfPresent(AppTheme.self, forKey: .theme) ?? .system
    }
}
