import re
import uuid
from dataclasses import dataclass
from datetime import UTC, datetime
from pathlib import PurePosixPath
from urllib.parse import quote

import boto3

from phora.core.config import Settings


class BlogMediaError(RuntimeError):
    pass


class BlogMediaNotConfigured(BlogMediaError):
    pass


class BlogMediaNotFound(BlogMediaError):
    pass


ALLOWED_IMAGE_TYPES = {
    "image/jpeg": ".jpg",
    "image/png": ".png",
    "image/webp": ".webp",
    "image/gif": ".gif",
}
MAX_BLOG_IMAGE_BYTES = 8 * 1024 * 1024


@dataclass(frozen=True)
class StoredBlogMedia:
    url: str
    bucket: str
    key: str
    content_type: str
    size_bytes: int


@dataclass(frozen=True)
class BlogMediaObject:
    body: bytes
    content_type: str
    cache_control: str
    etag: str | None = None


class BlogMediaService:
    def __init__(self, settings: Settings):
        self.settings = settings
        self._s3_client = None

    def store_cover_image(
        self,
        *,
        image_bytes: bytes,
        content_type: str | None,
        filename: str | None,
        slug: str | None,
        admin_id: str,
        public_base_url: str,
    ) -> StoredBlogMedia:
        bucket = self._bucket()
        media_type = self._normalize_content_type(content_type)
        if media_type not in ALLOWED_IMAGE_TYPES:
            raise BlogMediaError("Unsupported image type. Upload JPEG, PNG, WebP, or GIF.")
        if not image_bytes:
            raise BlogMediaError("Image is required.")
        if len(image_bytes) > MAX_BLOG_IMAGE_BYTES:
            raise BlogMediaError("Image must be 8 MB or smaller.")

        object_key = self._object_key(
            slug=slug,
            filename=filename,
            extension=ALLOWED_IMAGE_TYPES[media_type],
        )
        self._client().put_object(
            Bucket=bucket,
            Key=object_key,
            Body=image_bytes,
            ContentType=media_type,
            CacheControl="public, max-age=31536000, immutable",
            Metadata={
                "admin-id": self._metadata_value(admin_id),
                "original-filename": self._metadata_value(filename or "upload"),
                "uploaded-at": datetime.now(UTC).isoformat(),
            },
            ServerSideEncryption="AES256",
        )
        return StoredBlogMedia(
            url=self.public_url(public_base_url=public_base_url, object_key=object_key),
            bucket=bucket,
            key=object_key,
            content_type=media_type,
            size_bytes=len(image_bytes),
        )

    def load_object(self, object_key: str) -> BlogMediaObject:
        bucket = self._bucket()
        key = self._sanitize_object_key(object_key)
        try:
            response = self._client().get_object(Bucket=bucket, Key=key)
        except Exception as exc:
            raise BlogMediaNotFound("Blog image not found.") from exc

        return BlogMediaObject(
            body=response["Body"].read(),
            content_type=response.get("ContentType") or "application/octet-stream",
            cache_control=response.get("CacheControl") or "public, max-age=86400",
            etag=response.get("ETag"),
        )

    def public_url(self, *, public_base_url: str, object_key: str) -> str:
        base = public_base_url.rstrip("/")
        encoded_key = "/".join(quote(part, safe="") for part in object_key.split("/"))
        return f"{base}/api/v1/public/blog/media/{encoded_key}"

    def _bucket(self) -> str:
        bucket = (self.settings.blog_media_bucket or "").strip()
        if not bucket:
            raise BlogMediaNotConfigured("Blog media bucket is not configured.")
        return bucket

    def _client(self):
        if self._s3_client is None:
            self._s3_client = boto3.client("s3")
        return self._s3_client

    def _object_key(self, *, slug: str | None, filename: str | None, extension: str) -> str:
        safe_slug = self._slug_segment(slug)
        original_stem = self._slug_segment(PurePosixPath(filename or "cover").stem)
        return f"blog/covers/{safe_slug}/{uuid.uuid4().hex}-{original_stem}{extension}"

    def _sanitize_object_key(self, object_key: str) -> str:
        key = object_key.strip().lstrip("/")
        if not key.startswith("blog/covers/") or ".." in key.split("/"):
            raise BlogMediaNotFound("Blog image not found.")
        return key

    def _slug_segment(self, value: str | None) -> str:
        segment = re.sub(r"[^a-zA-Z0-9_-]+", "-", (value or "untitled").strip().lower())
        return segment.strip("-")[:80] or "untitled"

    def _normalize_content_type(self, content_type: str | None) -> str:
        return (content_type or "").split(";", 1)[0].strip().lower()

    def _metadata_value(self, value: str) -> str:
        compact = " ".join(value.split())
        if not compact:
            return "n/a"
        return compact.encode("ascii", "ignore").decode("ascii")[:240] or "n/a"

