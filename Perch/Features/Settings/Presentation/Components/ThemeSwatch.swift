import SwiftUI

struct ThemeSwatch: View {
    @Environment(SettingsViewModel.self) private var settings
    let theme: AppTheme

    var body: some View {
        let selected = settings.settings.theme == theme
        Button { settings.settings.theme = theme } label: {
            VStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(background)
                        .frame(width: 64, height: 44)
                        .overlay(RoundedRectangle(cornerRadius: 8)
                            .stroke(selected ? Color.accentColor : Color.secondary.opacity(0.25),
                                    lineWidth: selected ? 2 : 1))
                    // Mini window: sidebar + content pane (same style as Miqat's theme picker).
                    HStack(spacing: 3) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(sidebarColor)
                            .frame(width: 16, height: 28)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(contentColor)
                            .frame(width: 32, height: 28)
                    }
                }
                Text(theme.title)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(selected ? Color.accentColor : Color.secondary)
            }
        }
        .buttonStyle(.plain)
    }

    private var background: AnyShapeStyle {
        switch theme {
        case .light: return AnyShapeStyle(Color.white)
        case .dark:  return AnyShapeStyle(Color.black)
        case .system:
            return AnyShapeStyle(LinearGradient(
                stops: [.init(color: .black, location: 0.499), .init(color: .white, location: 0.501)],
                startPoint: .topLeading, endPoint: .bottomTrailing))
        }
    }

    private var sidebarColor: Color {
        switch theme {
        case .dark:   return .white.opacity(0.15)
        case .light:  return .black.opacity(0.08)
        case .system: return .gray.opacity(0.4)
        }
    }

    private var contentColor: Color {
        switch theme {
        case .dark:   return .white.opacity(0.07)
        case .light:  return .black.opacity(0.04)
        case .system: return .gray.opacity(0.2)
        }
    }
}
