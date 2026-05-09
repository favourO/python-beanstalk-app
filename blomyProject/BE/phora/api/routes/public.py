"""
Public (unauthenticated) endpoints for the Vyla landing page.
  POST /public/contact          — contact form submission
  POST /public/send-download    — email the user an app download link
  GET  /public/blog             — list published blog posts
  GET  /public/blog/{slug}      — get a published blog post by slug
"""
import logging
import uuid
from html import escape

from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException, Query, status
from pydantic import BaseModel, EmailStr
from sqlalchemy import select
from sqlalchemy.orm import Session

from phora.core.config import get_settings
from phora.db.session import get_db
from phora.models.blog import BlogPost
from phora.schemas.blog import BlogPostListOut, BlogPostOut
from phora.models.contact import ContactMessage
from phora.services.email import EmailService

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/public", tags=["public"])

APP_STORE_URL = "https://apps.apple.com/app/vyla"
PLAY_STORE_URL = "https://play.google.com/store/apps/details?id=com.vyla.app"
ADMIN_EMAIL = "curveseden@gmail.com"


# ── Schemas ───────────────────────────────────────────────────────────────────

class ContactRequest(BaseModel):
    name: str
    email: EmailStr
    subject: str
    message: str


class ContactResponse(BaseModel):
    ok: bool


class DownloadLinkRequest(BaseModel):
    email: EmailStr


class DownloadLinkResponse(BaseModel):
    ok: bool


# ── Endpoints ─────────────────────────────────────────────────────────────────

@router.post("/contact", response_model=ContactResponse)
def submit_contact(
    payload: ContactRequest,
    background: BackgroundTasks,
    db: Session = Depends(get_db),
) -> ContactResponse:
    msg = ContactMessage(
        id=str(uuid.uuid4()),
        name=payload.name.strip(),
        email=payload.email.lower().strip(),
        subject=payload.subject.strip(),
        message=payload.message.strip(),
    )
    db.add(msg)
    db.commit()

    settings = get_settings()
    svc = EmailService(settings)

    background.add_task(_send_contact_confirmation, svc, payload.name, payload.email, payload.subject)
    background.add_task(_send_admin_contact_alert, svc, payload.name, payload.email, payload.subject, payload.message)

    return ContactResponse(ok=True)


@router.post("/send-download", response_model=DownloadLinkResponse)
def send_download_link(
    payload: DownloadLinkRequest,
    background: BackgroundTasks,
) -> DownloadLinkResponse:
    settings = get_settings()
    svc = EmailService(settings)
    background.add_task(_send_download_email, svc, payload.email)
    return DownloadLinkResponse(ok=True)


# ── Background email tasks ────────────────────────────────────────────────────

def _send_contact_confirmation(svc: EmailService, name: str, email: str, subject: str) -> None:
    safe_name = escape(name)
    safe_subject = escape(subject)
    text = (
        f"Hi {name},\n\n"
        "Thanks for reaching out to Vyla! We've received your message and will get back to you within 1–2 business days.\n\n"
        f"Your message subject: {subject}\n\n"
        "In the meantime, feel free to explore the app or visit vyla.health for more information.\n\n"
        "Warm regards,\nThe Vyla Team\n\n"
        "Vyla Health Technologies Inc · 6 Giles Avenue, London RM13"
    )
    html = _render_simple_html(
        heading="We've received your message",
        subtext=f"Hi {safe_name}, thanks for contacting Vyla. We'll respond to your message about <strong>{safe_subject}</strong> within 1–2 business days.",
        body_html=(
            "<p style='margin:0 0 16px;font-family:Arial,sans-serif;font-size:14px;line-height:1.7;color:#7A4A32;'>"
            "While you wait, feel free to explore the app or visit our website for more information."
            "</p>"
            "<table role='presentation' cellspacing='0' cellpadding='0' border='0' align='center' style='margin:24px auto 0;'>"
            "<tr><td style='background-color:#FF7A33;border-radius:12px;'>"
            "<a href='https://vyla.health' style='display:inline-block;padding:14px 32px;font-family:Arial,sans-serif;"
            "font-size:14px;font-weight:700;color:#ffffff;text-decoration:none;'>Visit Vyla</a>"
            "</td></tr></table>"
        ),
    )
    try:
        svc._send(email, "We received your message — Vyla", text, html_body=html)
    except Exception:
        logger.exception("Failed to send contact confirmation to %s", email)


def _send_admin_contact_alert(svc: EmailService, name: str, email: str, subject: str, message: str) -> None:
    safe_name = escape(name)
    safe_email = escape(email)
    safe_subject = escape(subject)
    safe_message = escape(message)
    text = (
        f"New contact form submission\n\nFrom: {name} <{email}>\nSubject: {subject}\n\nMessage:\n{message}"
    )
    html = _render_simple_html(
        heading="New contact message",
        subtext=f"A new message was submitted via the Vyla landing page contact form.",
        body_html=(
            f"<table role='presentation' width='100%' cellspacing='0' cellpadding='0' border='0' "
            f"style='background:#FFF6F0;border-radius:14px;border:1px solid #FFE0CC;margin-bottom:20px;'>"
            f"<tr><td style='padding:20px 24px;'>"
            f"<p style='margin:0 0 8px;font-family:Arial,sans-serif;font-size:13px;color:#A06A52;'>"
            f"<strong>From:</strong> {safe_name} &lt;{safe_email}&gt;</p>"
            f"<p style='margin:0 0 8px;font-family:Arial,sans-serif;font-size:13px;color:#A06A52;'>"
            f"<strong>Subject:</strong> {safe_subject}</p>"
            f"<p style='margin:0;font-family:Arial,sans-serif;font-size:13px;color:#A06A52;'>"
            f"<strong>Message:</strong><br/>{safe_message}</p>"
            f"</td></tr></table>"
            "<table role='presentation' cellspacing='0' cellpadding='0' border='0' align='center' style='margin:0 auto;'>"
            "<tr><td style='background-color:#FF7A33;border-radius:12px;'>"
            "<a href='https://d2ljtgj9h46yo0.cloudfront.net' style='display:inline-block;padding:12px 28px;"
            "font-family:Arial,sans-serif;font-size:13px;font-weight:700;color:#ffffff;text-decoration:none;'>"
            "Open Admin Dashboard</a></td></tr></table>"
        ),
    )
    try:
        svc._send(ADMIN_EMAIL, f"[Vyla] Contact: {subject}", text, html_body=html)
    except Exception:
        logger.exception("Failed to send admin contact alert")


