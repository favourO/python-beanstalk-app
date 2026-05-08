import logging
import mimetypes
import smtplib
from datetime import date as _date
from email.utils import make_msgid
from email.message import EmailMessage
from html import escape
from pathlib import Path

from phora.core.config import Settings

logger = logging.getLogger(__name__)
_ASSETS_DIR = Path(__file__).resolve().parent.parent / "assets"
_LOGO_PATH = _ASSETS_DIR / "vyla-logo.png"

# ── CSS ──────────────────────────────────────────────────────────────────────
# Plain string — no f-string curly-brace escaping needed when interpolated.
_EMAIL_CSS = (
    "* {box-sizing:border-box}"
    "body,table,td,p,a,h1 {-webkit-text-size-adjust:100%;-ms-text-size-adjust:100%}"
    "table,td {mso-table-lspace:0pt;mso-table-rspace:0pt;border-collapse:collapse}"
    "img {-ms-interpolation-mode:bicubic;display:block;border:0;outline:0;text-decoration:none}"
    "@media only screen and (max-width:620px) {"
    ".eo {padding:16px 10px !important}"
    ".lc {display:none !important;max-width:0 !important;overflow:hidden !important}"
    ".cb {padding:24px 16px !important}"
    ".dt {padding:0 4px !important}"
    ".db {width:44px !important;height:56px !important;line-height:56px !important;font-size:28px !important}"
    "}"
)

# ── Inline SVG assets ─────────────────────────────────────────────────────────
_LEAF_BRANCH_SVG = (
    '<svg width="70" height="118" viewBox="0 0 70 118" xmlns="http://www.w3.org/2000/svg" aria-hidden="true">'
    '<path d="M42 5 C35 25,21 46,15 72 C11 88,12 103,17 115" stroke="#D8C8B5" stroke-width="1.8" fill="none" stroke-linecap="round"/>'
    '<ellipse cx="51" cy="21" rx="16" ry="9" transform="rotate(-35 51 21)" fill="#D8C8B5" opacity="0.60"/>'
    '<ellipse cx="40" cy="37" rx="15" ry="8" transform="rotate(-25 40 37)" fill="#D8C8B5" opacity="0.55"/>'
    '<ellipse cx="29" cy="55" rx="14" ry="8" transform="rotate(-13 29 55)" fill="#D8C8B5" opacity="0.50"/>'
    '<ellipse cx="21" cy="73" rx="13" ry="7" transform="rotate(-2 21 73)"  fill="#D8C8B5" opacity="0.45"/>'
    '</svg>'
)

_SHIELD_SVG = (
    '<svg width="48" height="48" viewBox="0 0 48 48" xmlns="http://www.w3.org/2000/svg" aria-hidden="true">'
    '<circle cx="24" cy="24" r="24" fill="#FFE4D0"/>'
    '<path d="M24 12 L33 16 L33 24 C33 29.5 29 34 24 36 C19 34 15 29.5 15 24 L15 16 Z"'
    ' stroke="#FF8A4C" stroke-width="1.6" fill="none" stroke-linejoin="round"/>'
    '<path d="M19.5 24 L23 27.5 L29.5 20.5"'
    ' stroke="#FF8A4C" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" fill="none"/>'
    '</svg>'
)

_QUESTION_SVG = (
    '<svg width="40" height="40" viewBox="0 0 40 40" xmlns="http://www.w3.org/2000/svg" aria-hidden="true">'
    '<circle cx="20" cy="20" r="18" stroke="#FF8A4C" stroke-width="1.5" fill="none"/>'
    '<text x="20" y="27" text-anchor="middle"'
    ' font-family="Georgia,\'Times New Roman\',serif" font-size="18" fill="#FF8A4C">?</text>'
    '</svg>'
)

_FOOTER_LEAF_SVG = (
    '<svg width="20" height="22" viewBox="0 0 20 22" xmlns="http://www.w3.org/2000/svg" aria-hidden="true">'
    '<path d="M10 20 C10 20,3.5 13,3.5 8 C3.5 4.5,6.5 2,10 2 C13.5 2,16.5 4.5,16.5 8 C16.5 13,10 20,10 20Z"'
    ' fill="#FF8A4C" opacity="0.75"/>'
    '<path d="M10 6 L10 17" stroke="white" stroke-width="1" stroke-linecap="round"/>'
    '</svg>'
)

