//
//  MouseProfileIntroSheet.swift
//  Perch
//

import SwiftUI

struct MouseProfileIntroSheet: View {
    var body: some View {
        ProfileIntroSheet(
            title: "How per-app profiles work",
            subtitle: "Your mouse follows whichever app is in front — automatically.",
            tip: "Add an app with the + tile, then change anything below for just that app.",
            scenes: [
                ProfileDemoScene(appName: "WhatsApp", appIcon: "message.fill",
                                 pressLabel: "Click Back", pressIcon: "computermouse",
                                 action: "Spotlight", actionIcon: "magnifyingglass",
                                 highlighted: true,
                                 caption: "WhatsApp is in front — its profile answers the click."),
                ProfileDemoScene(appName: "Browser", appIcon: "globe",
                                 pressLabel: "Click Back", pressIcon: "computermouse",
                                 action: "Normal click", actionIcon: "cursorarrow.click",
                                 highlighted: false,
                                 caption: "Same button in the browser — no profile here, so it just clicks. The switch is automatic."),
                ProfileDemoScene(appName: "WhatsApp", appIcon: "message.fill",
                                 pressLabel: "Scroll wheel", pressIcon: "scroll",
                                 action: "Slow & smooth", actionIcon: "dial.low",
                                 highlighted: true,
                                 caption: "Scrolling too — gentle in a chat, so you never fly past messages."),
                ProfileDemoScene(appName: "Browser", appIcon: "globe",
                                 pressLabel: "Scroll wheel", pressIcon: "scroll",
                                 action: "Fast 3×", actionIcon: "dial.high",
                                 highlighted: true,
                                 caption: "The same wheel races through long pages in the browser."),
                ProfileDemoScene(appName: "Figma", appIcon: "paintbrush.pointed.fill",
                                 pressLabel: "Hold Forward", pressIcon: "computermouse",
                                 action: "Zoom In", actionIcon: "plus.magnifyingglass",
                                 highlighted: true,
                                 caption: "Any app can get its own tricks — a zoom button just for design work."),
            ])
    }
}
