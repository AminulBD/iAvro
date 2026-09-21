Installation
------------

1. Download the `tar.gz` file from [Releases Section](https://github.com/torifat/iAvro/releases)
2. Extract the `tar.gz` & copy `Avro Keyboard.app` file
3. Goto `Finder` & press `⌘⇧G`, paste `~/Library/Input Methods/` & `Go`
4. Paste the `Avro Keyboard.app` file here
5. Goto `System Preferences -> Language & Text -> Input Sources` & Check `Avro Keyboard` from the list
6. Look Above :P

Building
--------

Open `AvroKeyboard.xcworkspace` (not the `.xcodeproj`) in Xcode and build the
`Avro Keyboard` scheme. Requires CocoaPods (`pod install`) and macOS 12.0+.

Continuous Integration
----------------------

Every push to `master`, every tag starting with `v`, and every pull request
builds Release binaries for Apple Silicon (`arm64`), Intel (`x86_64`) and a
universal binary, and uploads each as a workflow artifact.

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
