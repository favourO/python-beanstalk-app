import json
from dataclasses import dataclass
from typing import Any

import boto3

from phora.core.config import Settings


class AppReleaseUnavailable(RuntimeError):
    pass


@dataclass(frozen=True)
class AndroidRelease:
    download_url: str
    version_name: str | None = None
    version_code: str | None = None
    uploaded_at: str | None = None
    file_name: str | None = None
    size_bytes: int | None = None
    sha256: str | None = None
    s3_bucket: str | None = None
    s3_key: str | None = None


class AppReleaseService:
    def __init__(self, settings: Settings):
        self.settings = settings

    def latest_android_release(self) -> AndroidRelease:
        if self.settings.android_download_url:
            return AndroidRelease(download_url=self.settings.android_download_url)

        bucket = self.settings.android_release_bucket
        key = self.settings.android_release_manifest_key
        if not bucket or not key:
            raise AppReleaseUnavailable("Android release manifest is not configured.")

        manifest = self._load_manifest(bucket, key)
        return self._release_from_manifest(manifest, fallback_bucket=bucket)

    def latest_android_download_url(self) -> str:
        return self.latest_android_release().download_url

    def _load_manifest(self, bucket: str, key: str) -> dict[str, Any]:
        try:
            response = self._get_s3_client().get_object(Bucket=bucket, Key=key)
            payload = response["Body"].read()
            return json.loads(payload.decode("utf-8"))
        except Exception as exc:
            raise AppReleaseUnavailable("Android release manifest could not be loaded.") from exc

    def _release_from_manifest(self, manifest: dict[str, Any], *, fallback_bucket: str) -> AndroidRelease:
        direct_url = str(manifest.get("direct_url") or "").strip()
        bucket = str(manifest.get("s3_bucket") or fallback_bucket).strip()
        key = str(manifest.get("s3_key") or "").strip()
        file_name = str(manifest.get("file_name") or "vyla-android.apk").strip()

        if direct_url:
            download_url = direct_url
        elif bucket and key:
            download_url = self._presign_apk_download(bucket=bucket, key=key, file_name=file_name)
        else:
            raise AppReleaseUnavailable("Android release manifest does not include a download target.")

        return AndroidRelease(
            download_url=download_url,
            version_name=_optional_str(manifest.get("version_name")),
            version_code=_optional_str(manifest.get("version_code")),
            uploaded_at=_optional_str(manifest.get("uploaded_at")),
            file_name=file_name,
            size_bytes=_optional_int(manifest.get("size_bytes")),
            sha256=_optional_str(manifest.get("sha256")),
            s3_bucket=bucket or None,
            s3_key=key or None,
        )

    def _presign_apk_download(self, *, bucket: str, key: str, file_name: str) -> str:
        return self._get_s3_client().generate_presigned_url(
            "get_object",
            Params={
                "Bucket": bucket,
                "Key": key,
                "ResponseContentType": "application/vnd.android.package-archive",
                "ResponseContentDisposition": f'attachment; filename="{file_name}"',
            },
            ExpiresIn=self.settings.android_release_presign_expiration_seconds,
        )

    def _get_s3_client(self):
        return boto3.client("s3")


def _optional_str(value: Any) -> str | None:
    if value is None:
        return None
    text = str(value).strip()
    return text or None


def _optional_int(value: Any) -> int | None:
    if value is None or value == "":
        return None
    try:
        return int(value)
    except (TypeError, ValueError):
        return None
