//
//  Action.swift
//  Perch
//
//  What a mouse trigger does. `ActionKind` is the pickable catalogue — every case
//  defines all of its metadata in ONE record (name / icon / category / description /
//  tryable / target / premium). `Action` pairs a kind with its optional target.
//  How an action actually fires lives in ActionRunner, not here.
//

import CoreGraphics
import Foundation

// MARK: - Categories (picker sections, in display order)

enum ActionGroup: String, CaseIterable, Identifiable {
    case none, editing, navigation, view, layout, window, media, perch, clicks, launch, custom, automation
    var id: String { rawValue }

    var title: String {
        switch self {
        case .none:       return "None"
        case .editing:    return "Editing"
        case .navigation: return "Navigation"
        case .view:       return "View"
        case .layout:     return "Window Layout"
        case .window:     return "Window & System"
        case .media:      return "Media"
        case .perch:      return "Perch"
        case .clicks:     return "Clicks"
        case .launch:     return "Launch"
        case .custom:     return "Custom"
        case .automation: return "Automation"
        }
    }
}

// MARK: - Target a kind needs (drives the "…" prompt)

enum ActionTarget {
    case none, app, file, url, keystroke, appleScript, shellScript, shortcut, macro
}

// MARK: - Pickable catalogue

enum ActionKind: String, Codable, CaseIterable, Identifiable {
    case disabled, passThrough
    case copy, cut, paste, pastePlain, undo, redo, selectAll, deleteKey
    case find, save, emojiPicker
    case back, forward, missionControl, appExpose, spotlight, prevSpace, nextSpace
    case zoomIn, zoomOut
    case screenshotArea, screenshotWindow, screenshotFull, screenshotTool
    case minimizeWindow, closeWindow, quitApp, hideApp, forceQuit, toggleFullScreen, lockScreen
    case windowLeftHalf, windowRightHalf, windowMaximize, windowCenter
    case playPause, nextTrack, prevTrack, volumeUp, volumeDown, mute, brightnessUp, brightnessDown
    case openClipboard, pasteLast
    case doubleClick, tripleClick, middleClick
    case openApp, openFile, openURL
    case customKeystroke
    case runAppleScript, runShell

    var id: String { rawValue }

    /// Everything about a kind, in one place.
    struct Meta {
        let name: String
        let icon: String
        let category: ActionGroup
        let description: String           // plain "what it does"
        let tryable: Bool                 // can it be previewed here (self-contained)?
        let target: ActionTarget     // what the picker prompts for
        let premium: Bool
    }

    // Convenience accessors — all read from the single record.
    var title: String { meta.name }
    var icon: String { meta.icon }
    var group: ActionGroup { meta.category }
    var detail: String { meta.description }
    var isTryable: Bool { meta.tryable }
    var target: ActionTarget { meta.target }
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
        case .find:            return .init(name: "Find", icon: "text.magnifyingglass", category: .editing, description: "Opens Find (⌘F).", tryable: false, target: .none, premium: false)
        case .save:            return .init(name: "Save", icon: "square.and.arrow.down", category: .editing, description: "Saves (⌘S).", tryable: false, target: .none, premium: false)
        case .emojiPicker:     return .init(name: "Emoji & Symbols", icon: "face.smiling", category: .editing, description: "Opens the emoji & symbols viewer (⌃⌘Space).", tryable: true, target: .none, premium: false)

