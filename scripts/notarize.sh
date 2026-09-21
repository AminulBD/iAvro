#!/bin/bash
# Submit a file (zip, dmg or pkg) to Apple's notary service and wait for the
# verdict. Prints the notary log and fails if the submission is not accepted.
#
#   scripts/notarize.sh <file>
#
# Expects $RUNNER_TEMP/AuthKey.p8 (or $NOTARY_KEY) plus the
# APP_STORE_CONNECT_KEY_ID and APP_STORE_CONNECT_ISSUER_ID environment
# variables of an App Store Connect API key.
set -euo pipefail

FILE="${1:?usage: notarize.sh <file>}"
KEY="${NOTARY_KEY:-${RUNNER_TEMP:-/tmp}/AuthKey.p8}"
AUTH=(--key "$KEY" --key-id "$APP_STORE_CONNECT_KEY_ID" --issuer "$APP_STORE_CONNECT_ISSUER_ID")

RESULT="$(mktemp)"
xcrun notarytool submit "$FILE" "${AUTH[@]}" --wait --timeout 30m --output-format json | tee "$RESULT"
echo

STATUS="$(python3 -c 'import json,sys; print(json.load(sys.stdin)["status"])' < "$RESULT")"
SUBMISSION_ID="$(python3 -c 'import json,sys; print(json.load(sys.stdin)["id"])' < "$RESULT")"
rm -f "$RESULT"

if [ "$STATUS" != "Accepted" ]; then
  echo "Notarization of $FILE failed with status '$STATUS'; notary log:" >&2
  xcrun notarytool log "$SUBMISSION_ID" "${AUTH[@]}" >&2
  exit 1
fi
echo "Notarized $FILE (submission $SUBMISSION_ID)"
