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
                        .frame(width: 58, height: 42)
                        .overlay(RoundedRectangle(cornerRadius: 8)
                            .stroke(selected ? Color.accentColor : Color.secondary.opacity(0.25),
                                    lineWidth: selected ? 2 : 1))
                    HStack(spacing: 3) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(theme == .dark ? Color.white.opacity(0.15)
                                  : theme == .light ? Color.black.opacity(0.08) : Color.gray.opacity(0.45))
                            .frame(width: 13, height: 26)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(theme == .dark ? Color.white.opacity(0.08)
                                  : theme == .light ? Color.black.opacity(0.04) : Color.gray.opacity(0.25))
                            .frame(width: 30, height: 26)
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
}
