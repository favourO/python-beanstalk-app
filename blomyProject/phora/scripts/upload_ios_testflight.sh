#!/usr/bin/env zsh
set -euo pipefail

IPA_PATH="${1:-build/ios/ipa/Vyla.ipa}"

: "${APPLE_ID_EMAIL:?Missing APPLE_ID_EMAIL}"
: "${APPLE_APP_PASSWORD:?Missing APPLE_APP_PASSWORD}"

if [[ ! -f "$IPA_PATH" ]]; then
  echo "IPA not found: $IPA_PATH" >&2
  echo "Run: ./scripts/build_ios_testflight.sh 1.0.0 <build-number>" >&2
  exit 1
fi

TRANSPORTER_ARGS=(
  -m upload
  -assetFile "$IPA_PATH"
  -u "$APPLE_ID_EMAIL"
  -p "$APPLE_APP_PASSWORD"
)

if [[ -n "${ITC_PROVIDER:-}" ]]; then
  TRANSPORTER_ARGS+=(-itc_provider "$ITC_PROVIDER")
fi

xcrun iTMSTransporter "${TRANSPORTER_ARGS[@]}"
