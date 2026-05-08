from sqlalchemy import or_
from sqlalchemy.orm import Session

from phora.core.config import Settings
from phora.models import User
from phora.models.growth import FriendConnection
from phora.models.prediction import PredictionSnapshot
from phora.models.user import UserProfile
from phora.repositories.core import UserRepository
from phora.services.growth_analytics import GrowthAnalyticsService


class ComparisonService:
    def __init__(self, db: Session, settings: Settings):
        self.db = db
        self.settings = settings
        self.users = UserRepository(db)
        self.analytics = GrowthAnalyticsService(db)

    def friend_network(self, user_id: str) -> dict:
        connections = (
            self.db.query(FriendConnection)
            .filter(or_(FriendConnection.requester_user_id == user_id, FriendConnection.addressee_user_id == user_id))
            .order_by(FriendConnection.updated_at.desc())
            .all()
        )
        friends: list[dict] = []
        incoming: list[dict] = []
        outgoing: list[dict] = []
        for connection in connections:
            item = self._serialize_connection(connection, user_id)
            if connection.status == "accepted":
                friends.append(item)
            elif connection.addressee_user_id == user_id:
                incoming.append(item)
            else:
                outgoing.append(item)
        return {"friends": friends, "incoming_requests": incoming, "outgoing_requests": outgoing}

    def send_request(self, user_id: str, email: str) -> dict:
        target = self.users.by_email(email.lower().strip())
        if not target or target.id == user_id:
            raise ValueError("Friend could not be added")
        existing = (
            self.db.query(FriendConnection)
            .filter(
                or_(
                    (FriendConnection.requester_user_id == user_id) & (FriendConnection.addressee_user_id == target.id),
                    (FriendConnection.requester_user_id == target.id) & (FriendConnection.addressee_user_id == user_id),
                )
            )
            .first()
        )
        if existing:
            return self._serialize_connection(existing, user_id)
        connection = FriendConnection(requester_user_id=user_id, addressee_user_id=target.id)
        self.db.add(connection)
        self.db.flush()
        self.analytics.track(user_id, "growth.friend_request_sent", {"connection_id": connection.id, "target_user_id": target.id})
        return self._serialize_connection(connection, user_id)

    def respond_to_request(self, user_id: str, connection_id: str, *, accept: bool) -> dict:
        connection = self._connection_for_user(user_id, connection_id)
        if connection.addressee_user_id != user_id:
            raise PermissionError("Only the recipient can respond to this request")
        connection.status = "accepted" if accept else "declined"
        if accept:
            connection.accepted_at = self._now()
        else:
            connection.declined_at = self._now()
        self.db.flush()
        self.analytics.track(user_id, f"growth.friend_request_{'accepted' if accept else 'declined'}", {"connection_id": connection.id})
        return self._serialize_connection(connection, user_id)

    def update_permission(self, user_id: str, friend_id: str, *, enabled: bool) -> dict:
        connection = self._accepted_connection(user_id, friend_id)
        if connection.requester_user_id == user_id:
            connection.requester_compare_opt_in = enabled
        else:
            connection.addressee_compare_opt_in = enabled
        self.db.flush()
        self.analytics.track(user_id, "growth.compare_permission_updated", {"connection_id": connection.id, "enabled": enabled})
        return self._serialize_connection(connection, user_id)

    def compare_summary(self, user_id: str, friend_id: str) -> dict:
        connection = self._accepted_connection(user_id, friend_id)
        compare_enabled = connection.requester_compare_opt_in and connection.addressee_compare_opt_in
        friend = self.users.by_id(friend_id)
        if not friend:
            raise ValueError("Friend not found")
        if not compare_enabled:
            return {
                "friend": self._serialize_user(friend),
                "compare_enabled": False,
                "headline": "Comparison is locked",
                "summary": "Both friends need to opt in before comparison summaries are available.",
                "similarities": [],
                "differences": [],
                "metrics": [],
                "safe_notice": "Vyla only compares summary-level patterns. Exact cycle dates and logs are never shared.",
            }

        my_profile = self.users.ensure_profile(user_id)
        friend_profile = self.users.ensure_profile(friend_id)
        my_prediction = self._latest_prediction(user_id)
        friend_prediction = self._latest_prediction(friend_id)

        metrics = [
            self._metric("Cycle rhythm", self._cycle_rhythm_label(my_prediction), self._cycle_rhythm_label(friend_prediction)),
            self._metric("Energy pattern", self._energy_label(my_profile), self._energy_label(friend_profile)),
            self._metric("Wearable coverage", self._wearable_label(my_profile), self._wearable_label(friend_profile)),
            self._metric("Phase focus", self._phase_label(my_prediction), self._phase_label(friend_prediction)),
        ]
        similarities = [metric["summary"] for metric in metrics if metric["mine"] == metric["friend"]][:3]
        differences = [metric["summary"] for metric in metrics if metric["mine"] != metric["friend"]][:3]
        self.analytics.track(user_id, "growth.comparison_viewed", {"friend_user_id": friend_id, "connection_id": connection.id})
        return {
            "friend": self._serialize_user(friend),
            "compare_enabled": True,
            "headline": "Your patterns side by side",
            "summary": "This view compares broad cycle and wellness patterns, never exact dates or sensitive log values.",
            "similarities": similarities,
            "differences": differences,
            "metrics": metrics,
            "safe_notice": "Vyla only compares summary-level patterns. Exact cycle dates and logs are never shared.",
        }

    @staticmethod
    def _now():
        from datetime import UTC, datetime
        return datetime.now(UTC)

    def _connection_for_user(self, user_id: str, connection_id: str) -> FriendConnection:
        connection = (
            self.db.query(FriendConnection)
            .filter(
                FriendConnection.id == connection_id,
                or_(FriendConnection.requester_user_id == user_id, FriendConnection.addressee_user_id == user_id),
            )
            .one_or_none()
        )
        if not connection:
            raise ValueError("Friend request not found")
        return connection

    def _accepted_connection(self, user_id: str, friend_id: str) -> FriendConnection:
        connection = (
            self.db.query(FriendConnection)
            .filter(
                FriendConnection.status == "accepted",
                or_(
                    (FriendConnection.requester_user_id == user_id) & (FriendConnection.addressee_user_id == friend_id),
                    (FriendConnection.requester_user_id == friend_id) & (FriendConnection.addressee_user_id == user_id),
                ),
            )
            .one_or_none()
        )
        if not connection:
            raise ValueError("Friend connection not found")
        return connection

    def _serialize_connection(self, connection: FriendConnection, viewer_id: str) -> dict:
        friend_id = connection.addressee_user_id if connection.requester_user_id == viewer_id else connection.requester_user_id
        friend = self.users.by_id(friend_id)
        granted_by_me = connection.requester_compare_opt_in if connection.requester_user_id == viewer_id else connection.addressee_compare_opt_in
        granted_by_friend = connection.addressee_compare_opt_in if connection.requester_user_id == viewer_id else connection.requester_compare_opt_in
        return {
            "id": connection.id,
            "status": connection.status,
            "compare_enabled": granted_by_me and granted_by_friend,
            "compare_permission_granted_by_me": granted_by_me,
            "compare_permission_granted_by_friend": granted_by_friend,
            "created_at": connection.created_at,
            "updated_at": connection.updated_at,
            "friend": self._serialize_user(friend),
        }

    def _serialize_user(self, user: User | None) -> dict:
        if not user:
            return {"id": "", "display_name": "Unknown"}
        profile = self.users.ensure_profile(user.id)
        full_name = (profile.full_name or "").strip()
        first_name = full_name.split(" ")[0] if full_name else None
        return {
            "id": user.id,
            "display_name": full_name or user.email or "Vyla friend",
            "first_name": first_name,
        }

    def _latest_prediction(self, user_id: str) -> PredictionSnapshot | None:
        return (
            self.db.query(PredictionSnapshot)
            .filter(PredictionSnapshot.user_id == user_id)
            .order_by(PredictionSnapshot.generated_at.desc())
            .first()
        )

    @staticmethod
    def _cycle_rhythm_label(prediction: PredictionSnapshot | None) -> str:
        if not prediction:
            return "Still building"
        confidence = prediction.confidence or 0
        if confidence >= 0.8:
            return "Highly regular"
        if confidence >= 0.55:
            return "Fairly regular"
        return "More variable"

    @staticmethod
    def _energy_label(profile: UserProfile) -> str:
        conditions = dict(profile.conditions or {})
        if conditions.get("pcos") or conditions.get("endometriosis"):
            return "Needs more recovery"
        if profile.perimenopause_mode_active:
            return "More variable energy"
        return "Steady energy"

    @staticmethod
    def _wearable_label(profile: UserProfile) -> str:
        wearable = getattr(profile.wearable_type, "value", None) or "none"
        return "Connected wearable" if wearable != "none" else "Manual tracking"

    @staticmethod
    def _phase_label(prediction: PredictionSnapshot | None) -> str:
        if not prediction or not prediction.current_phase:
            return "Unknown"
        return prediction.current_phase.replace("_", " ").title()

    @staticmethod
    def _metric(label: str, mine: str, friend: str) -> dict:
        if mine == friend:
            summary = f"Both of you currently trend toward {mine.lower()}."
        else:
            summary = f"You trend toward {mine.lower()}, while your friend trends toward {friend.lower()}."
        return {"label": label, "mine": mine, "friend": friend, "summary": summary}
