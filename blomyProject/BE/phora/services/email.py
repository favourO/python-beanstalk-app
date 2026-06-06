import logging
import mimetypes
import smtplib
from datetime import date as _date
from email.utils import make_msgid
from email.message import EmailMessage
from html import escape
from pathlib import Path

from phora.core.config import Settings
from phora.services.email_i18n import translate

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
    '<circle cx="24" cy="24" r="24" fill="#F1EEFF"/>'
    '<path d="M24 12 L33 16 L33 24 C33 29.5 29 34 24 36 C19 34 15 29.5 15 24 L15 16 Z"'
    ' stroke="#5336E8" stroke-width="1.8" fill="none" stroke-linejoin="round"/>'
    '<path d="M19.5 24 L23 27.5 L29.5 20.5"'
    ' stroke="#5336E8" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" fill="none"/>'
    '</svg>'
)

_ACCOUNT_CONFIRMED_ICON_SVG = (
    '<svg width="64" height="64" viewBox="0 0 64 64" xmlns="http://www.w3.org/2000/svg" aria-hidden="true">'
    '<circle cx="32" cy="32" r="30" fill="#FDE9F1"/>'
    '<path d="M20 33 L28 41 L45 23" stroke="#7B235D" stroke-width="4" stroke-linecap="round" stroke-linejoin="round" fill="none"/>'
    '</svg>'
)




class EmailDeliveryError(RuntimeError):
    pass


