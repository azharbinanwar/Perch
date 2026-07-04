//
//  AppSettings.swift
//  Perch
//
//  App-level preferences: menu-peek count, launch-at-login, open-window-at-launch, show-in-dock.
//  (The clipboard's own "keep up to" size lives in ClipboardViewModel.)
//

import Foundation

struct AppSettings: Codable, Equatable {
    var menuItemCount: Int    // items shown in the menu-bar dropdown (kept small)
    var openAtLogin: Bool
    var openWindowAtLaunch: Bool   // show the main window on launch, else menu-bar only
    var showInDock: Bool           // also keep a Dock icon (else .accessory / menu-bar only)

    init(menuItemCount: Int = 10, openAtLogin: Bool = true,
         openWindowAtLaunch: Bool = false, showInDock: Bool = false) {
        self.menuItemCount = menuItemCount
        self.openAtLogin = openAtLogin
        self.openWindowAtLaunch = openWindowAtLaunch
        self.showInDock = showInDock
    }

    static let `default` = AppSettings()

    // Lenient decode — settings saved before newer keys existed keep loading.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        menuItemCount = try c.decodeIfPresent(Int.self, forKey: .menuItemCount) ?? 10
        openAtLogin = try c.decodeIfPresent(Bool.self, forKey: .openAtLogin) ?? true
        openWindowAtLaunch = try c.decodeIfPresent(Bool.self, forKey: .openWindowAtLaunch) ?? false
        showInDock = try c.decodeIfPresent(Bool.self, forKey: .showInDock) ?? false
    }
}
