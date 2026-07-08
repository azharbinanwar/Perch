//
//  MouseViewModel+Hotspots.swift
//  Perch
//

import Foundation

struct MouseHotspotMeta {
    let name, sub, icon: String
    let locked, gestures: Bool
}

extension MouseViewModel {
    var additionalTriggers: [MouseTrigger] {
        let extraPhysical = detectedButtons.filter {
            if case .button(let n) = $0 { return n >= 5 } else { return false }
        }
        return extraPhysical + whitelist
    }

    func buttonNumber(_ trigger: MouseTrigger) -> Int? {
        if case .button(let n) = trigger { return n }
        return nil
    }

    func triggerFor(_ id: String) -> MouseTrigger? {
        switch id {
        case "left":   return .button(0)
        case "right":  return .button(1)
        case "middle": return .button(2)
        case "back":   return .button(3)
        case "fwd":    return .button(4)
        case "top":    return additionalTriggers.count > 0 ? additionalTriggers[0] : nil
        case "rup":    return additionalTriggers.count > 1 ? additionalTriggers[1] : nil
        case "rdn":    return additionalTriggers.count > 2 ? additionalTriggers[2] : nil
        default:       return nil
        }
    }

    func hotspotFor(_ trigger: MouseTrigger) -> String? {
        switch trigger {
        case .button(0): return "left"
        case .button(1): return "right"
        case .button(2): return "middle"
        case .button(3): return "back"
        case .button(4): return "fwd"
        default:
            guard let i = additionalTriggers.firstIndex(of: trigger), i < 3 else { return nil }
            return ["top", "rup", "rdn"][i]
        }
    }

    func isActiveHotspot(_ id: String) -> Bool {
        switch id {
        case "left", "right", "middle": return true
        case "back": return detectedButtons.contains(.button(3))
        case "fwd":  return detectedButtons.contains(.button(4))
        case "top":  return additionalTriggers.count > 0
        case "rup":  return additionalTriggers.count > 1
        case "rdn":  return additionalTriggers.count > 2
        default:     return false
        }
    }

    func isMappedHotspot(_ id: String) -> Bool {
        guard let t = triggerFor(id), buttonNumber(t).map({ $0 > 1 }) ?? true else { return false }
        if id == "middle", !gestures.contains(where: { $0.button == 2 }) {
            return mapping(for: t) != nil
        }
        return mapping(for: t) != nil || (id == "middle" && !gestures.isEmpty)
    }

    func hotspotMeta(_ id: String) -> MouseHotspotMeta {
        switch id {
        case "left":   return .init(name: "Left", sub: "Primary click", icon: "cursorarrow.click", locked: true, gestures: false)
        case "right":  return .init(name: "Right", sub: "Secondary click", icon: "cursorarrow.click", locked: true, gestures: false)
        case "middle": return .init(name: "Middle", sub: "Wheel click", icon: "computermouse", locked: false, gestures: true)
        case "top":    return .init(name: "Top", sub: "Top button", icon: "computermouse", locked: false, gestures: false)
        case "back":   return .init(name: "Back", sub: "Side button 4", icon: "arrow.left", locked: false, gestures: false)
        case "fwd":    return .init(name: "Forward", sub: "Side button 5", icon: "arrow.right", locked: false, gestures: false)
        default:
            if let t = triggerFor(id) {
                if case .key = t {
                    return .init(name: t.displayName, sub: "Keystroke button", icon: "keyboard", locked: false, gestures: false)
                }
                return .init(name: t.displayName, sub: "Additional button", icon: "computermouse", locked: false, gestures: false)
            }
            return .init(name: "Extra", sub: "Additional button", icon: "computermouse", locked: false, gestures: false)
        }
    }

    func phases(forTrigger trigger: MouseTrigger) -> [ClickPhase] {
        if case .key = trigger { return [.single] }
        return ClickPhase.allCases
    }

    func predefinedLabel(_ trigger: MouseTrigger, _ phase: ClickPhase) -> String? {
        guard case .single = phase else { return nil }
        switch trigger {
        case .button(3): return "Back"
        case .button(4): return "Forward"
        default:         return nil
        }
    }
}
