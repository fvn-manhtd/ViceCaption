#!/usr/bin/env bash

set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "Usage: $0 <path-to-app-or-zip> <bundle-id>"
  echo "Example: $0 Build/Release/VibeCaption.app com.project.vibecaption"
  exit 1
fi

ARTIFACT_PATH="$1"
BUNDLE_ID="$2"

if [[ -z "${APPLE_ID:-}" || -z "${APPLE_TEAM_ID:-}" || -z "${APPLE_APP_SPECIFIC_PASSWORD:-}" ]]; then
  echo "Missing notarization credentials."
  echo "Set APPLE_ID, APPLE_TEAM_ID, and APPLE_APP_SPECIFIC_PASSWORD."
  exit 1
fi

echo "Submitting $ARTIFACT_PATH for notarization..."
xcrun notarytool submit "$ARTIFACT_PATH" \
  --apple-id "$APPLE_ID" \
  --team-id "$APPLE_TEAM_ID" \
  --password "$APPLE_APP_SPECIFIC_PASSWORD" \
  --wait

if [[ "$ARTIFACT_PATH" == *.app ]]; then
  echo "Stapling notarization ticket to app..."
  xcrun stapler staple "$ARTIFACT_PATH"
fi

echo "Notarization complete for $BUNDLE_ID"
