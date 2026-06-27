import logging
import smtplib
from datetime import date as _date
from email.message import EmailMessage
from html import escape

from phora.core.config import Settings
from phora.services.email_i18n import translate

logger = logging.getLogger(__name__)

_EMAIL_CSS = (
    "* {box-sizing:border-box}"
    "body,table,td,p,a,h1,h2 {-webkit-text-size-adjust:100%;-ms-text-size-adjust:100%}"
    "table,td {mso-table-lspace:0pt;mso-table-rspace:0pt;border-collapse:collapse}"
    "body {margin:0;padding:0;background:#F7F7F8}"
    "a {color:#5336E8;text-decoration:none}"
    "@media only screen and (max-width:620px) {"
    ".email-outer {padding:20px 12px !important}"
    ".email-card {width:100% !important;border-radius:0 !important}"
    ".email-body {padding:28px 22px !important}"
    ".otp-code {font-size:30px !important;letter-spacing:6px !important}"
    "}"
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
        self._send(recipient, subject, text_body, html_body=html_body)

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
        self._send(recipient, subject, text_body, html_body=html_body)

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
        self._send(recipient, subject, text_body, html_body=html_body)

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
        self._send(recipient, subject, text_body, html_body=html_body)

    def send_account_confirmed(self, recipient: str) -> None:
        subject = "Your Vyla account is confirmed"
        text_body = (
            "Your account is confirmed.\n\n"
            "Welcome to Vyla. Your email has been verified and your account is now active."
        )
        html_body = self._render_account_confirmed_html()
        self._send(recipient, subject, text_body, html_body=html_body)

    # ── SMTP delivery ─────────────────────────────────────────────────────────

    def _send(
        self,
        recipient: str,
        subject: str,
        body: str,
        *,
        html_body: str | None = None,
    ) -> None:
        if not self._is_smtp_ready():
            return
        message = self._build_message(recipient, subject, body, html_body)
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
            message.add_alternative(html_body, subtype="html")
        return message

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
        safe_code = escape(code)
        expiry = self.settings.otp_expiration_minutes
        year = _date.today().year

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
<body style="margin:0;padding:0;background-color:#F7F7F8;">
<table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0" bgcolor="#F7F7F8" style="background-color:#F7F7F8;">
<tr>
<td class="email-outer" align="center" style="padding:32px 16px;">
  <table class="email-card" role="presentation" align="center" width="600" cellspacing="0" cellpadding="0" border="0"
    style="max-width:600px;width:100%;background-color:#ffffff;border:1px solid #E6E6EA;border-radius:8px;">
    <tr>
      <td class="email-body" align="left" style="padding:40px 44px;background-color:#ffffff;">
        <p style="margin:0 0 28px;font-family:Arial,'Helvetica Neue',Helvetica,sans-serif;font-size:16px;line-height:1.5;color:#191A33;font-weight:700;text-align:left;">
          Vyla
        </p>
        <h1 style="margin:0 0 14px;font-family:Arial,'Helvetica Neue',Helvetica,sans-serif;font-size:26px;font-weight:700;color:#191A33;line-height:1.3;text-align:left;">
          {safe_heading}
        </h1>
        <p style="margin:0 0 24px;font-family:Arial,'Helvetica Neue',Helvetica,sans-serif;font-size:15px;line-height:1.6;color:#4B4F63;text-align:left;">
          {safe_subtext}
        </p>
        <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0"
          style="background:#F6F5FF;border:1px solid #E3DFFF;border-radius:6px;margin:0 0 24px;">
        <tr>
          <td align="left" style="padding:20px 22px;">
            <p style="margin:0 0 8px;font-family:Arial,'Helvetica Neue',Helvetica,sans-serif;font-size:13px;line-height:1.5;color:#4B4F63;text-align:left;">
              {t('pill_label')}
            </p>
            <p class="otp-code" style="margin:0;font-family:'Courier New',Courier,monospace;font-size:36px;line-height:1.2;letter-spacing:8px;font-weight:700;color:#2F1EB8;text-align:left;">
              {safe_code}
            </p>
          </td>
        </tr>
        </table>
        <p style="margin:0 0 18px;font-family:Arial,'Helvetica Neue',Helvetica,sans-serif;font-size:14px;line-height:1.6;color:#4B4F63;text-align:left;">
          This code expires in <strong style="color:#191A33;">{expiry} minutes</strong>.
        </p>
        <p style="margin:0 0 18px;font-family:Arial,'Helvetica Neue',Helvetica,sans-serif;font-size:14px;line-height:1.6;color:#4B4F63;text-align:left;">
          {t('security_body')}
        </p>
        <p style="margin:0 0 24px;font-family:Arial,'Helvetica Neue',Helvetica,sans-serif;font-size:14px;line-height:1.6;color:#4B4F63;text-align:left;">
          {t('not_requested_body')}
        </p>
        <div style="height:1px;background:#E6E6EA;margin:0 0 18px;"></div>
        <p style="margin:0;font-family:Arial,'Helvetica Neue',Helvetica,sans-serif;font-size:13px;line-height:1.6;color:#6B7083;text-align:left;">
          The Vyla Team<br/>
          &copy; {year} Vyla Health
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
<body style="margin:0;padding:0;background-color:#F7F7F8;">
<table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0" bgcolor="#F7F7F8" style="background-color:#F7F7F8;">
<tr>
<td class="email-outer" align="center" style="padding:32px 16px;">
  <table class="email-card" role="presentation" align="center" width="600" cellspacing="0" cellpadding="0" border="0"
    style="max-width:600px;width:100%;background:#ffffff;border-radius:8px;border:1px solid #E6E6EA;">
    <tr>
      <td class="email-body" align="left" style="padding:40px 44px;background-color:#ffffff;">
        <p style="margin:0 0 28px;font-family:Arial,'Helvetica Neue',Helvetica,sans-serif;font-size:16px;line-height:1.5;color:#191A33;font-weight:700;text-align:left;">
          Vyla
        </p>
        <h1 style="margin:0 0 14px;font-family:Arial,'Helvetica Neue',Helvetica,sans-serif;font-size:26px;line-height:1.3;font-weight:700;color:#191A33;text-align:left;">
          Your account is confirmed
        </h1>
        <p style="margin:0 0 16px;font-family:Arial,'Helvetica Neue',Helvetica,sans-serif;font-size:15px;line-height:1.6;color:#4B4F63;text-align:left;">
          Welcome to Vyla. Your email has been verified and your account is now active.
        </p>
        <p style="margin:0 0 24px;font-family:Arial,'Helvetica Neue',Helvetica,sans-serif;font-size:15px;line-height:1.6;color:#4B4F63;text-align:left;">
          You can now use your account to track your cycle, review your logs, and manage your Vyla settings.
        </p>
        <table role="presentation" cellspacing="0" cellpadding="0" border="0" style="margin:0 0 24px;">
        <tr>
          <td align="left" style="border-radius:6px;background:#5336E8;">
            <a href="https://vyla.health/dashboard"
              style="display:inline-block;padding:12px 18px;font-family:Arial,'Helvetica Neue',Helvetica,sans-serif;font-size:14px;line-height:1.4;font-weight:700;color:#ffffff;text-decoration:none;">
              Go to My Dashboard
            </a>
          </td>
        </tr>
        </table>
        <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0"
          style="background:#F8F8FA;border:1px solid #E6E6EA;border-radius:6px;margin:0 0 24px;">
        <tr>
          <td align="left" style="padding:20px 22px;">
            <p style="margin:0 0 10px;font-family:Arial,'Helvetica Neue',Helvetica,sans-serif;font-size:14px;font-weight:700;line-height:1.5;color:#191A33;text-align:left;">
              What you can do next
            </p>
            <p style="margin:0 0 8px;font-family:Arial,'Helvetica Neue',Helvetica,sans-serif;font-size:14px;line-height:1.6;color:#4B4F63;text-align:left;">
              Track periods, symptoms, and moods.
            </p>
            <p style="margin:0 0 8px;font-family:Arial,'Helvetica Neue',Helvetica,sans-serif;font-size:14px;line-height:1.6;color:#4B4F63;text-align:left;">
              Review cycle trends and body changes.
            </p>
            <p style="margin:0;font-family:Arial,'Helvetica Neue',Helvetica,sans-serif;font-size:14px;line-height:1.6;color:#4B4F63;text-align:left;">
              Manage privacy and notification settings.
            </p>
          </td>
        </tr>
        </table>
        <p style="margin:0 0 24px;font-family:Arial,'Helvetica Neue',Helvetica,sans-serif;font-size:14px;line-height:1.6;color:#4B4F63;text-align:left;">
          Your privacy matters. Vyla will not share your information without your permission.
        </p>
        <p style="margin:0 0 24px;font-family:Arial,'Helvetica Neue',Helvetica,sans-serif;font-size:14px;line-height:1.6;color:#4B4F63;text-align:left;">
          If you did not create an account with Vyla, you can safely ignore this email.
        </p>
        <div style="height:1px;background:#E6E6EA;margin:0 0 18px;"></div>
        <p style="margin:0;font-family:Arial,'Helvetica Neue',Helvetica,sans-serif;font-size:13px;line-height:1.6;color:#6B7083;text-align:left;">
          The Vyla Team<br/>
          &copy; {year} Vyla Health
        </p>
      </td>
    </tr>
  </table>
</td>
</tr>
</table>
</body>
</html>"""
