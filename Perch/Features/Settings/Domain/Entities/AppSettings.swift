//
//  AppSettings.swift
//  Perch
//
//  How many clipboard items to show in the menu, and launch-at-login.
//  (The clipboard's own "keep up to" size lives in ClipboardViewModel.)
//

import Foundation

struct AppSettings: Codable, Equatable {
    var menuItemCount: Int   // items shown in the menu-bar dropdown (kept small)
    var openAtLogin: Bool

    static let `default` = AppSettings(menuItemCount: 10, openAtLogin: true)
}
