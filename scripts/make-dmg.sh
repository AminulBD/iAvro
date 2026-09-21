#!/bin/bash
# Build a drag-and-drop installer DMG for Avro Keyboard.
#
#   scripts/make-dmg.sh "path/to/Avro Keyboard.app" "output.dmg"
#
# The image contains the app and a symlink to /Library/Input Methods so the
# user can drag one onto the other. The DMG is not signed or notarized here.
set -euo pipefail

APP="${1:?usage: make-dmg.sh <app bundle> <output dmg>}"
OUT="${2:?usage: make-dmg.sh <app bundle> <output dmg>}"
VOLNAME="Avro Keyboard"

STAGING="$(mktemp -d)"
trap 'rm -rf "$STAGING"' EXIT

ditto "$APP" "$STAGING/$(basename "$APP")"
ln -s "/Library/Input Methods" "$STAGING/Input Methods"
cat > "$STAGING/How to install.txt" <<'TXT'
Avro Keyboard for macOS
=======================

1. Drag "Avro Keyboard" onto the "Input Methods" folder next to it.
   (macOS will ask for your password, since this installs for all users.)

2. Log out and back in, or restart, so macOS picks up the new input method.

3. Open System Settings > Keyboard > Input Sources > Edit... > "+",
   choose Bangla > Avro Keyboard, and click Add.

4. Switch to it from the input menu in the menu bar.

To install only for your own user, drag the app into
~/Library/Input Methods instead (in Finder, press Cmd+Shift+G and paste
that path).
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
