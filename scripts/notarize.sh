#!/bin/bash
# Submit a file (zip, dmg or pkg) to Apple's notary service and wait for the
# verdict. Prints the notary log and fails if the submission is not accepted.
#
#   scripts/notarize.sh <file>
#
# Expects $RUNNER_TEMP/AuthKey.p8 (or $NOTARY_KEY) plus the
# APP_STORE_CONNECT_KEY_ID and APP_STORE_CONNECT_ISSUER_ID environment
# variables of an App Store Connect API key. NOTARY_TIMEOUT_MINUTES (default
# 120) bounds how long to wait; Apple can take over an hour for a team's first
# submissions, and seconds afterwards.
set -euo pipefail

FILE="${1:?usage: notarize.sh <file>}"
KEY="${NOTARY_KEY:-${RUNNER_TEMP:-/tmp}/AuthKey.p8}"
TIMEOUT_MINUTES="${NOTARY_TIMEOUT_MINUTES:-120}"
AUTH=(--key "$KEY" --key-id "$APP_STORE_CONNECT_KEY_ID" --issuer "$APP_STORE_CONNECT_ISSUER_ID")

json_field() { python3 -c 'import json,sys; print(json.load(sys.stdin).get(sys.argv[1], ""))' "$1"; }

echo "Submitting $FILE for notarization..."
SUBMISSION_ID="$(xcrun notarytool submit "$FILE" "${AUTH[@]}" --output-format json | json_field id)"
[ -n "$SUBMISSION_ID" ] || { echo "notarytool submit did not return a submission id" >&2; exit 1; }
echo "Submission id: $SUBMISSION_ID"

DEADLINE=$(( $(date +%s) + TIMEOUT_MINUTES * 60 ))
STATUS="In Progress"
while [ "$STATUS" = "In Progress" ]; do
  if [ "$(date +%s)" -ge "$DEADLINE" ]; then
    echo "Gave up waiting for notarization of $FILE after $TIMEOUT_MINUTES minutes (submission $SUBMISSION_ID)" >&2
    exit 1
  fi
  sleep 30
  # A transient API error should not abort the wait.
  STATUS="$(xcrun notarytool info "$SUBMISSION_ID" "${AUTH[@]}" --output-format json 2>/dev/null | json_field status || echo "In Progress")"
  [ -n "$STATUS" ] || STATUS="In Progress"
  echo "$(date -u +%H:%M:%S) status: $STATUS"
done

if [ "$STATUS" != "Accepted" ]; then
  echo "Notarization of $FILE failed with status '$STATUS'; notary log:" >&2
  xcrun notarytool log "$SUBMISSION_ID" "${AUTH[@]}" >&2 || true
  exit 1
fi
echo "Notarized $FILE (submission $SUBMISSION_ID)"
