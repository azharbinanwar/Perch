# AGENTS.md

Notes for AI coding assistants working on Perch. People should start with
[CONTRIBUTING.md](CONTRIBUTING.md); this file is the same ground rules, condensed.

## What Perch is

A native macOS menu-bar app (Swift, SwiftUI, macOS 14+, Apple Silicon) with four tools:
Clipboard history, Snippets (type-to-expand), Mouse remapping (including the Mouse Shift
layer) and Keys remapping (including the Caps Lock Hyper Key). Mouse and Keys behave per app.

## Build and run

```sh
open Perch.xcodeproj        # Cmd+R runs "Perch Dev" (Debug, bundle ID com.kodeelite.perch.debug)
xcodebuild -project Perch.xcodeproj -scheme Perch -configuration Release \
  CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM= -quiet build   # what CI runs
```

There's no test suite yet. Verify a change by running Perch Dev with Accessibility and Input
Monitoring granted, and using the feature for real.

## Layout

| Path | Contents |
|---|---|
| `Perch/Features/<Feature>/` | Clipboard, Snippets, Mouse, Remap (the Keys tab), Settings (General), Onboarding, MainWindow. Each split into `Data`, `Domain`, `Presentation` |
| `Perch/Core/Components/` | Shared settings UI: `SettingGroup`, `SettingRow`, `PermissionTile`, `ShowcaseSheet` and the rest |
| `Perch/Core/Actions/` | The action catalogue used by buttons, combos, Hyper shortcuts and double-taps |
| `Perch/Core/Config/` | Backup export and import (`PerchConfig`, `ConfigSection`) |
| `Perch/Core/Services/` | `UpdateChecker`, `UpdateInstaller` |
| `site/` | perch.kodeelite.com, deployed by hand |
| `.github/workflows/`, `scripts/` | CI and releases, see [RELEASE.md](RELEASE.md) |

## Rules

- Use the shared components in `Perch/Core/Components` directly at the call site. Don't wrap
  them in one-off helper views or methods.
- Comments explain only what the code can't say. No comments narrating a change. File headers
  stay the short standard Xcode header.
- Fix a broken feature; don't remove it or suggest dropping it.
- App Sandbox is off on purpose: the Force Quit action can't work inside it. Don't turn it on.
- Don't change the bundle ID `com.kodeelite.perch`: it resets every user's permissions and
  settings.
- Never commit `dev/`, build output, `dist/` or `flowcast/`.
- The updater, `install.sh` and the Homebrew cask download the release assets by their exact
  names, `Perch.dmg` and `Perch.dmg.sha256`.
- Branch names: `feat/…`, `fix/…`, `docs/…`, `chore/…`, `ci/…`. One change per pull request;
  `main` must always build.

## Permissions while debugging

Perch needs Accessibility and Input Monitoring. If a grant won't stick, look for a second
running copy of Perch Dev or an old entry in System Settings → Privacy & Security before
changing code.