        case .back:            return .init(name: "Back", icon: "chevron.left", category: .navigation, description: "Go back (⌘[) — browsers, Finder.", tryable: false, target: .none, premium: false)
        case .forward:         return .init(name: "Forward", icon: "chevron.right", category: .navigation, description: "Go forward (⌘]).", tryable: false, target: .none, premium: false)
        case .missionControl:  return .init(name: "Mission Control", icon: "square.grid.3x3", category: .navigation, description: "Shows all your open windows.", tryable: true, target: .none, premium: false)
        case .appExpose:       return .init(name: "App Exposé", icon: "square.on.square", category: .navigation, description: "Shows the current app's windows.", tryable: true, target: .none, premium: false)
        case .spotlight:       return .init(name: "Spotlight", icon: "magnifyingglass", category: .navigation, description: "Opens Spotlight search.", tryable: true, target: .none, premium: false)
        case .prevSpace:       return .init(name: "Previous Space", icon: "arrow.left.to.line", category: .navigation, description: "Switches to the desktop on the left.", tryable: true, target: .none, premium: false)
        case .nextSpace:       return .init(name: "Next Space", icon: "arrow.right.to.line", category: .navigation, description: "Switches to the desktop on the right.", tryable: true, target: .none, premium: false)
        case .zoomIn:          return .init(name: "Zoom In", icon: "plus.magnifyingglass", category: .view, description: "Zooms in (⌘+) — browsers, editors, Finder.", tryable: false, target: .none, premium: false)
        case .zoomOut:         return .init(name: "Zoom Out", icon: "minus.magnifyingglass", category: .view, description: "Zooms out (⌘−).", tryable: false, target: .none, premium: false)

        case .screenshotArea:  return .init(name: "Screenshot – Area", icon: "camera.viewfinder", category: .window, description: "Screenshot of a selected area.", tryable: true, target: .none, premium: false)
        case .screenshotWindow: return .init(name: "Screenshot – Window", icon: "macwindow", category: .window, description: "Screenshot of a window.", tryable: true, target: .none, premium: false)
        case .screenshotFull:  return .init(name: "Screenshot – Full", icon: "camera", category: .window, description: "Screenshot of the whole screen.", tryable: true, target: .none, premium: false)
        case .screenshotTool:  return .init(name: "Screenshot – Tool", icon: "camera.on.rectangle", category: .window, description: "Opens the screenshot toolbar.", tryable: true, target: .none, premium: false)
        case .minimizeWindow:  return .init(name: "Minimize Window", icon: "minus.rectangle", category: .layout, description: "Minimizes the front window (⌘M).", tryable: false, target: .none, premium: false)
        case .closeWindow:     return .init(name: "Close Window", icon: "xmark.rectangle", category: .window, description: "Closes the front window (⌘W).", tryable: false, target: .none, premium: false)
        case .quitApp:         return .init(name: "Quit App", icon: "xmark.circle", category: .window, description: "Quits the front app.", tryable: false, target: .none, premium: false)
        case .hideApp:         return .init(name: "Hide App", icon: "eye.slash", category: .window, description: "Hides the front app.", tryable: false, target: .none, premium: false)
        case .forceQuit:       return .init(name: "Force Quit App", icon: "exclamationmark.octagon", category: .window, description: "Immediately force-quits the front app.", tryable: false, target: .none, premium: false)
        case .toggleFullScreen: return .init(name: "Toggle Full Screen", icon: "arrow.up.left.and.arrow.down.right", category: .layout, description: "Enters or exits full screen (⌃⌘F).", tryable: false, target: .none, premium: false)
        case .lockScreen:      return .init(name: "Lock Screen", icon: "lock", category: .window, description: "Locks the screen (⌃⌘Q).", tryable: true, target: .none, premium: false)
        case .windowLeftHalf:  return .init(name: "Window – Left Half", icon: "rectangle.lefthalf.filled", category: .layout, description: "Snaps the front window to the left half of the screen.", tryable: false, target: .none, premium: false)
        case .windowRightHalf: return .init(name: "Window – Right Half", icon: "rectangle.righthalf.filled", category: .layout, description: "Snaps the front window to the right half of the screen.", tryable: false, target: .none, premium: false)
        case .windowMaximize:  return .init(name: "Window – Maximize", icon: "rectangle.inset.filled", category: .layout, description: "Fills the screen with the front window (not full-screen mode).", tryable: false, target: .none, premium: false)
        case .windowCenter:    return .init(name: "Window – Center", icon: "rectangle.center.inset.filled", category: .layout, description: "Centers the front window without resizing it.", tryable: false, target: .none, premium: false)

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

