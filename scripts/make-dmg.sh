#!/bin/bash
# Build the installer DMG for Avro Keyboard.
#
#   scripts/make-dmg.sh "path/to/Avro Keyboard.app" "output.dmg"
#
# The image contains the app and a short readme. Opening the app from the image
# offers to copy it into ~/Library/Input Methods (see Sources/Installer.swift).
# The DMG is not signed or notarized here.
set -euo pipefail

APP="${1:?usage: make-dmg.sh <app bundle> <output dmg>}"
OUT="${2:?usage: make-dmg.sh <app bundle> <output dmg>}"
VOLNAME="Avro Keyboard"

STAGING="$(mktemp -d)"
trap 'rm -rf "$STAGING"' EXIT

ditto "$APP" "$STAGING/$(basename "$APP")"
cat > "$STAGING/How to install.txt" <<'TXT'
Avro Keyboard for macOS
=======================

1. Double-click "Avro Keyboard" and click Install. It is copied into
   ~/Library/Input Methods (for your user only) and added to your input
   sources.

2. Switch to it from the input menu in the menu bar.

If it does not show up in the input menu, log out and back in, then open
System Settings > Keyboard > Input Sources > Edit... > "+", choose
Bangla > Avro Keyboard, and click Add.

To install for all users instead, copy the app into /Library/Input Methods
by hand (in Finder, press Cmd+Shift+G and paste that path) and log out and
back in.

Had the old iAvro installed? Remove it first, or two "Avro Keyboard" entries
show up in the input menu: remove it from System Settings > Keyboard >
Input Sources > Edit..., delete "Avro Keyboard.app" from ~/Library/Input
Methods or /Library/Input Methods, and log out and back in.
TXT

rm -f "$OUT"
# hdiutil occasionally fails on CI with "Resource busy"; retry a few times.
for attempt in 1 2 3 4 5; do
  if hdiutil create -volname "$VOLNAME" -srcfolder "$STAGING" -fs HFS+ \
       -format UDZO -imagekey zlib-level=9 -ov "$OUT" >/dev/null; then
    break
  fi
  echo "hdiutil create failed (attempt $attempt), retrying..." >&2
  sleep 5
  [ "$attempt" -eq 5 ] && exit 1
done

hdiutil verify "$OUT" >/dev/null
echo "Created $OUT ($(du -h "$OUT" | cut -f1))"
