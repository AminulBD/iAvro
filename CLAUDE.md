# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

macOS input method (Swift, InputMethodKit) for Bangla typing. No dependencies; SQLite is the system `libsqlite3`. No test target.

Read @README.md for features, supported macOS versions, installation and CI details.

## Build

```sh
xcodebuild -project AvroKeyboard.xcodeproj -scheme "Avro Keyboard" -configuration Release -derivedDataPath build CODE_SIGNING_ALLOWED=NO
```

Output: `build/Build/Products/Release/Avro Keyboard.app`. Bundle id is `app.aminul.inputmethod.AvroKeyboard`.

## Gotchas

- `Sources/Installer.swift` is compiled out in DEBUG builds (no install prompt). It runs at launch from `main.swift`, before the IMK server starts. Changes to install/update behaviour only show up in Release builds run from outside `~/Library/Input Methods`.
- `connectionName` in `Sources/main.swift` must match `InputMethodConnectionName` in `Info.plist` (no periods or spaces).
- Reload after reinstalling: a running input method keeps the old binary until it is killed.

## Releasing

1. Bump the version in `Resources/en.lproj/InfoPlist.strings`. Replace the old version in both `CFBundleShortVersionString = "vX.Y.Z"` and `CFBundleGetInfoString = "Avro Keyboard vX.Y.Z, ..."`. This file is the user-visible version; `Info.plist` stays at `1.5`/`1` and is not touched. Also update the copyright year there if it changed.
2. Commit as `bump vX.Y.Z` and push `master`.
3. Create an annotated tag and push it: `git tag -m "vX.Y.Z" vX.Y.Z && git push origin vX.Y.Z`. Plain `git tag vX.Y.Z` fails with "no tag message?" because tag signing is on.
4. The `v*` tag triggers `.github/workflows/build.yml`: arm64/x86_64/universal builds, notarization when signing secrets exist, then a GitHub release with DMGs, zips and `SHA256SUMS`.

To redo a release (e.g. after fixing a failed build), delete the tag locally and on the remote (`git tag -d vX.Y.Z && git push origin :refs/tags/vX.Y.Z`), then repeat steps 2-3 so the new tag points at the fixed commit. Check for a leftover GitHub release for the old tag.

A 403 "required agreement is missing or has expired" during notarization means an Apple Developer agreement needs accepting by the Account Holder; re-run the failed job afterwards, no new tag needed.

## Docs

User-facing docs exist in English (`README.md`, `docs/index.html`) and Bangla (`README.bn.md`, `docs/bn.html`); keep them in sync when changing install steps or supported macOS/chip lists.