class EmailService:
    def __init__(self, settings: Settings):
        self.settings = settings

    # ── Public send methods ───────────────────────────────────────────────────

    def send_signup_otp(self, recipient: str, code: str, locale: str = "en") -> None:
        t = lambda key: translate(locale, key)  # noqa: E731
        expiry = self.settings.otp_expiration_minutes
        subject = t("signup_subject")
        text_body = (
            f"{t('signup_text_intro')}\n\n"
            f"Your one-time verification code is: {code}\n\n"
            f"{t('otp_expires').format(expiry=expiry)}\n\n"
            "If you did not request this code, you can safely ignore this email."
        )
        html_body = self._render_otp_html(
            code=code,
            heading=t("signup_heading"),
            subtext=t("signup_subtext"),
            locale=locale,
        )
        self._send(recipient, subject, text_body, html_body=html_body, inline_images=[_LOGO_PATH])

    def send_set_password_otp(self, recipient: str, code: str, locale: str = "en") -> None:
        t = lambda key: translate(locale, key)  # noqa: E731
        expiry = self.settings.otp_expiration_minutes
        subject = t("reset_subject")
        text_body = (
            f"You requested to set a password for your account.\n\n"
            f"Your verification code is: {code}\n\n"
            f"{t('otp_expires').format(expiry=expiry)}"
        )
        html_body = self._render_otp_html(
            code=code,
            heading="Set Your Password",
            subtext="Use this code to set a password for your account.",
            locale=locale,
        )
        self._send(recipient, subject, text_body, html_body=html_body, inline_images=[_LOGO_PATH])

    def send_password_reset_otp(self, recipient: str, code: str, locale: str = "en") -> None:
        t = lambda key: translate(locale, key)  # noqa: E731
        expiry = self.settings.otp_expiration_minutes
        subject = t("reset_subject")
        text_body = (
            f"{t('reset_text_intro')}\n\n"
            f"Your password reset code is: {code}\n\n"
            f"{t('otp_expires').format(expiry=expiry)}"
        )
        html_body = self._render_otp_html(
            code=code,
            heading=t("reset_heading"),
            subtext=t("reset_subtext"),
            locale=locale,
        )
        self._send(recipient, subject, text_body, html_body=html_body, inline_images=[_LOGO_PATH])

    def send_account_deletion_otp(self, recipient: str, code: str, locale: str = "en") -> None:
        expiry = self.settings.otp_expiration_minutes
        subject = "Confirm account deletion - Vyla"
        text_body = (
            "Use this one-time passcode to confirm deleting your Vyla account.\n\n"
            f"Your confirmation code is: {code}\n\n"
            f"This code expires in {expiry} minutes.\n\n"
            "If you did not request this, change your password and contact support."
        )
        html_body = self._render_otp_html(
            code=code,
            heading="Confirm account deletion",
            subtext="Use this one-time passcode to confirm deleting your Vyla account.",
            locale=locale,
        )
        self._send(recipient, subject, text_body, html_body=html_body, inline_images=[_LOGO_PATH])

    def send_account_confirmed(self, recipient: str) -> None:
        subject = "Your Vyla account is confirmed"
        text_body = (
            "Your account is confirmed.\n\n"
            "Welcome to Vyla. Your email has been verified and your account is now active."
        )
        html_body = self._render_account_confirmed_html()
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

    def _render_otp_html(self, code: str, heading: str, subtext: str, locale: str = "en") -> str:
        t = lambda key: translate(locale, key)  # noqa: E731
        safe_heading = escape(heading)
        safe_subtext = escape(subtext)
        safe_digits = [escape(c) for c in code]
        expiry = self.settings.otp_expiration_minutes
        year = _date.today().year

        digit_cells = "".join(
            f'<td class="dt" style="padding:0 6px;">'
            f'<div class="db" style="width:72px;height:76px;line-height:76px;text-align:center;'
            f'font-family:Arial,\'Helvetica Neue\',Helvetica,sans-serif;font-size:44px;font-weight:800;color:#5336E8;text-shadow:0 2px 0 #B8A9FF;">'
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
<body style="margin:0;padding:0;background-color:#F4F2FF;">

<table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0" bgcolor="#F4F2FF" style="background-color:#F4F2FF;">
<tr>
<td class="eo" align="center" style="padding:8px 6px;">
  <table role="presentation" align="center" width="640" cellspacing="0" cellpadding="0" border="0"
    style="max-width:640px;width:100%;background-color:#ffffff;border-radius:20px;border:1px solid #ECE8FF;box-shadow:0 18px 48px rgba(45,35,120,0.08);overflow:hidden;">
    <tr>
      <td class="cb" align="center" style="padding:42px 44px 44px;background-color:#ffffff;">
        <img src="__CID_vyla-logo.png__" alt="Vyla" width="132" height="auto"
          style="display:block;width:132px;height:auto;margin:0 auto 28px;"/>
        <div style="width:156px;height:100px;margin:0 auto 30px;border-radius:12px;background:#DCD5FF;position:relative;border:1px solid #CEC4FF;">
          <div style="width:92px;height:62px;margin:0 auto;background:#F4F1FF;border-radius:0 0 18px 18px;border:1px solid #D8D0FF;"></div>
          <div style="width:62px;height:62px;line-height:62px;text-align:center;margin:-92px auto 0;border-radius:50%;background:#ffffff;border:3px solid #DDD5FF;color:#5336E8;font-size:28px;">&#128274;</div>
        </div>
        <h1 style="margin:0 0 18px;font-family:Arial,'Helvetica Neue',Helvetica,sans-serif;font-size:34px;font-weight:800;color:#191A33;line-height:1.2;text-align:center;">
              {safe_heading}
        </h1>
        <p style="margin:0 auto 30px;font-family:Arial,'Helvetica Neue',Helvetica,sans-serif;font-size:16px;line-height:1.7;color:#515779;text-align:center;max-width:430px;">
              {safe_subtext}
        </p>
        <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0"
          style="background:#F7F5FF;border-radius:14px;margin-bottom:28px;">
        <tr>
          <td align="center" style="padding:24px 14px;">
            <table role="presentation" cellspacing="0" cellpadding="0" border="0" align="center">
              <tr>{digit_cells}</tr>
            </table>
          </td>
        </tr>
        </table>
        <p style="margin:0 0 28px;font-family:Arial,'Helvetica Neue',Helvetica,sans-serif;font-size:16px;line-height:1.6;color:#515779;text-align:center;">
          &#9201; This code expires in <strong style="color:#5336E8;">{expiry} minutes</strong>.
        </p>
        <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0"
          style="background:#FCFBFF;border-radius:14px;border:1px solid #DDD7FF;margin-bottom:32px;">
        <tr>
          <td style="padding:22px 26px;">
            <table role="presentation" cellspacing="0" cellpadding="0" border="0" width="100%">
            <tr>
              <td valign="middle" width="56" style="padding-right:16px;vertical-align:middle;">
                {_SHIELD_SVG}
              </td>
              <td valign="middle" style="vertical-align:middle;">
                <p style="margin:0;font-family:Arial,'Helvetica Neue',Helvetica,sans-serif;font-size:16px;line-height:1.65;color:#515779;">
                  {t('security_body')}
                </p>
              </td>
            </tr>
            </table>
          </td>
        </tr>
        </table>
        <div style="height:1px;background:#E9E5FF;margin:0 0 28px;"></div>
        <p style="margin:0 0 18px;font-family:Arial,'Helvetica Neue',Helvetica,sans-serif;font-size:14px;line-height:1.7;color:#515779;text-align:center;">
              {t('not_requested_body')}
        </p>
        <p style="margin:0;font-family:Arial,'Helvetica Neue',Helvetica,sans-serif;font-size:14px;line-height:1.7;color:#515779;text-align:center;">
          - The <strong style="color:#5336E8;">Vyla</strong> Team
        </p>
      </td>
    </tr>
  </table>
</td>
</tr>
</table>

</body>
</html>"""

    def _render_account_confirmed_html(self) -> str:
        year = _date.today().year
        return f"""\
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8"/>
<meta name="viewport" content="width=device-width,initial-scale=1.0"/>
<title>Your account is confirmed</title>
<style>{_EMAIL_CSS}</style>
</head>
<body style="margin:0;padding:0;background-color:#FFF7FA;">
<table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0" bgcolor="#FFF7FA" style="background-color:#FFF7FA;">
<tr>
<td class="eo" align="center" style="padding:0 10px 28px;">
  <table role="presentation" align="center" width="640" cellspacing="0" cellpadding="0" border="0"
    style="max-width:640px;width:100%;background:#ffffff;border-radius:18px;overflow:hidden;border:1px solid #F8DFEA;">
    <tr>
      <td class="cb" align="center" style="padding:30px 34px 28px;">
        <img src="__CID_vyla-logo.png__" alt="Vyla" width="112" height="auto"
          style="display:block;width:112px;height:auto;margin:0 auto 18px;"/>
        {_ACCOUNT_CONFIRMED_ICON_SVG}
        <h1 style="margin:18px 0 10px;font-family:Arial,'Helvetica Neue',Helvetica,sans-serif;font-size:28px;line-height:1.25;font-weight:800;color:#4A153C;text-align:center;">
          Your account is confirmed! &#127881;
        </h1>
        <p style="margin:0 auto 8px;max-width:420px;font-family:Arial,'Helvetica Neue',Helvetica,sans-serif;font-size:14px;line-height:1.55;color:#1E1732;text-align:center;">
          Welcome to Vyla! Your email has been verified and your account is now active.
        </p>
        <p style="margin:0 auto 22px;max-width:420px;font-family:Arial,'Helvetica Neue',Helvetica,sans-serif;font-size:14px;line-height:1.55;color:#1E1732;text-align:center;">
          You are one step closer to understanding your body and living your best, healthiest life.
        </p>

        <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0"
          style="background:#FFF2F5;border-radius:12px;margin:0 0 18px;">
        <tr>
          <td align="center" style="padding:22px 14px;border-right:1px solid #F4CAD8;">
            <div style="font-size:34px;line-height:1;color:#FF6F86;">&#128197;</div>
            <p style="margin:10px 0 5px;font-family:Arial,'Helvetica Neue',Helvetica,sans-serif;font-size:13px;font-weight:800;color:#2B1830;">Track Your Cycle</p>
            <p style="margin:0;font-family:Arial,'Helvetica Neue',Helvetica,sans-serif;font-size:12px;line-height:1.45;color:#1E1732;">Log periods, symptoms, and moods with ease.</p>
          </td>
          <td align="center" style="padding:22px 14px;border-right:1px solid #F4CAD8;">
            <div style="font-size:34px;line-height:1;color:#FF6F86;">&#128200;</div>
            <p style="margin:10px 0 5px;font-family:Arial,'Helvetica Neue',Helvetica,sans-serif;font-size:13px;font-weight:800;color:#2B1830;">Understand Your Patterns</p>
            <p style="margin:0;font-family:Arial,'Helvetica Neue',Helvetica,sans-serif;font-size:12px;line-height:1.45;color:#1E1732;">Get insights into cycle trends and body changes.</p>
          </td>
          <td align="center" style="padding:22px 14px;">
            <div style="font-size:34px;line-height:1;color:#FF6F86;">&#10048;</div>
            <p style="margin:10px 0 5px;font-family:Arial,'Helvetica Neue',Helvetica,sans-serif;font-size:13px;font-weight:800;color:#2B1830;">Feel Your Best</p>
            <p style="margin:0;font-family:Arial,'Helvetica Neue',Helvetica,sans-serif;font-size:12px;line-height:1.45;color:#1E1732;">Personalized tips for fitness, wellness, and self-care.</p>
          </td>
        </tr>
        </table>

        <p style="margin:0 0 18px;font-family:Arial,'Helvetica Neue',Helvetica,sans-serif;font-size:14px;line-height:1.55;color:#1E1732;text-align:center;">
          We are so happy to have you on this journey to better health.<br/>
          <strong>You have got this!</strong> &#128170;
        </p>
        <table role="presentation" width="86%" cellspacing="0" cellpadding="0" border="0"
          style="background:#FFF5F7;border-radius:10px;">
        <tr>
          <td width="72" align="center" style="padding:16px 10px;">{_SHIELD_SVG}</td>
          <td align="left" style="padding:16px 18px 16px 0;">
            <p style="margin:0 0 4px;font-family:Arial,'Helvetica Neue',Helvetica,sans-serif;font-size:13px;font-weight:800;color:#4A153C;">Your privacy matters</p>
            <p style="margin:0;font-family:Arial,'Helvetica Neue',Helvetica,sans-serif;font-size:12px;line-height:1.5;color:#1E1732;">Your data is safe with us. We will never share your information without your permission.</p>
          </td>
        </tr>
        </table>
      </td>
    </tr>
    <tr>
      <td align="center" style="padding:16px 24px 22px;border-top:1px solid #F8DFEA;">
        <p style="margin:0 0 4px;font-family:Arial,'Helvetica Neue',Helvetica,sans-serif;font-size:12px;color:#1E1732;">
          If you did not create an account with Vyla, you can safely ignore this email.
        </p>
        <p style="margin:0;font-family:Arial,'Helvetica Neue',Helvetica,sans-serif;font-size:11px;color:#6B5064;">&#169; {year} Vyla Health</p>
      </td>
    </tr>
  </table>
</td>
</tr>
</table>
</body>
</html>"""
