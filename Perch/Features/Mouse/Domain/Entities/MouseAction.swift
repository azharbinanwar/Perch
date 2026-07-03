//
//  MouseAction.swift
//  Perch
//
//  What a mouse trigger does. `MouseActionKind` is the pickable catalogue — every case
//  defines all of its metadata in ONE record (name / icon / category / description /
//  tryable / target / premium). `MouseAction` pairs a kind with its optional target.
//  How an action actually fires lives in MouseActionRunner, not here.
//

import Foundation

// MARK: - Categories (picker sections, in display order)

enum MouseActionGroup: String, CaseIterable, Identifiable {
    case none, editing, navigation, window, media, perch, clicks, launch, custom, automation
    var id: String { rawValue }

    var title: String {
        switch self {
        case .none:       return "None"
        case .editing:    return "Editing"
        case .navigation: return "Navigation"
        case .window:     return "Window & System"
        case .media:      return "Media"
        case .perch:      return "Perch"
        case .clicks:     return "Clicks"
        case .launch:     return "Launch"
        case .custom:     return "Custom"
        case .automation: return "Automation (Premium)"
        }
    }
}

// MARK: - Target a kind needs (drives the "…" prompt)

enum MouseActionTarget {
    case none, app, file, url, keystroke, appleScript, shellScript, shortcut, macro
}

// MARK: - Pickable catalogue

enum MouseActionKind: String, Codable, CaseIterable, Identifiable {
    case disabled, passThrough
    case copy, cut, paste, pastePlain, undo, redo, selectAll, deleteKey
    case back, forward, missionControl, appExpose, spotlight, prevSpace, nextSpace
    case screenshotArea, screenshotWindow, screenshotFull, screenshotTool
    case minimizeWindow, closeWindow, lockScreen
    case playPause, nextTrack, prevTrack, volumeUp, volumeDown, mute, brightnessUp, brightnessDown
    case openClipboard, pasteLast
    case doubleClick, tripleClick, middleClick
    case openApp, openFile, openURL
    case customKeystroke
    case runShortcut, runAppleScript, runShell, macro

    var id: String { rawValue }

    /// Everything about a kind, in one place.
    struct Meta {
        let name: String
        let icon: String
        let category: MouseActionGroup
        let description: String           // plain "what it does"
        let tryable: Bool                 // can it be previewed here (self-contained)?
        let target: MouseActionTarget     // what the picker prompts for
        let premium: Bool
    }

    // Convenience accessors — all read from the single record.
    var title: String { meta.name }
    var icon: String { meta.icon }
    var group: MouseActionGroup { meta.category }
    var detail: String { meta.description }
    var isTryable: Bool { meta.tryable }
    var target: MouseActionTarget { meta.target }
    var isPremium: Bool { meta.premium }

