//
//  ActionPresets.swift
//  Perch
//
//  Ready-made picks for the automation actions so users don't need to know shell/AppleScript
//  syntax. Shell & AppleScript are curated lists; Shortcuts are loaded live from the system.
//  Each preset's `value` is what gets stored as the action's target.
//

import Foundation

struct ActionPreset: Identifiable, Hashable {
    let name: String
    let detail: String
    let value: String        // the command / script / shortcut name stored as target
    var id: String { name + value }
}

enum ActionPresets {

    /// Shell commands run via `/bin/sh -c`. Kept sudo-free so they just work.
    static let shell: [ActionPreset] = [
        .init(name: "Sleep Display",        detail: "Turn the screen off now",              value: "pmset displaysleepnow"),
        .init(name: "Lock Screen",          detail: "Lock the Mac",                          value: "osascript -e 'tell application \"System Events\" to keystroke \"q\" using {control down, command down}'"),
        .init(name: "Start Screen Saver",   detail: "Launch the screen saver",               value: "open -a ScreenSaverEngine"),
        .init(name: "Screenshot Area → Desktop",   detail: "Select an area, save to Desktop", value: "screencapture -i ~/Desktop/screenshot.png"),
        .init(name: "Screenshot Area → Clipboard", detail: "Select an area, copy it",         value: "screencapture -c -i"),
        .init(name: "Screenshot Full",      detail: "Whole screen to Desktop",               value: "screencapture ~/Desktop/screenshot.png"),
        .init(name: "Open Downloads",       detail: "Open your Downloads folder",            value: "open ~/Downloads"),
        .init(name: "Open Home Folder",     detail: "Open your home folder",                 value: "open ~"),
        .init(name: "Open Applications",    detail: "Open the Applications folder",          value: "open /Applications"),
        .init(name: "Empty Trash",          detail: "Empty the Trash",                       value: "osascript -e 'tell app \"Finder\" to empty the trash'"),
        .init(name: "Eject All Disks",      detail: "Eject every removable disk",            value: "osascript -e 'tell application \"Finder\" to eject (every disk whose ejectable is true)'"),
        .init(name: "Show Hidden Files",    detail: "Reveal hidden files in Finder",         value: "defaults write com.apple.finder AppleShowAllFiles -bool true; killall Finder"),
        .init(name: "Hide Hidden Files",    detail: "Hide hidden files in Finder",           value: "defaults write com.apple.finder AppleShowAllFiles -bool false; killall Finder"),
        .init(name: "Restart Finder",       detail: "Relaunch Finder",                       value: "killall Finder"),
        .init(name: "Restart Dock",         detail: "Relaunch the Dock",                     value: "killall Dock"),
        .init(name: "Restart Menu Bar",     detail: "Relaunch SystemUIServer",               value: "killall SystemUIServer"),
        .init(name: "Copy Date & Time",     detail: "Put the current date on the clipboard", value: "date | pbcopy"),
    ]

    /// AppleScript snippets run via `osascript -e`.
    static let appleScript: [ActionPreset] = [
        .init(name: "Toggle Dark Mode",     detail: "Switch between light and dark",         value: "tell application \"System Events\" to tell appearance preferences to set dark mode to not dark mode"),
        .init(name: "Show Notification",    detail: "Post a test notification",              value: "display notification \"Hello from Perch\" with title \"Perch\""),
        .init(name: "Volume Up",            detail: "Raise output volume",                   value: "set volume output volume ((output volume of (get volume settings)) + 10)"),
        .init(name: "Volume Down",          detail: "Lower output volume",                   value: "set volume output volume ((output volume of (get volume settings)) - 10)"),
        .init(name: "Mute",                 detail: "Mute system output",                    value: "set volume with output muted"),
        .init(name: "Unmute",               detail: "Unmute system output",                  value: "set volume without output muted"),
        .init(name: "Set Volume 50%",       detail: "Set output volume to half",             value: "set volume output volume 50"),
        .init(name: "Empty Trash",          detail: "Empty the Trash",                       value: "tell application \"Finder\" to empty the trash"),
        .init(name: "Lock Screen",          detail: "Lock the Mac",                          value: "tell application \"System Events\" to keystroke \"q\" using {control down, command down}"),
        .init(name: "Sleep",                detail: "Put the Mac to sleep",                  value: "tell application \"System Events\" to sleep"),
        .init(name: "Minimize Front Window", detail: "Minimize the front window (⌘M)",       value: "tell application \"System Events\" to keystroke \"m\" using command down"),
        .init(name: "Hide Front App",       detail: "Hide the frontmost app (⌘H)",           value: "tell application \"System Events\" to keystroke \"h\" using command down"),
        .init(name: "Quit Front App",       detail: "Quit the frontmost app (⌘Q)",           value: "tell application \"System Events\" to keystroke \"q\" using command down"),
        .init(name: "New Finder Window",    detail: "Open a new Finder window",              value: "tell application \"Finder\" to make new Finder window"),
    ]
}
