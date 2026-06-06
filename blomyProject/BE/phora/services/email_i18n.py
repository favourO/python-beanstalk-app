from __future__ import annotations

SUPPORTED_LANGUAGES = {"en", "es", "fr", "de", "pt"}

STRINGS: dict[str, dict[str, str]] = {
    "en": {
        "signup_subject": "Your Vyla verification code",
        "signup_text_intro": "Verify your email address to finish signing up for Vyla.",
        "signup_heading": "Verify it's you",
        "signup_subtext": "Enter the verification code below to secure your Vyla account.",
        "reset_subject": "Reset your Vyla password",
        "reset_text_intro": "Use this one-time code to reset your Vyla password.",
        "reset_heading": "Reset your password",
        "reset_subtext": "Enter the code below to reset your Vyla password.",
        "otp_label": "Your One-Time Password (OTP) is:",
        "otp_expires": "This code is valid for {expiry} minutes and can only be used once.",
        "security_title": "Keep your account safe",
        "security_body": "Never share this code with anyone.<br/>Vyla will never ask for your OTP.",
        "not_requested_title": "Didn’t request this?",
        "not_requested_body": (
            "If you didn’t request a code, you can safely ignore this email<br/>"
            "or <a href=\"mailto:support@vyla.health\" style=\"color:#FF8A4C;text-decoration:none;"
            "font-weight:600;\">contact our support team</a> if you have concerns."
        ),
        "pill_label": "Your verification code",
        "privacy_policy": "Privacy Policy",
        "terms_of_use": "Terms of Use",
        "contact_us": "Contact Us",
    },
    "de": {
        "signup_subject": "Dein Vyla-Bestätigungscode",
        "signup_text_intro": "Bestätige deine E-Mail-Adresse, um die Registrierung bei Vyla abzuschließen.",
        "signup_heading": "Bestätige, dass du es bist",
        "signup_subtext": "Gib den Bestätigungscode unten ein, um dein Vyla-Konto zu sichern.",
        "reset_subject": "Setze dein Vyla-Passwort zurück",
        "reset_text_intro": "Verwende diesen Einmalcode, um dein Vyla-Passwort zurückzusetzen.",
        "reset_heading": "Passwort zurücksetzen",
        "reset_subtext": "Gib den Code unten ein, um dein Vyla-Passwort zurückzusetzen.",
        "otp_label": "Dein Einmalpasswort (OTP) lautet:",
        "otp_expires": "Dieser Code ist {expiry} Minuten gültig und kann nur einmal verwendet werden.",
        "security_title": "Halte dein Konto sicher",
        "security_body": "Teile diesen Code niemals mit jemandem.<br/>Vyla wird dich nie nach deinem OTP fragen.",
        "not_requested_title": "Nicht angefordert?",
        "not_requested_body": (
            "Falls du keinen Code angefordert hast, kannst du diese E-Mail ignorieren<br/>"
            "oder <a href=\"mailto:support@vyla.health\" style=\"color:#FF8A4C;text-decoration:none;"
            "font-weight:600;\">kontaktiere unser Support-Team</a>, wenn du Bedenken hast."
        ),
        "pill_label": "Dein Bestätigungscode",
        "privacy_policy": "Datenschutzrichtlinie",
        "terms_of_use": "Nutzungsbedingungen",
        "contact_us": "Kontakt",
    },
    "es": {
        "signup_subject": "Tu código de verificación de Vyla",
        "signup_text_intro": "Verifica tu dirección de correo electrónico para terminar de registrarte en Vyla.",
        "signup_heading": "Verifica que eres tú",
        "signup_subtext": "Ingresa el código de verificación a continuación para asegurar tu cuenta Vyla.",
        "reset_subject": "Restablece tu contraseña de Vyla",
        "reset_text_intro": "Usa este código de un solo uso para restablecer tu contraseña de Vyla.",
        "reset_heading": "Restablecer contraseña",
        "reset_subtext": "Ingresa el código a continuación para restablecer tu contraseña de Vyla.",
        "otp_label": "Tu contraseña de un solo uso (OTP) es:",
        "otp_expires": "Este código es válido por {expiry} minutos y solo se puede usar una vez.",
        "security_title": "Mantén tu cuenta segura",
        "security_body": "Nunca compartas este código con nadie.<br/>Vyla nunca te pedirá tu OTP.",
        "not_requested_title": "¿No lo solicitaste?",
        "not_requested_body": (
            "Si no solicitaste un código, puedes ignorar este correo<br/>"
            "o <a href=\"mailto:support@vyla.health\" style=\"color:#FF8A4C;text-decoration:none;"
            "font-weight:600;\">contacta a nuestro equipo de soporte</a> si tienes dudas."
        ),
        "pill_label": "Tu código de verificación",
        "privacy_policy": "Política de privacidad",
        "terms_of_use": "Términos de uso",
        "contact_us": "Contáctanos",
    },
    "fr": {
        "signup_subject": "Votre code de vérification Vyla",
        "signup_text_intro": "Vérifiez votre adresse e-mail pour terminer votre inscription à Vyla.",
        "signup_heading": "Vérifiez votre identité",
        "signup_subtext": "Entrez le code de vérification ci-dessous pour sécuriser votre compte Vyla.",
        "reset_subject": "Réinitialisez votre mot de passe Vyla",
        "reset_text_intro": "Utilisez ce code à usage unique pour réinitialiser votre mot de passe Vyla.",
        "reset_heading": "Réinitialiser le mot de passe",
        "reset_subtext": "Entrez le code ci-dessous pour réinitialiser votre mot de passe Vyla.",
        "otp_label": "Votre mot de passe à usage unique (OTP) est :",
        "otp_expires": "Ce code est valable pendant {expiry} minutes et ne peut être utilisé qu'une seule fois.",
        "security_title": "Protégez votre compte",
        "security_body": "Ne partagez jamais ce code avec qui que ce soit.<br/>Vyla ne vous demandera jamais votre OTP.",
        "not_requested_title": "Vous n'avez pas demandé cela ?",
        "not_requested_body": (
            "Si vous n'avez pas demandé de code, vous pouvez ignorer cet e-mail<br/>"
            "ou <a href=\"mailto:support@vyla.health\" style=\"color:#FF8A4C;text-decoration:none;"
            "font-weight:600;\">contactez notre équipe d'assistance</a> si vous avez des doutes."
        ),
        "pill_label": "Votre code de vérification",
        "privacy_policy": "Politique de confidentialité",
        "terms_of_use": "Conditions d'utilisation",
        "contact_us": "Nous contacter",
    },
    "pt": {
        "signup_subject": "Seu código de verificação Vyla",
        "signup_text_intro": "Verifique seu endereço de e-mail para concluir o cadastro no Vyla.",
        "signup_heading": "Confirme sua identidade",
        "signup_subtext": "Insira o código de verificação abaixo para proteger sua conta Vyla.",
        "reset_subject": "Redefina sua senha do Vyla",
        "reset_text_intro": "Use este código de uso único para redefinir sua senha do Vyla.",
        "reset_heading": "Redefinir senha",
        "reset_subtext": "Insira o código abaixo para redefinir sua senha do Vyla.",
        "otp_label": "Sua senha de uso único (OTP) é:",
        "otp_expires": "Este código é válido por {expiry} minutos e só pode ser usado uma vez.",
        "security_title": "Mantenha sua conta segura",
        "security_body": "Nunca compartilhe este código com ninguém.<br/>O Vyla nunca pedirá seu OTP.",
        "not_requested_title": "Não solicitou isso?",
        "not_requested_body": (
            "Se você não solicitou um código, pode ignorar este e-mail<br/>"
            "ou <a href=\"mailto:support@vyla.health\" style=\"color:#FF8A4C;text-decoration:none;"
            "font-weight:600;\">entre em contato com nossa equipe de suporte</a> se tiver dúvidas."
        ),
        "pill_label": "Seu código de verificação",
        "privacy_policy": "Política de privacidade",
        "terms_of_use": "Termos de uso",
        "contact_us": "Fale conosco",
    },
}


def translate(locale: str, key: str) -> str:
    lang = locale.split("-")[0].split("_")[0].lower()
    if lang not in SUPPORTED_LANGUAGES:
        lang = "en"
    return STRINGS[lang].get(key, STRINGS["en"][key])


def parse_accept_language(header: str | None) -> str:
    if not header:
        return "en"
    for part in header.split(","):
        tag = part.split(";")[0].strip().split("-")[0].lower()
        if tag in SUPPORTED_LANGUAGES:
            return tag
    return "en"
