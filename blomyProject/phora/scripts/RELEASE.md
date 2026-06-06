# Release Scripts

## iOS TestFlight

Build and upload to App Store Connect:

```zsh
export APPLE_ID_EMAIL="ojiakufavour@gmail.com"
export APPLE_APP_PASSWORD="your-app-specific-password"
./scripts/ios_list_providers.sh

# Optional: set this only to a provider short name returned by ios_list_providers.sh.
# export ITC_PROVIDER="actual-provider-short-name"

./scripts/release_ios_app_store.sh 1.0.0 2
```

Build only:

```zsh
./scripts/build_ios_testflight.sh 1.0.0 2
```

Upload:

```zsh
export APPLE_ID_EMAIL="ojiakufavour@gmail.com"
export APPLE_APP_PASSWORD="your-app-specific-password"
# Optional: set this only to a provider short name returned by ios_list_providers.sh.
# export ITC_PROVIDER="actual-provider-short-name"

./scripts/upload_ios_testflight.sh
```

To find the provider short name:

```zsh
xcrun iTMSTransporter \
  -m provider \
  -u "$APPLE_ID_EMAIL" \
  -p "$APPLE_APP_PASSWORD"
```

## Android Play Release

Build:

```zsh
source /private/tmp/vyla_android_release_signing.env
./scripts/build_android_release.sh 1.0.0 2
```

The Android script also auto-sources `/private/tmp/vyla_android_release_signing.env`
when it exists and signing variables are not already set.

## Android Direct APK + QR

The backend exposes a stable QR code at:

```zsh
https://<api-host>/api/v1/public/app/android/qr.png
```

That QR points to:

```zsh
https://<api-host>/api/v1/public/app/android/download
```

Upload the latest APK and update the S3 release manifest:

```zsh
export ANDROID_RELEASE_BUCKET=vyla-releases
export ANDROID_RELEASE_REGION=eu-west-2
./scripts/upload_android_s3_release.sh stage 1.0.0 2
```

Configure the backend with:

```zsh
PHORA_PUBLIC_APP_URL=https://<api-host>
PHORA_ANDROID_RELEASE_BUCKET=vyla-releases
PHORA_ANDROID_RELEASE_MANIFEST_KEY=android/latest.json
```

The APK can stay private. The backend reads `android/latest.json` and redirects
downloads to a short-lived S3 presigned URL.

## Notes

Do not commit passwords, app-specific passwords, keystore passwords, or local
release env files. Use environment variables or local ignored `.env` files.
