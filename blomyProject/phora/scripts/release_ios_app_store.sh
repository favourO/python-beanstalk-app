#!/usr/bin/env zsh
set -euo pipefail

BUILD_NAME="${1:-1.0.0}"
BUILD_NUMBER="${2:?Missing build number. Usage: ./scripts/release_ios_app_store.sh 1.0.0 2}"
IPA_PATH="${IPA_PATH:-build/ios/ipa/Vyla.ipa}"

: "${APPLE_ID_EMAIL:?Missing APPLE_ID_EMAIL}"
: "${APPLE_APP_PASSWORD:?Missing APPLE_APP_PASSWORD}"

echo "Building production iOS App Store IPA ${BUILD_NAME}+${BUILD_NUMBER}"
DART_DEFINE_FILE="${DART_DEFINE_FILE:-env/prod.json}" \
EXPORT_METHOD="${EXPORT_METHOD:-app-store}" \
  ./scripts/build_ios_testflight.sh "$BUILD_NAME" "$BUILD_NUMBER"

if [[ ! -f "$IPA_PATH" ]]; then
  echo "IPA not found after build: $IPA_PATH" >&2
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

echo "Uploaded IPA to App Store Connect: $IPA_PATH"
echo "Wait for processing in App Store Connect, then submit/release from the Apple portal."
