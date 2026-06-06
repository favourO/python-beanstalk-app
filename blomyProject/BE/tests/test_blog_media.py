from io import BytesIO

from fastapi.testclient import TestClient

from phora.api.app import create_app
from phora.core.security import create_token
from phora.db.session import get_session_factory
from phora.models import User


class FakeS3Client:
    def __init__(self):
        self.objects: dict[tuple[str, str], dict] = {}

    def put_object(self, **kwargs):
        self.objects[(kwargs["Bucket"], kwargs["Key"])] = kwargs
        return {"ETag": '"fake-etag"'}

    def get_object(self, *, Bucket: str, Key: str):
        obj = self.objects[(Bucket, Key)]
        return {
            "Body": BytesIO(obj["Body"]),
            "ContentType": obj["ContentType"],
            "CacheControl": obj.get("CacheControl"),
            "ETag": '"fake-etag"',
        }


def _seed_admin() -> str:
    admin = User(
        id="blog-media-admin",
        email="blog-media-admin@example.com",
        password_hash="hash",
        is_admin=True,
        email_verified=True,
    )
    with get_session_factory()() as db:
        db.add(admin)
        db.commit()
    return admin.id


def test_admin_uploads_blog_image_to_s3_and_public_endpoint_serves_it(tmp_path, monkeypatch):
    monkeypatch.setenv("PHORA_DATABASE_URL", f"sqlite:///{tmp_path / 'blog-media.db'}")
    monkeypatch.setenv("PHORA_SECRET_KEY", "blog-media-test-secret")
    monkeypatch.setenv("PHORA_AUTO_CREATE_TABLES", "true")
    monkeypatch.setenv("PHORA_BLOG_MEDIA_BUCKET", "test-blog-media")
    monkeypatch.setenv("PHORA_PUBLIC_APP_URL", "https://vyla.health")

    fake_s3 = FakeS3Client()
    monkeypatch.setattr("phora.services.blog_media.boto3.client", lambda service: fake_s3)

    app = create_app()
    client = TestClient(app)
    admin_id = _seed_admin()
    token = create_token(admin_id, "access", 30)

    upload = client.post(
        "/api/v1/admin/blog/image",
        headers={"Authorization": f"Bearer {token}"},
        data={"slug": "first-post"},
        files={"image": ("cover.png", b"png-bytes", "image/png")},
    )

    assert upload.status_code == 201
    body = upload.json()
    assert body["bucket"] == "test-blog-media"
    assert body["content_type"] == "image/png"
    assert body["size_bytes"] == len(b"png-bytes")
    assert body["key"].startswith("blog/covers/first-post/")
    assert body["url"].startswith("https://vyla.health/api/v1/public/blog/media/")

    stored = fake_s3.objects[("test-blog-media", body["key"])]
    assert stored["Body"] == b"png-bytes"
    assert stored["ServerSideEncryption"] == "AES256"

    public_path = body["url"].replace("https://vyla.health", "")
    served = client.get(public_path)

    assert served.status_code == 200
    assert served.content == b"png-bytes"
    assert served.headers["content-type"] == "image/png"


def test_admin_blog_image_upload_rejects_non_image(tmp_path, monkeypatch):
    monkeypatch.setenv("PHORA_DATABASE_URL", f"sqlite:///{tmp_path / 'blog-media-invalid.db'}")
    monkeypatch.setenv("PHORA_SECRET_KEY", "blog-media-test-secret")
    monkeypatch.setenv("PHORA_AUTO_CREATE_TABLES", "true")
    monkeypatch.setenv("PHORA_BLOG_MEDIA_BUCKET", "test-blog-media")

    fake_s3 = FakeS3Client()
    monkeypatch.setattr("phora.services.blog_media.boto3.client", lambda service: fake_s3)

    app = create_app()
    client = TestClient(app)
    admin_id = _seed_admin()
    token = create_token(admin_id, "access", 30)

    response = client.post(
        "/api/v1/admin/blog/image",
        headers={"Authorization": f"Bearer {token}"},
        files={"image": ("notes.txt", b"text", "text/plain")},
    )

    assert response.status_code == 400
    assert "Unsupported image type" in response.json()["detail"]
    assert not fake_s3.objects