    var meta: Meta {
        switch self {
        case .disabled:        return .init(name: "Disabled", icon: "nosign", category: .none, description: "Does nothing.", tryable: false, target: .none, premium: false)
        case .passThrough:     return .init(name: "Pass Through", icon: "arrowshape.turn.up.right", category: .none, description: "Leaves the button as its normal click.", tryable: false, target: .none, premium: false)

        case .copy:            return .init(name: "Copy", icon: "doc.on.doc", category: .editing, description: "Copies the selection (⌘C).", tryable: false, target: .none, premium: false)
        case .cut:             return .init(name: "Cut", icon: "scissors", category: .editing, description: "Cuts the selection (⌘X).", tryable: false, target: .none, premium: false)
        case .paste:           return .init(name: "Paste", icon: "doc.on.clipboard", category: .editing, description: "Pastes (⌘V).", tryable: false, target: .none, premium: false)
        case .pastePlain:      return .init(name: "Paste as Plain Text", icon: "doc.plaintext", category: .editing, description: "Pastes without formatting.", tryable: false, target: .none, premium: false)
        case .undo:            return .init(name: "Undo", icon: "arrow.uturn.backward", category: .editing, description: "Undo (⌘Z).", tryable: false, target: .none, premium: false)
        case .redo:            return .init(name: "Redo", icon: "arrow.uturn.forward", category: .editing, description: "Redo (⌘⇧Z).", tryable: false, target: .none, premium: false)
        case .selectAll:       return .init(name: "Select All", icon: "selection.pin.in.out", category: .editing, description: "Selects everything (⌘A).", tryable: false, target: .none, premium: false)
        case .deleteKey:       return .init(name: "Delete", icon: "delete.left", category: .editing, description: "Presses Delete.", tryable: false, target: .none, premium: false)

        case .back:            return .init(name: "Back", icon: "chevron.left", category: .navigation, description: "Go back (⌘[) — browsers, Finder.", tryable: false, target: .none, premium: false)
        case .forward:         return .init(name: "Forward", icon: "chevron.right", category: .navigation, description: "Go forward (⌘]).", tryable: false, target: .none, premium: false)
        case .missionControl:  return .init(name: "Mission Control", icon: "square.grid.3x3", category: .navigation, description: "Shows all your open windows.", tryable: true, target: .none, premium: false)
        case .appExpose:       return .init(name: "App Exposé", icon: "square.on.square", category: .navigation, description: "Shows the current app's windows.", tryable: true, target: .none, premium: false)
        case .spotlight:       return .init(name: "Spotlight", icon: "magnifyingglass", category: .navigation, description: "Opens Spotlight search.", tryable: true, target: .none, premium: false)
        case .prevSpace:       return .init(name: "Previous Space", icon: "arrow.left.to.line", category: .navigation, description: "Switches to the desktop on the left.", tryable: true, target: .none, premium: false)
        case .nextSpace:       return .init(name: "Next Space", icon: "arrow.right.to.line", category: .navigation, description: "Switches to the desktop on the right.", tryable: true, target: .none, premium: false)

        case .screenshotArea:  return .init(name: "Screenshot – Area", icon: "camera.viewfinder", category: .window, description: "Screenshot of a selected area.", tryable: true, target: .none, premium: false)
        case .screenshotWindow: return .init(name: "Screenshot – Window", icon: "macwindow", category: .window, description: "Screenshot of a window.", tryable: true, target: .none, premium: false)
        case .screenshotFull:  return .init(name: "Screenshot – Full", icon: "camera", category: .window, description: "Screenshot of the whole screen.", tryable: true, target: .none, premium: false)
        case .screenshotTool:  return .init(name: "Screenshot – Tool", icon: "camera.on.rectangle", category: .window, description: "Opens the screenshot toolbar.", tryable: true, target: .none, premium: false)
        case .minimizeWindow:  return .init(name: "Minimize Window", icon: "minus.rectangle", category: .window, description: "Minimizes the front window (⌘M).", tryable: false, target: .none, premium: false)
        case .closeWindow:     return .init(name: "Close Window", icon: "xmark.rectangle", category: .window, description: "Closes the front window (⌘W).", tryable: false, target: .none, premium: false)
        case .lockScreen:      return .init(name: "Lock Screen", icon: "lock", category: .window, description: "Locks the screen.", tryable: true, target: .none, premium: false)

        case .playPause:       return .init(name: "Play/Pause", icon: "playpause", category: .media, description: "Play / pause media.", tryable: true, target: .none, premium: false)
        case .nextTrack:       return .init(name: "Next Track", icon: "forward.end", category: .media, description: "Next track.", tryable: true, target: .none, premium: false)
        case .prevTrack:       return .init(name: "Previous Track", icon: "backward.end", category: .media, description: "Previous track.", tryable: true, target: .none, premium: false)
        case .volumeUp:        return .init(name: "Volume Up", icon: "speaker.wave.3", category: .media, description: "Volume up.", tryable: true, target: .none, premium: false)
        case .volumeDown:      return .init(name: "Volume Down", icon: "speaker.wave.1", category: .media, description: "Volume down.", tryable: true, target: .none, premium: false)
        case .mute:            return .init(name: "Mute", icon: "speaker.slash", category: .media, description: "Mute / unmute.", tryable: true, target: .none, premium: false)
        case .brightnessUp:    return .init(name: "Brightness Up", icon: "sun.max", category: .media, description: "Brightness up.", tryable: true, target: .none, premium: false)
        case .brightnessDown:  return .init(name: "Brightness Down", icon: "sun.min", category: .media, description: "Brightness down.", tryable: true, target: .none, premium: false)

        case .openClipboard:   return .init(name: "Open Clipboard", icon: "doc.on.clipboard", category: .perch, description: "Opens the Perch clipboard popup.", tryable: true, target: .none, premium: false)
        case .pasteLast:       return .init(name: "Paste Last Item", icon: "clock.arrow.circlepath", category: .perch, description: "Pastes your last clipboard item.", tryable: false, target: .none, premium: false)

        case .doubleClick:     return .init(name: "Double-Click", icon: "cursorarrow.click.2", category: .clicks, description: "Double-clicks where the pointer is.", tryable: false, target: .none, premium: false)
        case .tripleClick:     return .init(name: "Triple-Click", icon: "cursorarrow.click", category: .clicks, description: "Triple-clicks where the pointer is.", tryable: false, target: .none, premium: false)
        case .middleClick:     return .init(name: "Middle-Click", icon: "cursorarrow", category: .clicks, description: "Middle-clicks — e.g. close a browser tab.", tryable: false, target: .none, premium: false)

        case .openApp:         return .init(name: "Open App…", icon: "app", category: .launch, description: "Opens an app you choose.", tryable: false, target: .app, premium: false)
        case .openFile:        return .init(name: "Open File/Folder…", icon: "folder", category: .launch, description: "Opens a file or folder you choose.", tryable: false, target: .file, premium: false)
        case .openURL:         return .init(name: "Open URL…", icon: "link", category: .launch, description: "Opens a web address you choose.", tryable: false, target: .url, premium: false)

        case .customKeystroke: return .init(name: "Custom Keystroke…", icon: "keyboard", category: .custom, description: "Sends a keyboard shortcut you record.", tryable: false, target: .keystroke, premium: false)

        case .runShortcut:     return .init(name: "Run Apple Shortcut…", icon: "sparkles", category: .automation, description: "Runs an Apple Shortcut.", tryable: false, target: .shortcut, premium: true)
        case .runAppleScript:  return .init(name: "Run AppleScript…", icon: "applescript", category: .automation, description: "Runs an AppleScript.", tryable: false, target: .appleScript, premium: true)
        case .runShell:        return .init(name: "Run Shell Script…", icon: "terminal", category: .automation, description: "Runs a shell script.", tryable: false, target: .shellScript, premium: true)
        case .macro:           return .init(name: "Macro (key sequence)…", icon: "list.bullet", category: .automation, description: "Plays a sequence of keys.", tryable: false, target: .macro, premium: true)
        }
    }

    /// Kinds in a category, catalogue order.
    static func inGroup(_ group: MouseActionGroup) -> [MouseActionKind] {
        allCases.filter { $0.group == group }
    }
}

// MARK: - A concrete action (kind + its target)

struct MouseAction: Codable, Equatable {
    var kind: MouseActionKind
    var target: String?      // bundle id / file path / URL / script text / shortcut name
    var keyCode: Int?        // for .customKeystroke
    var modifiers: UInt64?   // for .customKeystroke

    static let disabled = MouseAction(kind: .disabled)

    init(kind: MouseActionKind, target: String? = nil, keyCode: Int? = nil, modifiers: UInt64? = nil) {
        self.kind = kind
        self.target = target
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    /// Row label: the kind's name, plus the chosen target when it has one.
    var displayLabel: String {
        switch kind.target {
        case .keystroke:
            let mods = modifiers.map(MouseTrigger.modifierSymbols) ?? ""
            return keyCode.map { "\(mods)key\($0)" } ?? kind.title
        case .none:
            return kind.title
        default:
            if let target, !target.isEmpty { return "\(kind.title.replacingOccurrences(of: "…", with: "")): \(target)" }
            return kind.title
        }
    }
}
