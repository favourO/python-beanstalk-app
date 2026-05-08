import base64
import textwrap
import uuid
from collections import Counter
from datetime import UTC, datetime

import boto3
from sqlalchemy import desc, select
from sqlalchemy.orm import Session

from phora.core.config import Settings
from phora.models import CycleRecord, DailyLog
from phora.models.enums import LogType
from phora.repositories.core import CycleRepository
from phora.services.growth_analytics import GrowthAnalyticsService
from phora.services.home_service import HomeService
from phora.services.ml_client import MlClient

_SECTION_CYCLE_OVERVIEW = "cycle_overview"
_SECTION_PERIOD_DETAILS = "period_details"
_SECTION_SYMPTOMS = "symptoms"
_SECTION_TRENDS = "trends_insights"
_SECTION_NOTES = "notes"

_SECTION_ORDER = (
    _SECTION_CYCLE_OVERVIEW,
    _SECTION_PERIOD_DETAILS,
    _SECTION_SYMPTOMS,
    _SECTION_TRENDS,
    _SECTION_NOTES,
)

_SECTION_LABELS = {
    _SECTION_CYCLE_OVERVIEW: "Cycle overview",
    _SECTION_PERIOD_DETAILS: "Period details",
    _SECTION_SYMPTOMS: "Symptoms",
    _SECTION_TRENDS: "Trends and insights",
    _SECTION_NOTES: "Notes",
}


