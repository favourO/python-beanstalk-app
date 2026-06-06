#!/usr/bin/env zsh
set -euo pipefail

BUILD_NAME="${1:-1.0.0}"
BUILD_NUMBER="${2:-1}"
DART_DEFINE_FILE="${DART_DEFINE_FILE:-env/prod.json}"
DEFAULT_SIGNING_ENV="/private/tmp/vyla_android_release_signing.env"

if [[ -f "$DEFAULT_SIGNING_ENV" ]] && {
  [[ -z "${ANDROID_STORE_PASSWORD:-}" ]] ||
  [[ -z "${ANDROID_KEY_ALIAS:-}" ]] ||
  [[ -z "${ANDROID_KEY_PASSWORD:-}" ]]
}; then
  source "$DEFAULT_SIGNING_ENV"
fi

: "${ANDROID_STORE_PASSWORD:?Missing ANDROID_STORE_PASSWORD}"
: "${ANDROID_KEY_ALIAS:?Missing ANDROID_KEY_ALIAS}"
: "${ANDROID_KEY_PASSWORD:?Missing ANDROID_KEY_PASSWORD}"

echo "Preparing Android release build ${BUILD_NAME}+${BUILD_NUMBER}"

flutter pub get

flutter build appbundle --release \
  --build-name "$BUILD_NAME" \
  --build-number "$BUILD_NUMBER" \
  --obfuscate \
  --split-debug-info=build/app/symbols/android \
  --dart-define-from-file="$DART_DEFINE_FILE"

echo "AAB ready: build/app/outputs/bundle/release/app-release.aab"