_IG_SVG = (
    '<svg width="36" height="36" viewBox="0 0 36 36" xmlns="http://www.w3.org/2000/svg" aria-hidden="true">'
    '<circle cx="18" cy="18" r="17" stroke="#FF8A4C" stroke-width="1.4" fill="none"/>'
    '<rect x="11" y="11" width="14" height="14" rx="4" stroke="#FF8A4C" stroke-width="1.2" fill="none"/>'
    '<circle cx="18" cy="18" r="3.8" stroke="#FF8A4C" stroke-width="1.2" fill="none"/>'
    '<circle cx="23.5" cy="12.5" r="1.1" fill="#FF8A4C"/>'
    '</svg>'
)

_FB_SVG = (
    '<svg width="36" height="36" viewBox="0 0 36 36" xmlns="http://www.w3.org/2000/svg" aria-hidden="true">'
    '<circle cx="18" cy="18" r="17" stroke="#FF8A4C" stroke-width="1.4" fill="none"/>'
    '<text x="19" y="24" text-anchor="middle"'
    ' font-family="Arial,sans-serif" font-size="15" font-weight="bold" fill="#FF8A4C">f</text>'
    '</svg>'
)

_VYLA_SOCIAL_SVG = (
    '<svg width="36" height="36" viewBox="0 0 36 36" xmlns="http://www.w3.org/2000/svg" aria-hidden="true">'
    '<circle cx="18" cy="18" r="17" stroke="#FF8A4C" stroke-width="1.4" fill="none"/>'
    '<path d="M18 27 C18 27,11.5 20,11.5 15 C11.5 11.5,14.5 9,18 9 C21.5 9,24.5 11.5,24.5 15 C24.5 20,18 27,18 27Z"'
    ' fill="#FF8A4C" opacity="0.70"/>'
    '</svg>'
)


class EmailDeliveryError(RuntimeError):
    pass


