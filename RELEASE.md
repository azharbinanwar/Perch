# Releasing Perch

Pushing a version tag is the release. GitHub Actions builds the app, signs it, makes
`Perch.dmg` and `Perch.dmg.sha256`, publishes the GitHub release, and updates the Homebrew
cask.

## Release

1. In a pull request, bump `MARKETING_VERSION` (e.g. `1.0.1`) and `CURRENT_PROJECT_VERSION`
   in `Perch.xcodeproj/project.pbxproj`. Each appears twice, Debug and Release, and both must
   match. Merge it.
2. Tag `main` and push the tag:

   ```sh
   git checkout main && git pull
   git tag v1.0.1 && git push origin v1.0.1
   ```

3. Watch **Actions → Release**. It fails early if the tag doesn't match `MARKETING_VERSION`.

The release notes are generated from the merged pull requests. Edit them on the release page
if they need it.

## Check it

- `curl -sIL -o /dev/null -w "%{http_code}\n" https://github.com/azharbinanwar/Perch/releases/latest/download/Perch.dmg`
  prints `200`.
- `curl -fsSL perch.kodeelite.com/install.sh | sh` installs the new version.
- `brew upgrade --cask perch` picks it up.
- An older install offers the update from Settings → Updates, and keeps its permissions
  afterwards.
- The website shows the new version and size. It reads them from the GitHub API, so a hard
  refresh is enough.

## How it works

| File | Job |
|---|---|
| `.github/workflows/release.yml` | On a `v*` tag: checks the version, loads the signing certificate, runs `scripts/build-dmg.sh`, publishes the release, then calls `homebrew.yml` |
| `.github/workflows/homebrew.yml` | Checks the release has `Perch.dmg` and a matching `Perch.dmg.sha256`, then rewrites `Casks/perch.rb` in `azharbinanwar/homebrew-tap`. Re-run it by hand with a tag if the tap push failed |
| `.github/workflows/checks.yml` | Builds every pull request and every push to `main` |
| `scripts/build-dmg.sh` | Builds Release, signs it when `SIGN_IDENTITY` is set, packages the DMG with `make-a-dmg` |

The in-app updater, `install.sh` and the cask all download the assets by their exact names,
`Perch.dmg` and `Perch.dmg.sha256`. Never rename them.

## Signing

macOS keys Accessibility and Input Monitoring to the app's signature. An ad-hoc signature
changes with every build, so every update would make users grant both permissions again.
Releases are signed with a self-signed certificate (free, no Apple account) so the signer
stays the same and permissions survive updates. It doesn't remove the first-launch
"Open Anyway" prompt; only notarization does that.

Repository secrets:

| Secret | Value |
|---|---|
| `SIGNING_P12_BASE64` | The certificate and key, `base64 -i signing.p12` |
| `SIGNING_P12_PASSWORD` | The `.p12` password |
| `TAP_TOKEN` | A fine-grained token with *Contents: read and write* on `azharbinanwar/homebrew-tap` only |

```sh
base64 -i signing.p12 | gh secret set SIGNING_P12_BASE64 -R azharbinanwar/Perch
gh secret set SIGNING_P12_PASSWORD -R azharbinanwar/Perch < password.txt
gh secret set TAP_TOKEN -R azharbinanwar/Perch
```

The same certificate can sign several apps; each keeps its own permissions because macOS also
checks the bundle ID. Keep an encrypted backup of the `.p12` and its password: GitHub secrets
can't be read back. Losing or replacing the certificate makes users grant permissions once
more.

Check a build with `codesign -dr - Perch.app`. A signed build shows
`certificate leaf = H"…"`. `cdhash H"…"` means it's still ad-hoc.

## Building a DMG locally

```sh
brew install azharbinanwar/tap/make-a-dmg   # once, or the script downloads it
scripts/build-dmg.sh                        # dist/Perch.dmg, ad-hoc signed
```

To sign it locally, import `signing.p12` into your login keychain and set `SIGN_IDENTITY` to
the certificate's SHA-1 from `security find-identity -p codesigning`.

## Website

`site/` is perch.kodeelite.com. It isn't deployed by these workflows: upload changed files
to the host by hand. A normal release needs no site changes.

## Good to know

- `install.sh`, the website and the cask point at `releases/latest`. Deleting the newest
  release before the next one is published breaks downloads.
- Delete a broken release with
  `gh release delete vX.Y.Z --repo azharbinanwar/Perch --yes --cleanup-tag`.
- Don't change the bundle ID (`com.kodeelite.perch`). It resets permissions and settings for
  every user; they would have to move settings over with Backup export and import.