class ShareService:
    def __init__(self, db: Session, settings: Settings, ml_client: MlClient):
        self.db = db
        self.settings = settings
        self.ml_client = ml_client
        self.analytics = GrowthAnalyticsService(db)
        self.cycles = CycleRepository(db)
        self._report_storage_client = None

    def build_payload(self, user_id: str) -> dict:
        home = HomeService(
            self.db,
            self.settings,
            self.ml_client,
        ).get_home_payload(user_id)
        share_id = str(uuid.uuid4())
        first_name = home.user.first_name or "You"
        phase = (home.main_status.current_phase or "cycle").replace("_", " ").title()
        cycle_day = home.main_status.current_cycle_day or 0
        countdown = home.main_status.countdown_to_next_period_days
        confidence = home.main_status.prediction_confidence.replace("_", " ").title()
        summary = home.today_focus.message
        tags = list(home.today_focus.tags or [])
        deep_link_id = share_id[:8]
        deep_link_url = f"vyla://insight/{share_id}?src=share&dl={deep_link_id}"

        payload = {
            "share_id": share_id,
            "title": f"{first_name}'s cycle snapshot",
            "subtitle": f"Cycle day {cycle_day} • {phase}",
            "summary": summary,
            "privacy_note": (
                "Shared from Vyla using privacy-safe, summary-level insights only."
            ),
            "deep_link_url": deep_link_url,
            "cards": [
                {
                    "title": "Phase",
                    "value": phase,
                    "subtitle": "Current predicted phase",
                    "accent": "lavender",
                },
                {
                    "title": "Confidence",
                    "value": confidence,
                    "subtitle": "Prediction confidence",
                    "accent": "pink",
                },
                {
                    "title": "Next period",
                    "value": "Soon" if countdown is None else f"{countdown}d",
                    "subtitle": "Time until next predicted period",
                    "accent": "rose",
                },
                {
                    "title": "Focus",
                    "value": (
                        home.fitness_guidance.recommended_intensity or "steady"
                    ).replace("_", " ").title(),
                    "subtitle": home.fitness_guidance.reason,
                    "accent": "plum",
                },
            ],
            "tags": tags[:4],
        }
        self.analytics.track(
            user_id,
            "growth.share_payload_created",
            {
                "share_id": share_id,
                "deep_link_id": deep_link_id,
                "tags": payload["tags"],
            },
        )
        return payload

    def get_share_config(self, user_id: str) -> dict:
        HomeService(
            self.db,
            self.settings,
            self.ml_client,
        ).get_home_payload(user_id)
        self.analytics.track(user_id, "growth.share_config_viewed", {})
        return {
            "screen_title": "Share your cycle insight",
            "screen_subtitle": "Share reports with your doctor or partner",
            "hero_title": "Empower your conversations",
            "hero_body": (
                "Share your cycle insights to get better understanding, support, "
                "and care."
            ),
            "privacy_note": (
                "Your data is encrypted, generated only for you, and shared "
                "securely."
            ),
            "sections": [
                {
                    "id": _SECTION_CYCLE_OVERVIEW,
                    "title": "Cycle Overview",
                    "subtitle": "Dates and phases summary",
                    "description": (
                        "Current phase, cycle day, and recent cycle-length context."
                    ),
                    "selected_by_default": True,
                },
                {
                    "id": _SECTION_PERIOD_DETAILS,
                    "title": "Period Details",
                    "subtitle": "Period start date, duration and flow",
                    "description": (
                        "Recent period timing, duration, and logged flow patterns."
                    ),
                    "selected_by_default": True,
                },
                {
                    "id": _SECTION_SYMPTOMS,
                    "title": "Symptoms",
                    "subtitle": "Physical, emotional and other symptoms",
                    "description": (
                        "Frequently logged symptoms, mood trends, and pain notes."
                    ),
                    "selected_by_default": True,
                },
                {
                    "id": _SECTION_TRENDS,
                    "title": "Trends & Insights",
                    "subtitle": "Cycle patterns and key insights",
                    "description": (
                        "Prediction confidence, upcoming timing, and current focus."
                    ),
                    "selected_by_default": True,
                },
                {
                    "id": _SECTION_NOTES,
                    "title": "Notes",
                    "subtitle": "Your personal notes and observations",
                    "description": (
                        "The latest note snippets from symptom or cycle tracking."
                    ),
                    "selected_by_default": True,
                },
            ],
            "audiences": [
                {
                    "id": "doctor",
                    "title": "Doctor",
                    "subtitle": "Share with your healthcare provider",
                },
                {
                    "id": "partner",
                    "title": "Partner",
                    "subtitle": "Share with your partner",
                },
            ],
            "methods": [
                {
                    "id": "secure_link",
                    "title": "Secure Link",
                    "subtitle": "Share via link",
                },
                {
                    "id": "pdf_report",
                    "title": "PDF Report",
                    "subtitle": "Download and share",
                },
                {
                    "id": "email",
                    "title": "Email",
                    "subtitle": "Send via email",
                },
            ],
            "cycle_count_options": [
                {"value": 1, "label": "1 cycle"},
                {"value": 3, "label": "3 cycles"},
                {"value": 6, "label": "6 cycles"},
            ],
            "default_audience": "partner",
            "default_method": "secure_link",
            "default_cycle_count": 3,
        }

    def get_cycle_report_config(self, user_id: str) -> dict:
        HomeService(
            self.db,
            self.settings,
            self.ml_client,
        ).get_home_payload(user_id)
        self.analytics.track(user_id, "growth.cycle_report_config_viewed", {})
        return {
            "screen_title": "Cycle Report",
            "screen_subtitle": (
                "Generate and share a concise summary from your recent cycles."
            ),
            "hero_title": "Create a shareable cycle report",
            "hero_body": (
                "Build a compact report from your recent cycle history, symptoms, "
                "and trends to share with your doctor or partner."
            ),
            "privacy_note": (
                "You control which sections are included each time a report is "
                "generated."
            ),
            "sections": [
                {
                    "id": _SECTION_CYCLE_OVERVIEW,
                    "title": "Cycle Overview",
                    "subtitle": "Dates and phases summary",
                    "description": (
                        "Current phase, cycle day, and recent cycle-length context."
                    ),
                    "selected_by_default": True,
                },
                {
                    "id": _SECTION_PERIOD_DETAILS,
                    "title": "Period Details",
                    "subtitle": "Period start date, duration and flow",
                    "description": (
                        "Recent period timing, duration, and logged flow patterns."
                    ),
                    "selected_by_default": True,
                },
                {
                    "id": _SECTION_SYMPTOMS,
                    "title": "Symptoms",
                    "subtitle": "Physical, emotional and other symptoms",
                    "description": (
                        "Frequently logged symptoms, mood trends, and pain notes."
                    ),
                    "selected_by_default": True,
                },
                {
                    "id": _SECTION_TRENDS,
                    "title": "Trends & Insights",
                    "subtitle": "Cycle patterns and key insights",
                    "description": (
                        "Prediction confidence, upcoming timing, and current focus."
                    ),
                    "selected_by_default": True,
                },
                {
                    "id": _SECTION_NOTES,
                    "title": "Notes",
                    "subtitle": "Your personal notes and observations",
                    "description": (
                        "The latest note snippets from symptom or cycle tracking."
                    ),
                    "selected_by_default": False,
                },
            ],
            "audiences": [
                {
                    "id": "doctor",
                    "title": "Doctor",
                    "subtitle": "Share with your healthcare provider",
                },
                {
                    "id": "partner",
                    "title": "Partner",
                    "subtitle": "Share with your partner",
                },
            ],
            "methods": [
                {
                    "id": "pdf_report",
                    "title": "PDF Report",
                    "subtitle": "Download and share",
                },
                {
                    "id": "secure_link",
                    "title": "Secure Link",
                    "subtitle": "Share via link",
                },
                {
                    "id": "email",
                    "title": "Email",
                    "subtitle": "Send via email",
                },
            ],
            "cycle_count_options": [
                {"value": 1, "label": "1 cycle"},
                {"value": 3, "label": "3 cycles"},
                {"value": 6, "label": "6 cycles"},
                {"value": 12, "label": "12 cycles"},
            ],
            "default_audience": "doctor",
            "default_method": "pdf_report",
            "default_cycle_count": 3,
        }

    def generate_share(
        self,
        user_id: str,
        *,
        section_ids: list[str],
        audience: str,
        method: str,
        cycle_count: int,
    ) -> dict:
        selected_sections = self._sanitize_section_ids(section_ids)
        home = HomeService(
            self.db,
            self.settings,
            self.ml_client,
        ).get_home_payload(user_id)
        cycles = self._recent_cycles(user_id, cycle_count)
        logs = self._recent_logs(user_id, cycle_count)
        share_id = str(uuid.uuid4())
        deep_link_id = share_id[:8]
        title = self._report_title(home, audience)
        subtitle = self._report_subtitle(home, cycle_count)
        sections = [
            self._build_section_summary(section_id, home=home, cycles=cycles, logs=logs)
            for section_id in selected_sections
        ]
        report_file_name = self._report_file_name(home, cycle_count)
        report_pdf_bytes = self._build_pdf_report(
            title=title,
            subtitle=subtitle,
            sections=sections,
            footer="Generated securely by Vyla.",
        )
        secure_link_url = self._store_report_and_get_secure_link(
            share_id=share_id,
            audience=audience,
            method=method,
            deep_link_id=deep_link_id,
            title=title,
            subtitle=subtitle,
            sections=sections,
            report_file_name=report_file_name,
            report_pdf_bytes=report_pdf_bytes,
        )
        share_text = self._build_share_text(
            title=title,
            subtitle=subtitle,
            sections=sections,
            secure_link_url=secure_link_url,
        )
        email_subject = f"{title} from Vyla"
        email_body = self._build_email_body(
            audience=audience,
            title=title,
            subtitle=subtitle,
            sections=sections,
            secure_link_url=secure_link_url,
        )
        report_pdf_base64 = base64.b64encode(report_pdf_bytes).decode("ascii")

        self.analytics.track(
            user_id,
            "growth.share_generated",
            {
                "share_id": share_id,
                "audience": audience,
                "method": method,
                "cycle_count": cycle_count,
                "section_ids": selected_sections,
                "deep_link_id": deep_link_id,
            },
        )

        return {
            "share_id": share_id,
            "audience": audience,
            "method": method,
            "title": title,
            "subtitle": subtitle,
            "privacy_note": (
                "This summary includes only the sections you selected and can be "
                "regenerated any time."
            ),
            "secure_link_url": secure_link_url,
            "share_text": share_text,
            "email_subject": email_subject,
            "email_body": email_body,
            "report_file_name": report_file_name,
            "report_pdf_base64": report_pdf_base64,
            "sections": sections,
        }

    def track_event(
        self,
        user_id: str,
        *,
        share_id: str,
        event: str,
        channel: str | None,
        deep_link_id: str | None,
    ) -> None:
        self.analytics.track(
            user_id,
            f"growth.{event}",
            {
                "share_id": share_id,
                "channel": channel,
                "deep_link_id": deep_link_id,
            },
        )

    def _sanitize_section_ids(self, section_ids: list[str]) -> list[str]:
        requested = {item.strip() for item in section_ids if item.strip()}
        selected = [item for item in _SECTION_ORDER if item in requested]
        return selected or list(_SECTION_ORDER)

    def _recent_cycles(self, user_id: str, cycle_count: int) -> list[CycleRecord]:
        stmt = (
            select(CycleRecord)
            .where(CycleRecord.user_id == user_id)
            .order_by(desc(CycleRecord.period_start_date))
            .limit(max(1, cycle_count))
        )
        return list(self.db.scalars(stmt))

    def _recent_logs(self, user_id: str, cycle_count: int) -> list[DailyLog]:
        days = max(35, cycle_count * 40)
        return self.cycles.recent_logs(user_id, days=days)

    def _report_title(self, home, audience: str) -> str:
        owner = home.user.first_name or "Cycle"
        suffix = "for your doctor" if audience == "doctor" else "for your partner"
        return f"{owner}'s cycle insight {suffix}"

    def _report_subtitle(self, home, cycle_count: int) -> str:
        phase = (home.main_status.current_phase or "cycle").replace("_", " ").title()
        cycle_day = home.main_status.current_cycle_day or 0
        noun = "cycle" if cycle_count == 1 else "cycles"
        return f"Cycle day {cycle_day} • {phase} • Last {cycle_count} {noun}"

    def _build_section_summary(self, section_id: str, *, home, cycles, logs) -> dict:
        return {
            "id": section_id,
            "title": _SECTION_LABELS[section_id],
            "summary": self._section_text(section_id, home=home, cycles=cycles, logs=logs),
        }

    def _section_text(self, section_id: str, *, home, cycles, logs) -> str:
        if section_id == _SECTION_CYCLE_OVERVIEW:
            average_cycle = self._average_value(
                [
                    item.cycle_length_days or int(round(item.mu_cycle or 0))
                    for item in cycles
                    if (item.cycle_length_days or item.mu_cycle)
                ]
            )
            cycle_phrase = (
                f"Recent cycles average {average_cycle} days."
                if average_cycle is not None
                else "Recent cycle length is still being learned."
            )
            next_period = home.main_status.countdown_to_next_period_days
            next_phrase = (
                "Next period timing is still being estimated."
                if next_period is None
                else f"Next predicted period is in about {next_period} days."
            )
            phase = (home.main_status.current_phase or "cycle").replace("_", " ").title()
            return (
                f"Current cycle day {home.main_status.current_cycle_day or 0} in the "
                f"{phase} phase. {cycle_phrase} {next_phrase}"
            )

        if section_id == _SECTION_PERIOD_DETAILS:
            latest_cycle = cycles[0] if cycles else None
            start_text = (
                latest_cycle.period_start_date.strftime("%b %d, %Y")
                if latest_cycle is not None
                else "not available"
            )
            duration = latest_cycle.menses_length if latest_cycle else None
            period_logs = [item for item in logs if item.log_type == LogType.PERIOD]
            intensity = self._most_common(
                [
                    str(item.payload.get("intensity", "")).strip().lower()
                    for item in period_logs
                    if item.payload.get("intensity")
                ]
            )
            duration_phrase = (
                f"Periods usually last about {duration} days."
                if duration
                else "Duration data is still being collected."
            )
            flow_phrase = (
                f"Most recent logged flow trend was {intensity}."
                if intensity
                else "No recent flow intensity was logged."
            )
            return (
                f"Most recent period started on {start_text}. "
                f"{duration_phrase} {flow_phrase}"
            )

        if section_id == _SECTION_SYMPTOMS:
            symptom_logs = [item for item in logs if item.log_type == LogType.SYMPTOM]
            physical = []
            moods = []
            pain_levels = []
            for item in symptom_logs:
                raw_physical = item.payload.get("physical")
                if isinstance(raw_physical, list):
                    physical.extend(
                        str(value).strip().lower()
                        for value in raw_physical
                        if str(value).strip()
                    )
                mood = item.payload.get("mood")
                if mood:
                    moods.append(str(mood).strip().lower())
                pain = item.payload.get("pain_level")
                if isinstance(pain, (int, float)):
                    pain_levels.append(int(pain))
            top_symptoms = ", ".join(self._top_values(physical, limit=3))
            mood = self._most_common(moods)
            pain_average = self._average_value(pain_levels)
            symptom_phrase = (
                f"Most logged symptoms were {top_symptoms}."
                if top_symptoms
                else "No recent symptom pattern was logged."
            )
            mood_phrase = f"Mood trend leaned {mood}." if mood else "Mood trend is limited."
            pain_phrase = (
                f"Average logged pain was {pain_average}/10."
                if pain_average is not None
                else "Pain intensity was not consistently logged."
            )
            return f"{symptom_phrase} {mood_phrase} {pain_phrase}"

        if section_id == _SECTION_TRENDS:
            focus = home.today_focus.message.strip()
            confidence = home.main_status.prediction_confidence.replace("_", " ").title()
            fertile = (
                "The fertile window is active today."
                if home.fertility.fertile_today
                else "The fertile window is not active today."
            )
            return (
                f"Prediction confidence is {confidence}. {fertile} "
                f"Today's focus: {focus}"
            )

        if section_id == _SECTION_NOTES:
            note_lines: list[str] = []
            for item in logs:
                notes = item.payload.get("notes")
                if notes:
                    clean = " ".join(str(notes).split())
                    if clean:
                        note_lines.append(clean)
            if not note_lines:
                return "No personal notes were included in the selected cycles."
            preview = " ".join(note_lines[:2])
            if len(preview) > 180:
                preview = f"{preview[:177].rstrip()}..."
            return preview

        raise ValueError(f"Unsupported share section: {section_id}")

    def _build_share_text(
        self,
        *,
        title: str,
        subtitle: str,
        sections: list[dict],
        secure_link_url: str,
    ) -> str:
        lines = [title, subtitle, ""]
        for section in sections:
            lines.append(f"{section['title']}: {section['summary']}")
        lines.extend(["", f"Secure link: {secure_link_url}"])
        return "\n".join(lines)

    def _build_email_body(
        self,
        *,
        audience: str,
        title: str,
        subtitle: str,
        sections: list[dict],
        secure_link_url: str,
    ) -> str:
        intro = (
            "Hi Doctor,"
            if audience == "doctor"
            else "Hi,"
        )
        lines = [intro, "", f"I generated a cycle insight summary from Vyla.", ""]
        lines.append(title)
        lines.append(subtitle)
        lines.append("")
        for section in sections:
            lines.append(f"- {section['title']}: {section['summary']}")
        lines.extend(
            [
                "",
                f"Secure link: {secure_link_url}",
                "",
                "Shared securely from Vyla.",
            ]
        )
        return "\n".join(lines)

    def _store_report_and_get_secure_link(
        self,
        *,
        share_id: str,
        audience: str,
        method: str,
        deep_link_id: str,
        title: str,
        subtitle: str,
        sections: list[dict],
        report_file_name: str,
        report_pdf_bytes: bytes,
    ) -> str:
        bucket = (self.settings.report_share_bucket or "").strip()
        if not bucket:
            return (
                f"vyla://share/report/{share_id}?src={method}&aud={audience}&dl={deep_link_id}"
            )

        object_key = self._report_object_key(share_id, report_file_name)
        self._upload_report_pdf(
            bucket=bucket,
            object_key=object_key,
            report_pdf_bytes=report_pdf_bytes,
            title=title,
            subtitle=subtitle,
            audience=audience,
            method=method,
            deep_link_id=deep_link_id,
            sections=sections,
        )
        return self._build_presigned_pdf_url(
            bucket=bucket,
            object_key=object_key,
            report_file_name=report_file_name,
        )

    def _report_object_key(self, share_id: str, report_file_name: str) -> str:
        return f"growth/share-reports/{share_id}/{report_file_name}"

    def _upload_report_pdf(
        self,
        *,
        bucket: str,
        object_key: str,
        report_pdf_bytes: bytes,
        title: str,
        subtitle: str,
        audience: str,
        method: str,
        deep_link_id: str,
        sections: list[dict],
    ) -> None:
        client = self._get_report_storage_client()
        client.put_object(
            Bucket=bucket,
            Key=object_key,
            Body=report_pdf_bytes,
            ContentType="application/pdf",
            ContentDisposition='attachment; filename="{}"'.format(
                object_key.rsplit("/", 1)[-1]
            ),
            Metadata={
                "title": self._storage_metadata_value(title),
                "subtitle": self._storage_metadata_value(subtitle),
                "audience": audience,
                "method": method,
                "deep-link-id": deep_link_id,
                "sections": ",".join(section["id"] for section in sections),
                "generated-at": datetime.now(UTC).isoformat(),
            },
            ServerSideEncryption="AES256",
        )

    def _build_presigned_pdf_url(
        self,
        *,
        bucket: str,
        object_key: str,
        report_file_name: str,
    ) -> str:
        client = self._get_report_storage_client()
        return str(
            client.generate_presigned_url(
                "get_object",
                Params={
                    "Bucket": bucket,
                    "Key": object_key,
                    "ResponseContentType": "application/pdf",
                    "ResponseContentDisposition": (
                        f'attachment; filename="{report_file_name}"'
                    ),
                },
                ExpiresIn=self.settings.report_share_url_expiration_seconds,
            )
        )

    def _get_report_storage_client(self):
        if self._report_storage_client is None:
            self._report_storage_client = boto3.client("s3")
        return self._report_storage_client

    def _storage_metadata_value(self, value: str) -> str:
        compact = " ".join(value.split())
        if not compact:
            return "n/a"
        return compact.encode("ascii", "ignore").decode("ascii")[:240] or "n/a"

    def _report_file_name(self, home, cycle_count: int) -> str:
        base = (home.user.first_name or "phora").strip().lower().replace(" ", "-")
        stamp = datetime.now(UTC).strftime("%Y%m%d")
        return f"{base}-cycle-insight-{cycle_count}-cycles-{stamp}.pdf"

    def _build_pdf_report(
        self,
        *,
        title: str,
        subtitle: str,
        sections: list[dict],
        footer: str,
    ) -> bytes:
        lines = [title, subtitle, ""]
        for section in sections:
            lines.append(section["title"])
            lines.extend(textwrap.wrap(section["summary"], width=78))
            lines.append("")
        lines.append(footer)
        return self._simple_pdf(lines)

    def _simple_pdf(self, lines: list[str]) -> bytes:
        content_lines = ["BT", "/F1 12 Tf", "50 780 Td", "14 TL"]
        first = True
        for line in lines:
            for wrapped in textwrap.wrap(line or " ", width=82) or [" "]:
                escaped = self._pdf_escape(wrapped)
                if first:
                    content_lines.append(f"({escaped}) Tj")
                    first = False
                else:
                    content_lines.append(f"T* ({escaped}) Tj")
        content_lines.append("ET")
        content = "\n".join(content_lines).encode("ascii")

        objects = [
            b"1 0 obj << /Type /Catalog /Pages 2 0 R >> endobj",
            b"2 0 obj << /Type /Pages /Count 1 /Kids [3 0 R] >> endobj",
            (
                b"3 0 obj << /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] "
                b"/Resources << /Font << /F1 4 0 R >> >> /Contents 5 0 R >> endobj"
            ),
            b"4 0 obj << /Type /Font /Subtype /Type1 /BaseFont /Helvetica >> endobj",
            (
                f"5 0 obj << /Length {len(content)} >> stream\n".encode("ascii")
                + content
                + b"\nendstream endobj"
            ),
        ]

        pdf = bytearray(b"%PDF-1.4\n")
        offsets = [0]
        for obj in objects:
            offsets.append(len(pdf))
            pdf.extend(obj)
            pdf.extend(b"\n")
        xref_offset = len(pdf)
        pdf.extend(f"xref\n0 {len(offsets)}\n".encode("ascii"))
        pdf.extend(b"0000000000 65535 f \n")
        for offset in offsets[1:]:
            pdf.extend(f"{offset:010d} 00000 n \n".encode("ascii"))
        pdf.extend(
            (
                f"trailer << /Size {len(offsets)} /Root 1 0 R >>\n"
                f"startxref\n{xref_offset}\n%%EOF"
            ).encode("ascii")
        )
        return bytes(pdf)

    def _pdf_escape(self, value: str) -> str:
        ascii_value = value.encode("ascii", "replace").decode("ascii")
        return (
            ascii_value.replace("\\", "\\\\")
            .replace("(", "\\(")
            .replace(")", "\\)")
        )

    def _average_value(self, values: list[int]) -> int | None:
        if not values:
            return None
        return round(sum(values) / len(values))

    def _most_common(self, values: list[str]) -> str | None:
        if not values:
            return None
        return Counter(values).most_common(1)[0][0].replace("_", " ")

    def _top_values(self, values: list[str], *, limit: int) -> list[str]:
        counts = Counter(values)
        return [item.replace("_", " ") for item, _ in counts.most_common(limit)]