class EmailService:
    def __init__(self, settings: Settings):
        self.settings = settings

    # ── Public send methods ───────────────────────────────────────────────────

    def send_signup_otp(self, recipient: str, code: str) -> None:
        subject = "Your Vyla verification code"
        text_body = (
            "Verify your email address to finish signing up for Vyla.\n\n"
            f"Your one-time verification code is: {code}\n\n"
            f"This code expires in {self.settings.otp_expiration_minutes} minutes.\n\n"
            "If you did not request this code, you can safely ignore this email."
        )
        html_body = self._render_otp_html(
            code=code,
            heading="Verify it’s you",
            subtext="Enter the verification code below to secure your Vyla account.",
        )
        self._send(recipient, subject, text_body, html_body=html_body, inline_images=[_LOGO_PATH])

    def send_password_reset_otp(self, recipient: str, code: str) -> None:
        subject = "Reset your Vyla password"
        text_body = (
            "Use this one-time code to reset your Vyla password.\n\n"
            f"Your password reset code is: {code}\n\n"
            f"This code expires in {self.settings.otp_expiration_minutes} minutes."
        )
        html_body = self._render_otp_html(
            code=code,
            heading="Reset your password",
            subtext="Enter the code below to reset your Vyla password.",
        )
        self._send(recipient, subject, text_body, html_body=html_body, inline_images=[_LOGO_PATH])

    # ── SMTP delivery ─────────────────────────────────────────────────────────

    def _send(
        self,
        recipient: str,
        subject: str,
        body: str,
        *,
        html_body: str | None = None,
        inline_images: list[Path] | None = None,
    ) -> None:
        if not self._is_smtp_ready():
            return
        message = self._build_message(recipient, subject, body, html_body, inline_images or [])
        self._deliver(message, subject)

    def _is_smtp_ready(self) -> bool:
        if not self.settings.smtp_enabled:
            msg = "SMTP is disabled; email not sent"
            if self.settings.environment in {"stage", "staging", "prod"}:
                logger.error("%s in %s", msg, self.settings.environment)
                raise EmailDeliveryError(msg)
            logger.warning("%s in %s", msg, self.settings.environment)
            return False
        if not self.settings.smtp_host or not self.settings.smtp_from_email:
            raise EmailDeliveryError("SMTP is enabled but host/from email is not configured")
        return True

    def _build_message(
        self,
        recipient: str,
        subject: str,
        body: str,
        html_body: str | None,
        inline_images: list[Path],
    ) -> EmailMessage:
        message = EmailMessage()
        message["Subject"] = subject
        message["From"] = (
            f"{self.settings.smtp_from_name} <{self.settings.smtp_from_email}>"
            if self.settings.smtp_from_name
            else self.settings.smtp_from_email
        )
        message["To"] = recipient
        message.set_content(body)
        if html_body:
            self._attach_html(message, html_body, inline_images)
        return message

    def _attach_html(self, message: EmailMessage, html_body: str, inline_images: list[Path]) -> None:
        if not inline_images:
            message.add_alternative(html_body, subtype="html")
            return
        cids = {path.name: make_msgid(domain="phora.email")[1:-1] for path in inline_images}
        html = html_body
        for name, cid in cids.items():
            html = html.replace(f"__CID_{name}__", f"cid:{cid}")
        message.add_alternative(html, subtype="html")
        html_part = message.get_payload()[-1]
        for path in inline_images:
            self._attach_inline_image(html_part, path, cids[path.name])

    def _attach_inline_image(self, html_part, path: Path, cid: str) -> None:
        if not path.exists():
            return
        mime_type, _ = mimetypes.guess_type(path.name)
        maintype, subtype = (mime_type or "image/png").split("/", 1)
        with path.open("rb") as handle:
            html_part.add_related(
                handle.read(),
                maintype=maintype,
                subtype=subtype,
                cid=f"<{cid}>",
                filename=path.name,
            )

    def _deliver(self, message: EmailMessage, subject: str) -> None:
        try:
            if self.settings.smtp_use_ssl:
                with smtplib.SMTP_SSL(self.settings.smtp_host, self.settings.smtp_port, timeout=10) as smtp:
                    self._authenticate(smtp)
                    smtp.send_message(message)
            else:
                with smtplib.SMTP(self.settings.smtp_host, self.settings.smtp_port, timeout=10) as smtp:
                    if self.settings.smtp_use_tls:
                        smtp.starttls()
                    self._authenticate(smtp)
                    smtp.send_message(message)
            logger.info("Email sent via SMTP", extra={"subject": subject})
        except Exception as exc:  # pragma: no cover - network path
            logger.exception("SMTP email delivery failed", extra={"subject": subject})
            raise EmailDeliveryError(f"Failed to send email: {exc}") from exc

    def _authenticate(self, smtp: smtplib.SMTP) -> None:
        if self.settings.smtp_username:
            smtp.login(self.settings.smtp_username, self.settings.smtp_password or "")

    # ── HTML template ─────────────────────────────────────────────────────────

    def _render_otp_html(self, code: str, heading: str, subtext: str) -> str:
        safe_heading = escape(heading)
        safe_subtext = escape(subtext)
        safe_digits = [escape(c) for c in code]
        expiry = self.settings.otp_expiration_minutes
        year = _date.today().year

        digit_cells = "".join(
            f'<td class="dt" style="padding:0 6px;">'
            f'<div class="db" style="width:72px;height:84px;line-height:84px;text-align:center;'
            f'border-radius:16px;background-color:#ffffff;border:1.5px solid #FFD5B8;'
            f'font-family:Georgia,\'Times New Roman\',serif;font-size:40px;font-weight:700;color:#3A1A08;">'
            f'{d}</div></td>'
            for d in safe_digits
        )

        return f"""\
<!DOCTYPE html>
<html lang="en" xmlns="http://www.w3.org/1999/xhtml" xmlns:o="urn:schemas-microsoft-com:office:office">
<head>
<meta charset="UTF-8"/>
<meta name="viewport" content="width=device-width,initial-scale=1.0"/>
<meta http-equiv="X-UA-Compatible" content="IE=edge"/>
<meta name="x-apple-disable-message-reformatting"/>
<title>{safe_heading}</title>
<!--[if mso]><noscript><xml><o:OfficeDocumentSettings><o:PixelsPerInch>96</o:PixelsPerInch></o:OfficeDocumentSettings></xml></noscript><![endif]-->
<style>{_EMAIL_CSS}</style>
</head>
<body style="margin:0;padding:0;background-color:#FFF6F0;">

<table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0" bgcolor="#FFF6F0" style="background-color:#FFF6F0;">
<tr>
<td class="eo" align="center" style="padding:28px 16px 36px;">

  <!-- Pill label -->
  <table role="presentation" cellspacing="0" cellpadding="0" border="0" align="center" style="margin:0 auto 14px auto;">
  <tr>
    <td style="padding:6px 18px;background-color:#FFE6D6;border-radius:20px;font-family:Arial,'Helvetica Neue',Helvetica,sans-serif;font-size:11px;font-weight:700;letter-spacing:0.14em;text-transform:uppercase;color:#A06A52;white-space:nowrap;">
      Your verification code &nbsp;&#9679;
    </td>
  </tr>
  </table>

  <!-- Main card -->
  <table role="presentation" align="center" width="640" cellspacing="0" cellpadding="0" border="0"
    style="max-width:640px;width:100%;background-color:#ffffff;border-radius:24px;border:1px solid #FFE0CC;-webkit-box-shadow:0 8px 48px rgba(74,44,26,0.10);box-shadow:0 8px 48px rgba(74,44,26,0.10);overflow:hidden;">

    <!-- ── HEADER: peach blob with logo + heading + leaf ── -->
    <tr>
      <td style="background-color:#FFE8D4;border-radius:0 0 60px 60px;padding:0;">
        <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0">
        <tr>
          <!-- Left balance spacer -->
          <td class="lc" width="72" style="width:72px;">&nbsp;</td>
          <!-- Center: logo + heading + subtext -->
          <td align="center" style="padding:36px 0 40px;">
            <img src="__CID_vyla-logo.png__" alt="Vyla" width="160" height="auto"
              style="display:block;width:160px;height:auto;margin:0 auto 24px;"/>
            <h1 style="margin:0 0 14px;font-family:Georgia,'Times New Roman',serif;font-size:30px;font-weight:700;color:#3A1A08;line-height:1.2;text-align:center;">
              {safe_heading}
            </h1>
            <p style="margin:0;font-family:Arial,'Helvetica Neue',Helvetica,sans-serif;font-size:15px;line-height:1.7;color:#7A4A32;text-align:center;max-width:360px;">
              {safe_subtext}
            </p>
          </td>
          <!-- Right: leaf branch decoration -->
          <td class="lc" width="72" valign="top" style="width:72px;padding-top:8px;vertical-align:top;">
            {_LEAF_BRANCH_SVG}
          </td>
        </tr>
        </table>
      </td>
    </tr>

    <!-- ── BODY ── -->
    <tr>
      <td class="cb" style="padding:32px 44px 36px;background-color:#ffffff;">

        <!-- OTP block -->
        <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0"
          style="background-color:#FFF6F0;border-radius:20px;border:1px solid #FFE0CC;margin-bottom:24px;">
        <tr>
          <td align="center" style="padding:28px 16px 24px;">
            <p style="margin:0 0 20px;font-family:Arial,'Helvetica Neue',Helvetica,sans-serif;font-size:13px;color:#A06A52;letter-spacing:0.04em;">
              Your One-Time Password (OTP) is:
            </p>
            <table role="presentation" cellspacing="0" cellpadding="0" border="0" align="center">
            <tr>
              {digit_cells}
            </tr>
            </table>
            <p style="margin:20px 0 0;font-family:Arial,'Helvetica Neue',Helvetica,sans-serif;font-size:13px;line-height:1.6;color:#A06A52;text-align:center;">
              This code is valid for <strong style="color:#FF8A4C;">{expiry}&nbsp;minutes</strong> and can only be used once.
            </p>
          </td>
        </tr>
        </table>

        <!-- Security card -->
        <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0"
          style="background-color:#FFFAF8;border-radius:18px;border:1px solid #FFE0CC;margin-bottom:28px;">
        <tr>
          <td style="padding:20px 22px;">
            <table role="presentation" cellspacing="0" cellpadding="0" border="0" width="100%">
            <tr>
              <td valign="middle" width="62" style="padding-right:16px;vertical-align:middle;">
                {_SHIELD_SVG}
              </td>
              <td valign="middle" style="vertical-align:middle;">
                <p style="margin:0 0 5px;font-family:Georgia,'Times New Roman',serif;font-size:15px;font-weight:700;color:#3A1A08;line-height:1.3;">
                  Keep your account safe
                </p>
                <p style="margin:0;font-family:Arial,'Helvetica Neue',Helvetica,sans-serif;font-size:14px;line-height:1.6;color:#A06A52;">
                  Never share this code with anyone.<br/>Vyla will never ask for your OTP.
                </p>
              </td>
            </tr>
            </table>
          </td>
        </tr>
        </table>

        <!-- Help section -->
        <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0">
        <tr>
          <td align="center" style="padding-bottom:10px;">
            {_QUESTION_SVG}
          </td>
        </tr>
        <tr>
          <td align="center">
            <p style="margin:0 0 8px;font-family:Georgia,'Times New Roman',serif;font-size:16px;font-weight:700;color:#3A1A08;">
              Didn&#8217;t request this?
            </p>
            <p style="margin:0;font-family:Arial,'Helvetica Neue',Helvetica,sans-serif;font-size:14px;line-height:1.7;color:#A06A52;max-width:400px;">
              If you didn&#8217;t request a code, you can safely ignore this email<br/>
              or <a href="mailto:support@vyla.health" style="color:#FF8A4C;text-decoration:none;font-weight:600;">contact our support team</a> if you have concerns.
            </p>
          </td>
        </tr>
        </table>

      </td>
    </tr>

    <!-- ── FOOTER ── -->
    <tr>
      <td align="center" style="padding:22px 32px 28px;background-color:#FFF6F0;border-top:1px solid #FFE0CC;">
        <!-- Leaf icon -->
        <table role="presentation" cellspacing="0" cellpadding="0" border="0" align="center" style="margin:0 auto 14px auto;">
        <tr>
          <td align="center">{_FOOTER_LEAF_SVG}</td>
        </tr>
        </table>
        <!-- Social icons -->
        <table role="presentation" cellspacing="0" cellpadding="0" border="0" align="center" style="margin:0 auto 16px auto;">
        <tr>
          <td style="padding:0 8px;">{_IG_SVG}</td>
          <td style="padding:0 8px;">{_FB_SVG}</td>
          <td style="padding:0 8px;">{_VYLA_SOCIAL_SVG}</td>
        </tr>
        </table>
        <!-- Copyright -->
        <p style="margin:0 0 8px;font-family:Arial,'Helvetica Neue',Helvetica,sans-serif;font-size:12px;line-height:1.5;color:#A06A52;">
          &#169; {year} Vyla Health Ltd. All rights reserved.
        </p>
        <!-- Links -->
        <p style="margin:0;font-family:Arial,'Helvetica Neue',Helvetica,sans-serif;font-size:12px;color:#FF8A4C;">
          <a href="#" style="color:#FF8A4C;text-decoration:none;">Privacy Policy</a>
          <span style="color:#FFD5B8;padding:0 6px;">&#8226;</span>
          <a href="#" style="color:#FF8A4C;text-decoration:none;">Terms of Use</a>
          <span style="color:#FFD5B8;padding:0 6px;">&#8226;</span>
          <a href="mailto:support@vyla.health" style="color:#FF8A4C;text-decoration:none;">Contact Us</a>
        </p>
      </td>
    </tr>

  </table>
</td>
</tr>
</table>

</body>
</html>"""
