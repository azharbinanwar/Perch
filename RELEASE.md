# Perch release runbook

When the user says "help me release" (or similar), follow this file top to bottom.
The user builds the DMG themselves; everything else can be run by the assistant.

Key facts:
- Public releases repo: `azharbinanwar/perch-releases` (DMG + sha256 + README live here)
- Brew tap repo: `azharbinanwar/homebrew-tap` (cask `Casks/perch.rb`)
- Website: https://perch.kodeelite.com — hosted on Hostinger, files uploaded manually by the user
  from `site/`. The site fetches version + size live from the GitHub API, so a normal release
  needs NO site changes.
- Bundle ID: `com.kodeelite.perch` (Release), `com.kodeelite.perch.debug` (Debug "Perch Dev")
- The download button and `install.sh` point at `releases/latest` — between deleting a release
  and publishing the next one, downloads are DEAD. Never leave that gap open.

## 1. Version bump

`MARKETING_VERSION` in `Perch.xcodeproj/project.pbxproj` (two occurrences, Debug + Release
must match). Bump `CURRENT_PROJECT_VERSION` (build number) as well.

## 2. Build + DMG (user does this)

User archives Release in Xcode and produces `Perch.dmg` (create-dmg; `--volicon` must be a
`.icns`, never a `.png`). Ask where the DMG is if not stated.

## 3. Checksum

```sh
shasum -a 256 Perch.dmg > Perch.dmg.sha256
```

## 4. Publish the GitHub release

```sh
gh release create vX.Y.Z Perch.dmg Perch.dmg.sha256 \
  --repo azharbinanwar/perch-releases \
  --title "Perch X.Y.Z" \
  --notes "<short changelog, bullet per user-visible change, no AI attribution>"
```

## 5. Verify

- `curl -sIL -o /dev/null -w "%{http_code}" https://github.com/azharbinanwar/perch-releases/releases/latest/download/Perch.dmg` → `200`
- Website hero shows the new version + size (auto, may need a hard refresh)
- `curl -fsSL perch.kodeelite.com/install.sh | sh` installs the new version (checksum verified by the script)
- In-app updater on an older install offers the new version

## 6. Update the brew cask

In `azharbinanwar/homebrew-tap`, edit `Casks/perch.rb`: set `version` and `sha256`
(first field of `Perch.dmg.sha256`). Commit + push to that repo only.

If the cask does not exist yet, create `Casks/perch.rb`:

```ruby
cask "perch" do
  version "X.Y.Z"
  sha256 "<sha256 of Perch.dmg>"

  url "https://github.com/azharbinanwar/perch-releases/releases/download/v#{version}/Perch.dmg"
  name "Perch"
  desc "Clipboard history, snippets, mouse remapping and a Hyper Key in one menu-bar app"
  homepage "https://perch.kodeelite.com"

  app "Perch.app"

  caveats <<~EOS
    Perch is not notarized, so macOS blocks the first launch. Approve it once in
    System Settings -> Privacy & Security -> "Open Anyway", or install with
    --no-quarantine to skip the prompt entirely.
  EOS

  zap trash: [
    "~/Library/Preferences/com.kodeelite.perch.plist",
  ]
end
```

Verify with: `brew install --cask azharbinanwar/tap/perch` (on a machine without Perch, or
`brew reinstall`).

## 7. After the release

- If README screenshots or feature docs changed, sync the README to `perch-releases`
  (adapted copy lives there with images under `docs/`; icon path differs from the app repo).
- Site changes (if any were made): user uploads changed files from `site/` to Hostinger.
- Announce wherever appropriate (r/macapps, X, etc.) — user's call.

## Notes

- Deleting releases: `gh release delete vX.Y.Z --repo azharbinanwar/perch-releases --yes --cleanup-tag`
  — remember downloads break until a new release exists.
- Changing the bundle ID resets TCC permissions and UserDefaults for users — avoid; if ever
  needed again, users migrate settings via Backup export/import.
