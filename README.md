Screenshots
-----------

<p align="center">
  <img src="docs/assets/screenshots/avro-phonetic-typing.png" width="560" alt="Typing “tumi” in Notes, with the candidate bar showing তুমি and other spellings">
</p>

<p align="center">
  <img src="docs/assets/screenshots/avro-switching-between-layouts.png" width="49%" alt="The Preferences window with the Keyboard Layout pop-up listing Avro Phonetic, Probhat and Unijoy">
  <img src="docs/assets/screenshots/avro-preferences.png" width="49%" alt="The input menu with Avro Keyboard selected and its Preferences item">
</p>

Type phonetically and pick a spelling from the candidate bar, or switch to the
Probhat or Unijoy layout under `Preferences… > Keyboard Layout`.

Installation
------------

### Homebrew

```
brew install --cask aminulbd/tap/avro
```

This installs `Avro Keyboard.app` into `~/Library/Input Methods`. Upgrade with
`brew upgrade --cask avro` and remove with `brew uninstall --cask avro`. After
installing, switch to it from the input menu in the menu bar.

### Manual

1. Download `Avro-Keyboard-universal.dmg` from the
   [Releases](https://github.com/AminulBD/iAvro/releases) page
   (or the `apple-silicon` / `intel` build for your Mac)
2. Open the DMG, double-click `Avro Keyboard` and click `Install`. It is
   copied into `~/Library/Input Methods` and added to your input sources
   (to install for all users instead, copy it into `/Library/Input Methods`
   by hand and log out and back in)
3. Switch to it from the input menu in the menu bar

If it does not appear in the input menu, log out and back in, then open
`System Settings > Keyboard > Input Sources > Edit… > +`, choose
`Bangla > Avro Keyboard`, and click `Add`.

<p align="center">
  <img src="docs/assets/screenshots/input-method-macos.png" width="49%" alt="Avro Keyboard under Input Sources in System Settings on macOS 13 and later">
  <img src="docs/assets/screenshots/input-method-legacy-macos.png" width="49%" alt="Avro Keyboard under Input Sources in System Preferences on macOS 12">
</p>

On macOS 12 the same list is under `System Preferences > Keyboard > Input Sources`.

### Removing the old version

If you had the original iAvro (bundle identifier
`com.omicronlab.inputmethod.AvroKeyboard`) installed, remove it first, otherwise
two `Avro Keyboard` entries show up in the input menu and macOS may keep
loading the old one:

1. Open `System Settings > Keyboard > Input Sources > Edit…` and remove
   `Avro Keyboard` from the list
2. Delete the old app. It lives in one of these folders (in Finder press
   `⌘⇧G` and paste the path):

   ```
   rm -rf ~/Library/Input\ Methods/Avro\ Keyboard.app
   sudo rm -rf /Library/Input\ Methods/Avro\ Keyboard.app
   ```

3. Log out and back in, then install the new version as described above

Your personal dictionary and preferences from the old version are not carried
over; they were stored under the old bundle identifier.

Building
--------

Open `AvroKeyboard.xcodeproj` in Xcode and build the `Avro Keyboard` scheme, or
from the command line:

```
xcodebuild -project AvroKeyboard.xcodeproj \
  -scheme "Avro Keyboard" \
  -configuration Release \
  -derivedDataPath build
```

The app is written in Swift with no external dependencies (SQLite is used
through the system `libsqlite3`) and requires Xcode 16+ and macOS 12.0+. The
built app is at `build/Build/Products/Release/Avro Keyboard.app`; its bundle
identifier is `app.aminul.inputmethod.AvroKeyboard`.

Continuous Integration
----------------------

Pushing a tag starting with `v`, or running the **Build** workflow manually
from the Actions tab, builds Release binaries for Apple Silicon (`arm64`), Intel (`x86_64`) and a
universal binary, and uploads each as a workflow artifact (a `.dmg` installer
and a `.zip` of the bare app).

### Releases

Push a tag starting with `v` to publish a release:

```
git tag v1.6.0
git push fork v1.6.0
```

Once all three builds finish, a GitHub release is created for that tag with
the DMGs and zips attached and auto-generated release notes.

### Signing & notarization

When the following repository secrets are set, CI signs the app with your
Developer ID certificate, submits it to Apple for notarization, and staples the
ticket before uploading. Without them the app is ad-hoc signed and Gatekeeper
will block it on other Macs.

| Secret | Value |
|---|---|
| `MACOS_CERTIFICATE_P12` | Base64 of a `.p12` export of your **Developer ID Application** certificate (with private key): `base64 -i cert.p12 \| pbcopy` |
| `MACOS_CERTIFICATE_PASSWORD` | Password used when exporting the `.p12` |
| `APPLE_TEAM_ID` | 10-character Team ID from <https://developer.apple.com/account> |
| `APP_STORE_CONNECT_KEY_ID` | Key ID of an App Store Connect API key |
| `APP_STORE_CONNECT_ISSUER_ID` | Issuer ID shown on the API keys page |
| `APP_STORE_CONNECT_API_KEY_P8` | Full contents of the downloaded `AuthKey_XXXXXXXXXX.p8` file |

To create the API key: App Store Connect → Users and Access → Integrations →
App Store Connect API → **Team Keys** → `+`, role **Developer** (or higher).
The `.p8` can only be downloaded once.

## License

Avro Keyboard for Mac is licensed under the [Mozilla Public License 1.1](LICENSE).
Copyright © 2026 OmicronLab. All rights reserved.