def _send_download_email(svc: EmailService, email: str) -> None:
    text = (
        "Thanks for your interest in Vyla!\n\n"
        f"Download on the App Store: {APP_STORE_URL}\n"
        f"Download on Google Play: {PLAY_STORE_URL}\n\n"
        "Vyla is free to download. No credit card needed.\n\n"
        "The Vyla Team · vyla.health"
    )
    html = _render_simple_html(
        heading="Get Vyla on your phone",
        subtext="Here are your download links. Tap the button for your device.",
        body_html=(
            "<table role='presentation' cellspacing='0' cellpadding='0' border='0' align='center' "
            "style='margin:0 auto 12px;'>"
            "<tr><td style='background-color:#1E0C16;border-radius:12px;margin-bottom:8px;'>"
            f"<a href='{APP_STORE_URL}' style='display:inline-block;padding:14px 32px;"
            "font-family:Arial,sans-serif;font-size:14px;font-weight:700;color:#ffffff;text-decoration:none;'>"
            "&#x2B07; Download on App Store</a></td></tr></table>"
            "<table role='presentation' cellspacing='0' cellpadding='0' border='0' align='center' "
            "style='margin:8px auto 0;'>"
            "<tr><td style='background-color:#FF7A33;border-radius:12px;'>"
            f"<a href='{PLAY_STORE_URL}' style='display:inline-block;padding:14px 32px;"
            "font-family:Arial,sans-serif;font-size:14px;font-weight:700;color:#ffffff;text-decoration:none;'>"
            "&#x2B07; Get it on Google Play</a></td></tr></table>"
        ),
    )
    try:
        svc._send(email, "Your Vyla download links", text, html_body=html)
    except Exception:
        logger.exception("Failed to send download link to %s", email)


# ── Minimal shared HTML template ──────────────────────────────────────────────

def _render_simple_html(heading: str, subtext: str, body_html: str) -> str:
    return f"""<!DOCTYPE html>
<html lang="en"><head><meta charset="UTF-8"/>
<meta name="viewport" content="width=device-width,initial-scale=1.0"/>
<title>{heading}</title></head>
<body style="margin:0;padding:0;background-color:#FFF6F0;">
<table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0" bgcolor="#FFF6F0">
<tr><td align="center" style="padding:28px 16px;">
  <table role="presentation" align="center" width="600" cellspacing="0" cellpadding="0" border="0"
    style="max-width:600px;width:100%;background:#ffffff;border-radius:24px;border:1px solid #FFE0CC;overflow:hidden;">
    <tr>
      <td style="background-color:#FFE8D4;padding:32px 44px 28px;text-align:center;">
        <h1 style="margin:0 0 12px;font-family:Georgia,serif;font-size:26px;font-weight:700;color:#3A1A08;">{heading}</h1>
        <p style="margin:0;font-family:Arial,sans-serif;font-size:14px;line-height:1.7;color:#7A4A32;">{subtext}</p>
      </td>
    </tr>
    <tr>
      <td style="padding:32px 44px 36px;background:#ffffff;text-align:center;">
        {body_html}
      </td>
    </tr>
    <tr>
      <td style="padding:20px 32px;background:#FFF6F0;border-top:1px solid #FFE0CC;text-align:center;">
        <p style="margin:0;font-family:Arial,sans-serif;font-size:12px;color:#A06A52;">
          &copy; 2026 Vyla Health Technologies Inc. All rights reserved.<br/>
          6 Giles Avenue, London RM13
        </p>
      </td>
    </tr>
  </table>
</td></tr>
</table>
</body></html>"""


# ── Public blog endpoints ──────────────────────────────────────────────────────

@router.get("/blog", response_model=BlogPostListOut)
def list_published_posts(
    category: str | None = Query(default=None),
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=20, ge=1, le=50),
    db: Session = Depends(get_db),
) -> BlogPostListOut:
    stmt = select(BlogPost).where(BlogPost.published.is_(True))
    if category:
        stmt = stmt.where(BlogPost.category == category)
    from sqlalchemy import func
    total = db.scalar(select(func.count()).select_from(stmt.subquery())) or 0
    rows = db.scalars(
        stmt.order_by(BlogPost.published_at.desc())
        .offset((page - 1) * page_size)
        .limit(page_size)
    ).all()
    return BlogPostListOut(items=[BlogPostOut.from_model(r) for r in rows], total=total)


@router.get("/blog/{slug:path}", response_model=BlogPostOut)
def get_published_post(
    slug: str,
    db: Session = Depends(get_db),
) -> BlogPostOut:
    post = db.scalar(select(BlogPost).where(BlogPost.slug == slug, BlogPost.published.is_(True)))
    if not post:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Post not found")
    return BlogPostOut.from_model(post)
