#!/usr/bin/env zsh
set -euo pipefail

BUILD_NAME="${1:-1.0.0}"
BUILD_NUMBER="${2:-1}"
DART_DEFINE_FILE="${DART_DEFINE_FILE:-env/prod.json}"
EXPORT_METHOD="${EXPORT_METHOD:-app-store}"
ICON_PATH="ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png"

echo "Preparing iOS TestFlight build ${BUILD_NAME}+${BUILD_NUMBER}"

plutil -lint ios/Runner/Info.plist >/dev/null

if sips -g hasAlpha "$ICON_PATH" | grep -q 'hasAlpha: yes'; then
  echo "The 1024x1024 iOS app icon has alpha. App Store upload will reject it." >&2
  echo "Fix: flatten $ICON_PATH onto an opaque background, then rerun." >&2
  exit 1
fi

flutter pub get

pushd ios >/dev/null
pod install
popd >/dev/null

flutter build ipa --release \
  --build-name "$BUILD_NAME" \
  --build-number "$BUILD_NUMBER" \
  --export-method "$EXPORT_METHOD" \
  --dart-define-from-file="$DART_DEFINE_FILE"

echo "IPA ready: build/ios/ipa/Vyla.ipa"
