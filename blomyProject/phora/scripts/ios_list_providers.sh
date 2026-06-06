#!/usr/bin/env zsh
set -euo pipefail

: "${APPLE_ID_EMAIL:?Missing APPLE_ID_EMAIL}"
: "${APPLE_APP_PASSWORD:?Missing APPLE_APP_PASSWORD}"

xcrun iTMSTransporter \
  -m provider \
  -u "$APPLE_ID_EMAIL" \
  -p "$APPLE_APP_PASSWORD"
