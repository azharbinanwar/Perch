# Contributing

Contributions are welcome: bug fixes, new actions, better defaults, docs.

## Getting started

```sh
git clone https://github.com/azharbinanwar/Perch.git
cd Perch
open Perch.xcodeproj
```

Requires Xcode 26+ and macOS 14+. Press ⌘R to run.

- **Signing:** in the Perch target's *Signing & Capabilities*, pick your own team, or set
  *Signing Certificate* to *Sign to Run Locally*. Don't commit that change.
- **Running from Xcode builds Perch Dev**, with its own bundle ID (`com.kodeelite.perch.debug`),
  so it never touches an installed Perch or its settings.
- **Permissions:** grant Perch Dev **Accessibility** and **Input Monitoring** in
  System Settings → Privacy & Security, then relaunch it. A permission that won't stick
  is usually a second copy of Perch Dev still running, or an old entry in that list:
  quit every copy, remove the old entry, and grant it again.

## Where things live

| Folder | What's in it |
|---|---|
| `Perch/Features/<Feature>/` | One folder per tab (Clipboard, Snippets, Mouse, Remap = Keys, Settings = General), each split into `Data`, `Domain` and `Presentation` |
| `Perch/Core/Components/` | The shared settings UI: `SettingGroup`, `SettingRow`, `PermissionTile`, `ShowcaseSheet` and friends. Use these instead of building one-off rows |
| `Perch/Core/Actions/` | The action catalogue every button, combo, Hyper shortcut and double-tap draws from |
| `Perch/Core/Config/` | Backup export and import |
| `site/` | The website, perch.kodeelite.com |

## Branches and pull requests

- `main` always builds. Open a pull request instead of committing to it.
- Name branches by type: `feat/…`, `fix/…`, `docs/…`, `chore/…`, `ci/…`.
- One change per pull request. They're squash-merged, so the title becomes the commit
  message: a short present-tense sentence, e.g. "Add Toggle Dark Mode action".
- Every pull request is built automatically and must pass before merging.
- Use the shared components, and comment only what the code can't say itself.

## Testing a change

There's no automated test suite yet. Before opening a pull request:

1. Run Perch Dev with both permissions granted.
2. Use the feature you changed for real: copy and paste, expand a snippet, press the
   remapped button or key.
3. Check that nearby features still work, especially anything sharing the action catalogue
   or the input monitors.

## Reporting bugs

Open an issue with what Perch did, what you expected, your macOS and Perch versions, and
your mouse or keyboard model if it's an input bug.

## Releases

Maintainers only: see [RELEASE.md](RELEASE.md).
