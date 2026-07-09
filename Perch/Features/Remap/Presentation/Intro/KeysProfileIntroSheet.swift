import SwiftUI

struct KeysProfileIntroSheet: View {
    var body: some View {
        ProfileIntroSheet(
            title: "How per-app profiles work",
            subtitle: "Your keyboard follows whichever app is in front — automatically.",
            tip: "Add an app with the + tile, then change shortcuts, Hyper Key or Double-Tap for just that app.",
            scenes: [
                ProfileDemoScene(appName: "Figma", appIcon: "paintbrush.pointed.fill",
                                 pressLabel: "Press Caps Lock + Z", pressIcon: "keyboard",
                                 action: "Zoom to Fit", actionIcon: "arrow.up.left.and.arrow.down.right",
                                 highlighted: true,
                                 caption: "Figma is in front — its profile answers the keys."),
                ProfileDemoScene(appName: "Terminal", appIcon: "terminal.fill",
                                 pressLabel: "Press Caps Lock", pressIcon: "keyboard",
                                 action: "Just Caps Lock", actionIcon: "capslock",
                                 highlighted: false,
                                 caption: "In Terminal you turned Hyper off — Caps Lock is simply Caps Lock again."),
                ProfileDemoScene(appName: "Figma", appIcon: "paintbrush.pointed.fill",
                                 pressLabel: "Double-tap ⇧", pressIcon: "keyboard",
                                 action: "Spotlight", actionIcon: "magnifyingglass",
                                 highlighted: true,
                                 caption: "Double-tap actions switch per app too. All of it follows the front app by itself."),
            ])
    }
}
