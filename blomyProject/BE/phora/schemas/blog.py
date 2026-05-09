from datetime import datetime

from pydantic import BaseModel


class BlogPostCreate(BaseModel):
    title: str
    slug: str
    excerpt: str = ""
    body: str = ""
    cover_image_url: str | None = None
    category: str | None = None
    tags: list[str] = []
    author_name: str = "Vyla Team"
    published: bool = False


class BlogPostUpdate(BaseModel):
    title: str | None = None
    slug: str | None = None
    excerpt: str | None = None
    body: str | None = None
    cover_image_url: str | None = None
    category: str | None = None
    tags: list[str] | None = None
    author_name: str | None = None
    published: bool | None = None


class BlogPostOut(BaseModel):
    id: str
    slug: str
    title: str
    excerpt: str
    body: str
    cover_image_url: str | None
    category: str | None
    tags: list[str]
    author_name: str
    published: bool
    published_at: datetime | None
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}

    @classmethod
    def from_model(cls, m: object) -> "BlogPostOut":
        raw_tags = getattr(m, "tags", None) or ""
        tags = [t.strip() for t in raw_tags.split(",") if t.strip()] if raw_tags else []
        return cls(
            id=m.id,  # type: ignore[attr-defined]
            slug=m.slug,  # type: ignore[attr-defined]
            title=m.title,  # type: ignore[attr-defined]
            excerpt=m.excerpt or "",  # type: ignore[attr-defined]
            body=m.body or "",  # type: ignore[attr-defined]
            cover_image_url=m.cover_image_url,  # type: ignore[attr-defined]
            category=m.category,  # type: ignore[attr-defined]
            tags=tags,
            author_name=m.author_name or "Vyla Team",  # type: ignore[attr-defined]
            published=m.published,  # type: ignore[attr-defined]
            published_at=m.published_at,  # type: ignore[attr-defined]
            created_at=m.created_at,  # type: ignore[attr-defined]
            updated_at=m.updated_at,  # type: ignore[attr-defined]
        )


class BlogPostListOut(BaseModel):
    items: list[BlogPostOut]
    total: int
