#!/usr/bin/env zsh
set -euo pipefail

ENVIRONMENT="${1:-stage}"
BUILD_NAME="${2:-1.0.0}"
BUILD_NUMBER="${3:-1}"

: "${ANDROID_RELEASE_BUCKET:?Missing ANDROID_RELEASE_BUCKET}"

ANDROID_RELEASE_PREFIX="${ANDROID_RELEASE_PREFIX:-android}"
ANDROID_RELEASE_MANIFEST_KEY="${ANDROID_RELEASE_MANIFEST_KEY:-${ANDROID_RELEASE_PREFIX}/latest.json}"
ANDROID_RELEASE_REGION="${ANDROID_RELEASE_REGION:-${AWS_REGION:-eu-west-2}}"
ANDROID_RELEASE_ACL="${ANDROID_RELEASE_ACL:-}"
ANDROID_RELEASE_PUBLIC_BASE_URL="${ANDROID_RELEASE_PUBLIC_BASE_URL:-}"
DEFAULT_SIGNING_ENV="/private/tmp/vyla_android_release_signing.env"
DART_DEFINE_FILE="env/${ENVIRONMENT}.json"

if [[ ! -f "$DART_DEFINE_FILE" ]]; then
  echo "Missing Dart define file: $DART_DEFINE_FILE" >&2
  exit 1
fi

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

echo "Building Android APK ${BUILD_NAME}+${BUILD_NUMBER} for ${ENVIRONMENT}"
flutter pub get
flutter build apk --release \
  --build-name "$BUILD_NAME" \
  --build-number "$BUILD_NUMBER" \
  --obfuscate \
  --split-debug-info="build/app/symbols/android-${ENVIRONMENT}" \
  --dart-define-from-file="$DART_DEFINE_FILE"

APK_PATH="build/app/outputs/flutter-apk/app-release.apk"
if [[ ! -f "$APK_PATH" ]]; then
  echo "Expected APK was not produced: $APK_PATH" >&2
  exit 1
fi

FILE_NAME="vyla-${ENVIRONMENT}-${BUILD_NAME}+${BUILD_NUMBER}.apk"
S3_KEY="${ANDROID_RELEASE_PREFIX}/releases/${FILE_NAME}"
SHA256="$(shasum -a 256 "$APK_PATH" | awk '{print $1}')"
SIZE_BYTES="$(wc -c < "$APK_PATH" | tr -d ' ')"
UPLOADED_AT="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
TMP_MANIFEST="$(mktemp)"

echo "Uploading APK to s3://${ANDROID_RELEASE_BUCKET}/${S3_KEY}"
APK_UPLOAD_ARGS=(
  --region "$ANDROID_RELEASE_REGION"
  --content-type "application/vnd.android.package-archive"
  --metadata "version_name=${BUILD_NAME},version_code=${BUILD_NUMBER},sha256=${SHA256}"
)
if [[ -n "$ANDROID_RELEASE_ACL" ]]; then
  APK_UPLOAD_ARGS+=(--acl "$ANDROID_RELEASE_ACL")
fi
aws s3 cp "$APK_PATH" "s3://${ANDROID_RELEASE_BUCKET}/${S3_KEY}" \
  "${APK_UPLOAD_ARGS[@]}"

DIRECT_URL=""
if [[ -n "$ANDROID_RELEASE_PUBLIC_BASE_URL" ]]; then
  DIRECT_URL="${ANDROID_RELEASE_PUBLIC_BASE_URL%/}/${S3_KEY}"
elif [[ "$ANDROID_RELEASE_ACL" == "public-read" ]]; then
  DIRECT_URL="https://${ANDROID_RELEASE_BUCKET}.s3.${ANDROID_RELEASE_REGION}.amazonaws.com/${S3_KEY}"
fi

export ANDROID_RELEASE_BUCKET BUILD_NAME BUILD_NUMBER UPLOADED_AT FILE_NAME S3_KEY SIZE_BYTES SHA256 DIRECT_URL TMP_MANIFEST
python3 -c 'import json, os, pathlib
manifest = {
    "platform": "android",
    "version_name": os.environ["BUILD_NAME"],
    "version_code": os.environ["BUILD_NUMBER"],
    "uploaded_at": os.environ["UPLOADED_AT"],
    "file_name": os.environ["FILE_NAME"],
    "s3_bucket": os.environ["ANDROID_RELEASE_BUCKET"],
    "s3_key": os.environ["S3_KEY"],
    "size_bytes": int(os.environ["SIZE_BYTES"]),
    "sha256": os.environ["SHA256"],
}
direct_url = os.environ.get("DIRECT_URL", "").strip()
if direct_url:
    manifest["direct_url"] = direct_url
pathlib.Path(os.environ["TMP_MANIFEST"]).write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
'

echo "Uploading release manifest to s3://${ANDROID_RELEASE_BUCKET}/${ANDROID_RELEASE_MANIFEST_KEY}"
MANIFEST_UPLOAD_ARGS=(
  --region "$ANDROID_RELEASE_REGION"
  --content-type "application/json"
  --cache-control "no-cache"
)
if [[ -n "$ANDROID_RELEASE_ACL" ]]; then
  MANIFEST_UPLOAD_ARGS+=(--acl "$ANDROID_RELEASE_ACL")
fi
aws s3 cp "$TMP_MANIFEST" "s3://${ANDROID_RELEASE_BUCKET}/${ANDROID_RELEASE_MANIFEST_KEY}" \
  "${MANIFEST_UPLOAD_ARGS[@]}"

rm -f "$TMP_MANIFEST"

echo "Android release uploaded."
echo "Backend QR endpoint: PHORA_PUBLIC_APP_URL/api/v1/public/app/android/qr.png"
