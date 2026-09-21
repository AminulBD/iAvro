Installation
------------

1. Download `Avro-Keyboard-universal.dmg` from the
   [Releases](https://github.com/AminulBD/iAvro/releases) page
   (or the `apple-silicon` / `intel` build for your Mac)
2. Open the DMG and drag `Avro Keyboard` onto the `Input Methods` folder
   (installs for all users; to install only for yourself, drag it into
   `~/Library/Input Methods` instead)
3. Log out and back in
4. Open `System Settings > Keyboard > Input Sources > Edit… > +`, choose
   `Bangla > Avro Keyboard`, and click `Add`
5. Switch to it from the input menu in the menu bar

Building
--------

Open `AvroKeyboard.xcworkspace` (not the `.xcodeproj`) in Xcode and build the
`Avro Keyboard` scheme. Requires CocoaPods (`pod install`) and macOS 12.0+.

Continuous Integration
----------------------

Every push to `master`, every tag starting with `v`, and every pull request
builds Release binaries for Apple Silicon (`arm64`), Intel (`x86_64`) and a
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
