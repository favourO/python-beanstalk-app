import json
from io import BytesIO

import pytest
from fastapi.testclient import TestClient

from phora.api.app import create_app
from phora.services.app_release import AppReleaseService


class FakeS3Client:
    def __init__(self, manifest: dict):
        self.manifest = manifest

    def get_object(self, *, Bucket, Key):
        assert Bucket == "vyla-releases"
        assert Key == "android/latest.json"
        return {"Body": BytesIO(json.dumps(self.manifest).encode("utf-8"))}

    def generate_presigned_url(self, operation_name, *, Params, ExpiresIn):
        assert operation_name == "get_object"
        assert Params["Bucket"] == "vyla-releases"
        assert Params["Key"] == "android/releases/vyla-1.2.3+45.apk"
        assert Params["ResponseContentType"] == "application/vnd.android.package-archive"
        assert Params["ResponseContentDisposition"] == 'attachment; filename="vyla-1.2.3+45.apk"'
        assert ExpiresIn == 3600
        return "https://s3.example.com/vyla-1.2.3.apk?signature=test"


@pytest.fixture
def app_release_client(tmp_path, monkeypatch):
    monkeypatch.setenv("PHORA_DATABASE_URL", f"sqlite:///{tmp_path / 'app-release.db'}")
    monkeypatch.setenv("PHORA_SECRET_KEY", "test-secret")
    monkeypatch.setenv("PHORA_AUTO_CREATE_TABLES", "true")
    monkeypatch.setenv("PHORA_PUBLIC_APP_URL", "https://api.vyla.health")
    monkeypatch.setenv("PHORA_ANDROID_RELEASE_BUCKET", "vyla-releases")
    monkeypatch.setenv("PHORA_ANDROID_RELEASE_MANIFEST_KEY", "android/latest.json")

    manifest = {
        "platform": "android",
        "version_name": "1.2.3",
        "version_code": "45",
        "uploaded_at": "2026-05-26T12:00:00Z",
        "file_name": "vyla-1.2.3+45.apk",
        "s3_bucket": "vyla-releases",
        "s3_key": "android/releases/vyla-1.2.3+45.apk",
        "size_bytes": 123456,
        "sha256": "abc123",
    }
    monkeypatch.setattr(AppReleaseService, "_get_s3_client", lambda self: FakeS3Client(manifest))
    return TestClient(create_app())


def test_android_release_metadata_uses_stable_backend_download_url(app_release_client):
    response = app_release_client.get("/api/v1/public/app/android")

    assert response.status_code == 200
    body = response.json()
    assert body["platform"] == "android"
    assert body["download_url"] == "https://api.vyla.health/api/v1/public/app/android/download"
    assert body["qr_url"] == "https://api.vyla.health/api/v1/public/app/android/qr.png"
    assert body["version_name"] == "1.2.3"
    assert body["version_code"] == "45"
    assert body["file_name"] == "vyla-1.2.3+45.apk"
    assert body["size_bytes"] == 123456
    assert body["sha256"] == "abc123"


def test_android_download_redirects_to_latest_presigned_s3_url(app_release_client):
    response = app_release_client.get("/api/v1/public/app/android/download", follow_redirects=False)

    assert response.status_code == 307
    assert response.headers["location"] == "https://s3.example.com/vyla-1.2.3.apk?signature=test"


def test_android_download_qr_is_png(app_release_client):
    pytest.importorskip("qrcode")

    response = app_release_client.get("/api/v1/public/app/android/qr.png")

    assert response.status_code == 200
    assert response.headers["content-type"] == "image/png"
    assert response.content.startswith(b"\x89PNG\r\n\x1a\n")