        case .runAppleScript:  return .init(name: "Run AppleScript…", icon: "applescript", category: .automation, description: "Runs AppleScript you enter.", tryable: false, target: .appleScript, premium: false)
        case .runShell:        return .init(name: "Run Shell Script…", icon: "terminal", category: .automation, description: "Runs a shell command you enter.", tryable: false, target: .shellScript, premium: false)
        }
    }

    /// Kinds in a category, catalogue order.
    static func inGroup(_ group: ActionGroup) -> [ActionKind] {
        allCases.filter { $0.group == group }
    }

    /// The single keystroke this kind performs, when it's just one shortcut. Source of truth for
    /// both running (ActionRunner) and display. nil for actions that aren't a plain keypress.
    var shortcut: (code: CGKeyCode, flags: CGEventFlags)? {
        switch self {
        case .copy:             return (8,  .maskCommand)
        case .cut:              return (7,  .maskCommand)
        case .paste:            return (9,  .maskCommand)
        case .pastePlain:       return (9,  [.maskCommand, .maskShift, .maskAlternate])
        case .undo:             return (6,  .maskCommand)
        case .redo:             return (6,  [.maskCommand, .maskShift])
        case .selectAll:        return (0,  .maskCommand)
        case .deleteKey:        return (51, [])
        case .find:             return (3,  .maskCommand)                    // ⌘F
        case .save:             return (1,  .maskCommand)                    // ⌘S
        case .emojiPicker:      return (49, [.maskControl, .maskCommand])    // ⌃⌘Space
        case .back:             return (33, .maskCommand)                    // ⌘[
        case .forward:          return (30, .maskCommand)                    // ⌘]
        case .appExpose:        return (125, .maskControl)                   // ⌃↓
        case .spotlight:        return (49, .maskCommand)                    // ⌘Space
        case .prevSpace:        return (123, .maskControl)                   // ⌃←
        case .nextSpace:        return (124, .maskControl)                   // ⌃→
        case .zoomIn:           return (24, .maskCommand)                    // ⌘= (the "+" key)
        case .zoomOut:          return (27, .maskCommand)                    // ⌘−
        case .screenshotArea:   return (21, [.maskCommand, .maskShift])      // ⌘⇧4
        case .screenshotFull:   return (20, [.maskCommand, .maskShift])      // ⌘⇧3
        case .screenshotTool:   return (23, [.maskCommand, .maskShift])      // ⌘⇧5
        case .minimizeWindow:   return (46, .maskCommand)                    // ⌘M
        case .closeWindow:      return (13, .maskCommand)                    // ⌘W
        case .toggleFullScreen: return (3,  [.maskControl, .maskCommand])    // ⌃⌘F
        case .lockScreen:       return (12, [.maskCommand, .maskControl])    // ⌃⌘Q
        default:                return nil
        }
    }

    /// The shortcut as symbols (⌘C) for display, when the kind is a plain keypress.
    var shortcutSymbols: String? {
        guard let s = shortcut else { return nil }
        return KeyCombo(keyCode: Int(s.code), modifiers: s.flags.rawValue).displayName
    }
}

// MARK: - A concrete action (kind + its target)

struct Action: Codable, Equatable {
    var kind: ActionKind
    var target: String?      // bundle id / file path / URL / script text / shortcut name
    var keyCode: Int?        // for .customKeystroke
    var modifiers: UInt64?   // for .customKeystroke

    static let disabled = Action(kind: .disabled)

    init(kind: ActionKind, target: String? = nil, keyCode: Int? = nil, modifiers: UInt64? = nil) {
        self.kind = kind
        self.target = target
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    /// Row label: the kind's name, plus the chosen target when it has one.
    var displayLabel: String {
        switch kind.target {
        case .keystroke:
            return keyCode.map { KeyCombo(keyCode: $0, modifiers: modifiers ?? 0).displayName } ?? kind.title
        case .none:
            if let sym = kind.shortcutSymbols { return "\(kind.title)  \(sym)" }
            return kind.title
        case .app:
            guard let bundle = target, !bundle.isEmpty else { return kind.title }
            return "\(kind.title.replacingOccurrences(of: "…", with: "")): \(AppIcon.name(forBundleID: bundle) ?? bundle)"
        default:
            if let target, !target.isEmpty { return "\(kind.title.replacingOccurrences(of: "…", with: "")): \(target)" }
            return kind.title
        }
    }
}
