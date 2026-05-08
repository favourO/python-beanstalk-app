from __future__ import annotations

import hashlib
import hmac
import json
from datetime import UTC, datetime
from typing import Any

import httpx
from sqlalchemy.orm import Session

from phora.core.config import Settings
from phora.models import Invoice, Subscription, User
from phora.services.billing_catalog import resolve_stripe_price, stripe_price_metadata


class StripeBillingError(ValueError):
    pass


class StripeWebhookError(ValueError):
    pass


class StripeBillingService:
    _EPHEMERAL_KEY_API_VERSION = "2026-02-25.clover"

    def __init__(self, db: Session, settings: Settings):
        self.db = db
        self.settings = settings

    def create_checkout_session(
        self,
        *,
        user_id: str,
        country: str,
        plan_id: str,
        interval: str,
        success_url: str | None,
        cancel_url: str | None,
    ) -> dict[str, Any]:
        if not self.settings.stripe_secret_key:
            raise StripeBillingError("Stripe secret key is not configured.")

        user = self.db.query(User).filter(User.id == user_id).one_or_none()
        if not user or not user.email:
            raise StripeBillingError("A verified email is required before starting Stripe checkout.")

        try:
            price_details = resolve_stripe_price(country=country, plan_id=plan_id, interval=interval)
        except ValueError as exc:
            raise StripeBillingError(str(exc)) from exc
        success = success_url or self.settings.stripe_checkout_success_url
        cancel = cancel_url or self.settings.stripe_checkout_cancel_url
        if not success or not cancel:
            raise StripeBillingError("success_url and cancel_url are required for Stripe checkout.")

        payload = {
            "mode": "subscription",
            "success_url": success,
            "cancel_url": cancel,
            "client_reference_id": user.id,
            "customer_email": user.email,
            "allow_promotion_codes": "true",
            "line_items[0][price]": str(price_details["provider_price_id"]),
            "line_items[0][quantity]": "1",
            "metadata[user_id]": user.id,
            "metadata[plan_id]": plan_id,
            "metadata[interval]": interval,
            "metadata[country]": price_details["country"],
            "subscription_data[metadata][user_id]": user.id,
            "subscription_data[metadata][plan_id]": plan_id,
            "subscription_data[metadata][interval]": interval,
            "subscription_data[metadata][country]": price_details["country"],
        }

        response = self._stripe_post("/v1/checkout/sessions", data=payload)
        return {
            "checkout_session_id": response["id"],
            "checkout_url": response["url"],
            "publishable_key": self.settings.stripe_publishable_key,
            "customer_email": user.email,
            "provider_product_id": price_details["provider_product_id"],
            "provider_price_id": price_details["provider_price_id"],
            "plan_id": plan_id,
            "interval": interval,
        }

    def create_payment_sheet_subscription(
        self,
        *,
        user_id: str,
        country: str,
        plan_id: str,
        interval: str,
    ) -> dict[str, Any]:
        if not self.settings.stripe_secret_key:
            raise StripeBillingError("Stripe secret key is not configured.")
        if not self.settings.stripe_publishable_key:
            raise StripeBillingError("Stripe publishable key is not configured.")

        user = self.db.query(User).filter(User.id == user_id).one_or_none()
        if not user or not user.email:
            raise StripeBillingError("A verified email is required before starting Stripe checkout.")

        try:
            price_details = resolve_stripe_price(country=country, plan_id=plan_id, interval=interval)
        except ValueError as exc:
            raise StripeBillingError(str(exc)) from exc

        local_subscription = self._latest_user_subscription(user.id)
        if local_subscription and self._has_unexpired_paid_access(local_subscription):
            raise StripeBillingError("An active paid subscription already exists.")

        customer_id = (
            local_subscription.provider_customer_id
            if local_subscription
            and local_subscription.provider == "stripe"
            and local_subscription.provider_customer_id
            else None
        )
        if not customer_id:
            customer_payload = {
                "email": user.email,
                "metadata[user_id]": user.id,
            }
            if user.profile and user.profile.full_name:
                customer_payload["name"] = user.profile.full_name
            customer = self._stripe_post("/v1/customers", data=customer_payload)
            customer_id = customer["id"]

        subscription_payload = {
            "customer": customer_id,
            "items[0][price]": str(price_details["provider_price_id"]),
            "payment_behavior": "default_incomplete",
            "payment_settings[save_default_payment_method]": "on_subscription",
            "expand[0]": "latest_invoice.payment_intent",
            "metadata[user_id]": user.id,
            "metadata[plan_id]": plan_id,
            "metadata[interval]": interval,
            "metadata[country]": str(price_details["country"]),
        }
        stripe_subscription = self._stripe_post("/v1/subscriptions", data=subscription_payload)
        payment_intent = self._subscription_payment_intent(stripe_subscription)
        payment_intent_client_secret = payment_intent.get("client_secret") if payment_intent else None
        if not payment_intent_client_secret:
            raise StripeBillingError("Stripe did not return a payment intent client secret.")

        ephemeral_key = self._stripe_post(
            "/v1/ephemeral_keys",
            data={"customer": customer_id},
            stripe_version=self._EPHEMERAL_KEY_API_VERSION,
        )
        ephemeral_key_secret = ephemeral_key.get("secret")
        if not ephemeral_key_secret:
            raise StripeBillingError("Stripe did not return a customer ephemeral key.")

        if not local_subscription:
            local_subscription = Subscription(user_id=user.id)
            self.db.add(local_subscription)

        self._apply_subscription_details(
            local_subscription,
            stripe_subscription=stripe_subscription,
            customer_id=customer_id,
            price_details=price_details,
            plan_id=plan_id,
            interval=interval,
        )
        self.db.commit()

        return {
            "payment_intent_client_secret": payment_intent_client_secret,
            "customer_id": customer_id,
            "customer_ephemeral_key_secret": ephemeral_key_secret,
            "publishable_key": self.settings.stripe_publishable_key,
            "customer_email": user.email,
            "provider_subscription_id": stripe_subscription["id"],
            "provider_product_id": price_details["provider_product_id"],
            "provider_price_id": price_details["provider_price_id"],
            "plan_id": plan_id,
            "interval": interval,
            "currency": price_details["currency"],
            "amount_minor": price_details["price_minor"],
            "display_price": price_details["display_price"],
        }

    def sync_payment_sheet_subscription(self, *, user_id: str, provider_subscription_id: str) -> Subscription:
        if not self.settings.stripe_secret_key:
            raise StripeBillingError("Stripe secret key is not configured.")

        local_subscription = (
            self.db.query(Subscription)
            .filter(
                Subscription.user_id == user_id,
                Subscription.provider == "stripe",
                Subscription.provider_subscription_id == provider_subscription_id,
            )
            .one_or_none()
        )
        if not local_subscription:
            raise StripeBillingError("Stripe subscription was not found for this user.")

        stripe_subscription = self._stripe_get(
            f"/v1/subscriptions/{provider_subscription_id}",
            params={"expand[]": "latest_invoice.payment_intent"},
        )
        metadata = stripe_subscription.get("metadata") or {}
        metadata_user_id = metadata.get("user_id")
        if metadata_user_id and metadata_user_id != user_id:
            raise StripeBillingError("Stripe subscription does not belong to this user.")

        self._handle_subscription_event(stripe_subscription)
        self.db.flush()
        refreshed = (
            self.db.query(Subscription)
            .filter(Subscription.provider_subscription_id == provider_subscription_id)
            .one()
        )
        self.db.commit()
        return refreshed

    def handle_webhook(self, *, payload: bytes, signature: str | None) -> dict[str, str]:
        event = self._verify_event(payload=payload, signature=signature)
        event_type = event.get("type")
        data_object = ((event.get("data") or {}).get("object")) or {}

        if event_type == "checkout.session.completed":
            self._handle_checkout_completed(data_object)
        elif event_type in {"customer.subscription.created", "customer.subscription.updated", "customer.subscription.deleted"}:
            self._handle_subscription_event(data_object)
        elif event_type in {"invoice.paid", "invoice.payment_failed"}:
            self._handle_invoice_event(data_object)

        self.db.commit()
        return {"status": "ok"}

    def cancel_subscription(self, subscription: Subscription, *, immediate: bool = False) -> None:
        if subscription.provider != "stripe":
            raise StripeBillingError("Subscription is not managed by Stripe.")
        if not self.settings.stripe_secret_key:
            raise StripeBillingError("Stripe secret key is not configured.")

        if subscription.provider_subscription_id and subscription.status in {"active", "trialing", "past_due", "unpaid"}:
            if immediate:
                response = self._stripe_delete(f"/v1/subscriptions/{subscription.provider_subscription_id}")
            else:
                response = self._stripe_post(
                    f"/v1/subscriptions/{subscription.provider_subscription_id}",
                    data={"cancel_at_period_end": "true"},
                )
            subscription.status = response.get("status") or ("canceled" if immediate else "active")
            period_end = response.get("current_period_end")
            if immediate:
                subscription.current_period_end = None
            elif period_end:
                subscription.current_period_end = datetime.fromtimestamp(period_end, tz=UTC)
        else:
            subscription.status = "canceled"

    def _verify_event(self, *, payload: bytes, signature: str | None) -> dict[str, Any]:
        secrets = self._webhook_secrets()
        if not secrets:
            raise StripeWebhookError("Stripe webhook secret is not configured.")
        if not signature:
            raise StripeWebhookError("Missing Stripe-Signature header.")

        components: dict[str, list[str]] = {}
        for part in signature.split(","):
            key, _, value = part.partition("=")
            if not key or not value:
                continue
            components.setdefault(key, []).append(value)

        timestamp = next(iter(components.get("t", [])), None)
        signatures = components.get("v1", [])
        if not timestamp or not signatures:
            raise StripeWebhookError("Invalid Stripe-Signature header.")

        now = int(datetime.now(UTC).timestamp())
        if abs(now - int(timestamp)) > self.settings.stripe_webhook_tolerance_seconds:
            raise StripeWebhookError("Stripe webhook timestamp is outside the allowed tolerance.")

        signed_payload = f"{timestamp}.{payload.decode('utf-8')}"
        expected_signatures = [
            hmac.new(secret.encode("utf-8"), signed_payload.encode("utf-8"), hashlib.sha256).hexdigest()
            for secret in secrets
        ]
        if not any(
            hmac.compare_digest(expected, candidate)
            for expected in expected_signatures
            for candidate in signatures
        ):
            raise StripeWebhookError("Invalid Stripe webhook signature.")

        return json.loads(payload)

    def _webhook_secrets(self) -> list[str]:
        configured = self.settings.stripe_webhook_secret or ""
        return [secret.strip() for secret in configured.replace("\n", ",").split(",") if secret.strip()]

    def _handle_checkout_completed(self, checkout_session: dict[str, Any]) -> None:
        metadata = checkout_session.get("metadata") or {}
        user_id = metadata.get("user_id") or checkout_session.get("client_reference_id")
        if not user_id:
            return

        subscription = self._find_or_create_subscription(
            user_id=user_id,
            provider_subscription_id=checkout_session.get("subscription"),
        )
        if checkout_session.get("customer"):
            subscription.provider_customer_id = checkout_session["customer"]
        if metadata.get("plan_id"):
            subscription.tier = metadata["plan_id"]
        subscription.provider = "stripe"
        subscription.status = checkout_session.get("status") or subscription.status
        subscription.currency = (checkout_session.get("currency") or subscription.currency or "").upper() or None
        amount_total = checkout_session.get("amount_total")
        if amount_total is not None:
            subscription.amount = float(amount_total) / 100
        if metadata.get("interval"):
            subscription.billing_interval = metadata["interval"]

    def _handle_subscription_event(self, stripe_subscription: dict[str, Any]) -> None:
        metadata = stripe_subscription.get("metadata") or {}
        items = ((stripe_subscription.get("items") or {}).get("data")) or []
        price = (items[0].get("price") if items else None) or {}
        price_id = price.get("id")
        derived_metadata = stripe_price_metadata(price_id) if price_id else None
        user_id = metadata.get("user_id")

        subscription = self._find_or_create_subscription(
            user_id=user_id,
            provider_subscription_id=stripe_subscription.get("id"),
        )
        subscription.provider = "stripe"
        subscription.provider_customer_id = stripe_subscription.get("customer")
        subscription.provider_price_id = price_id
        subscription.status = stripe_subscription.get("status") or subscription.status
        subscription.currency = (stripe_subscription.get("currency") or price.get("currency") or subscription.currency or "").upper() or None
        subscription.billing_interval = ((price.get("recurring") or {}).get("interval")) or metadata.get("interval") or subscription.billing_interval
        if derived_metadata:
            subscription.tier = derived_metadata["plan_id"]
            subscription.billing_interval = subscription.billing_interval or derived_metadata["interval"]
        elif metadata.get("plan_id"):
            subscription.tier = metadata["plan_id"]

        unit_amount = price.get("unit_amount")
        if unit_amount is not None:
            subscription.amount = float(unit_amount) / 100
        period_end = stripe_subscription.get("current_period_end")
        if period_end:
            subscription.current_period_end = datetime.fromtimestamp(period_end, tz=UTC)

    def _handle_invoice_event(self, stripe_invoice: dict[str, Any]) -> None:
        invoice = self.db.query(Invoice).filter(Invoice.provider_invoice_id == stripe_invoice.get("id")).one_or_none()
        if not invoice:
            invoice = Invoice(provider_invoice_id=stripe_invoice.get("id"))
            self.db.add(invoice)

        subscription_provider_id = self._invoice_subscription_id(stripe_invoice)
        metadata = self._invoice_metadata(stripe_invoice)
        price = self._invoice_price(stripe_invoice)
        subscription = None
        if subscription_provider_id:
            subscription = (
                self.db.query(Subscription)
                .filter(Subscription.provider_subscription_id == subscription_provider_id)
                .one_or_none()
            )
            if not subscription:
                subscription = self._find_or_create_subscription(
                    user_id=metadata.get("user_id"),
                    provider_subscription_id=subscription_provider_id,
                )
            invoice.subscription_id = subscription.id

        invoice.provider_customer_id = stripe_invoice.get("customer")
        invoice.provider_payment_intent_id = stripe_invoice.get("payment_intent")
        invoice.total = float(stripe_invoice.get("total", 0)) / 100
        invoice.currency = (stripe_invoice.get("currency") or invoice.currency).upper()
        invoice.status = stripe_invoice.get("status") or invoice.status

        if subscription:
            subscription.provider = "stripe"
            subscription.provider_customer_id = stripe_invoice.get("customer") or subscription.provider_customer_id
            if price.get("id"):
                subscription.provider_price_id = price["id"]
            if metadata.get("plan_id"):
                subscription.tier = metadata["plan_id"]
            subscription.currency = (stripe_invoice.get("currency") or price.get("currency") or subscription.currency or "").upper() or None
            subscription.billing_interval = ((price.get("recurring") or {}).get("interval")) or metadata.get("interval") or subscription.billing_interval
            unit_amount = price.get("unit_amount")
            if unit_amount is not None:
                subscription.amount = float(unit_amount) / 100
            period_end = self._invoice_period_end(stripe_invoice)
            if period_end:
                subscription.current_period_end = datetime.fromtimestamp(period_end, tz=UTC)

        if subscription and stripe_invoice.get("status") == "paid":
            subscription.status = "active"
        elif subscription and stripe_invoice.get("status") in {"open", "uncollectible"}:
            subscription.status = "payment_failed"

    def _invoice_subscription_id(self, stripe_invoice: dict[str, Any]) -> str | None:
        if stripe_invoice.get("subscription"):
            return stripe_invoice["subscription"]

        parent_subscription = (
            ((stripe_invoice.get("parent") or {}).get("subscription_details") or {}).get("subscription")
        )
        if parent_subscription:
            return parent_subscription

        lines = ((stripe_invoice.get("lines") or {}).get("data")) or []
        for line in lines:
            if line.get("subscription"):
                return line["subscription"]
        return None

    def _invoice_metadata(self, stripe_invoice: dict[str, Any]) -> dict[str, str]:
        sources = [
            stripe_invoice.get("subscription_details") or {},
            ((stripe_invoice.get("parent") or {}).get("subscription_details") or {}),
        ]
        lines = ((stripe_invoice.get("lines") or {}).get("data")) or []
        sources.extend(lines)

        for source in sources:
            metadata = source.get("metadata") or {}
            if metadata:
                return metadata
        return {}

    def _invoice_price(self, stripe_invoice: dict[str, Any]) -> dict[str, Any]:
        lines = ((stripe_invoice.get("lines") or {}).get("data")) or []
        for line in lines:
            price = line.get("price") or {}
            if price:
                return price
        return {}

    def _invoice_period_end(self, stripe_invoice: dict[str, Any]) -> int | None:
        lines = ((stripe_invoice.get("lines") or {}).get("data")) or []
        for line in lines:
            period_end = (line.get("period") or {}).get("end")
            if period_end:
                return period_end
        return None

    def _latest_user_subscription(self, user_id: str) -> Subscription | None:
        return (
            self.db.query(Subscription)
            .filter(Subscription.user_id == user_id)
            .order_by(Subscription.created_at.desc())
            .first()
        )

    def _has_unexpired_paid_access(self, subscription: Subscription) -> bool:
        if subscription.tier == "free":
            return False
        if subscription.status in {"active", "trialing"}:
            return True
        if subscription.status in {"canceled", "cancelled"} and subscription.current_period_end:
            current_period_end = subscription.current_period_end
            if current_period_end.tzinfo is None:
                current_period_end = current_period_end.replace(tzinfo=UTC)
            return current_period_end > datetime.now(UTC)
        return False

    def _subscription_payment_intent(self, stripe_subscription: dict[str, Any]) -> dict[str, Any] | None:
        latest_invoice = stripe_subscription.get("latest_invoice")
        if not isinstance(latest_invoice, dict):
            return None
        payment_intent = latest_invoice.get("payment_intent")
        return payment_intent if isinstance(payment_intent, dict) else None

    def _apply_subscription_details(
        self,
        subscription: Subscription,
        *,
        stripe_subscription: dict[str, Any],
        customer_id: str,
        price_details: dict[str, str | int],
        plan_id: str,
        interval: str,
    ) -> None:
        subscription.provider = "stripe"
        subscription.provider_customer_id = customer_id
        subscription.provider_subscription_id = stripe_subscription.get("id")
        subscription.provider_price_id = str(price_details["provider_price_id"])
        subscription.tier = plan_id
        subscription.status = stripe_subscription.get("status") or "incomplete"
        subscription.currency = str(price_details["currency"])
        subscription.amount = float(price_details["price_minor"]) / 100
        subscription.billing_interval = interval
        period_end = stripe_subscription.get("current_period_end")
        if period_end:
            subscription.current_period_end = datetime.fromtimestamp(period_end, tz=UTC)

    def _find_or_create_subscription(self, *, user_id: str | None, provider_subscription_id: str | None) -> Subscription:
        subscription = None
        if provider_subscription_id:
            subscription = (
                self.db.query(Subscription)
                .filter(Subscription.provider_subscription_id == provider_subscription_id)
                .one_or_none()
            )
        if not subscription and user_id:
            subscription = (
                self.db.query(Subscription)
                .filter(Subscription.user_id == user_id, Subscription.provider == "stripe")
                .order_by(Subscription.created_at.desc())
                .first()
            )
            if (
                subscription
                and provider_subscription_id
                and subscription.provider_subscription_id
                and subscription.provider_subscription_id != provider_subscription_id
            ):
                subscription = None
        if subscription:
            if provider_subscription_id and not subscription.provider_subscription_id:
                subscription.provider_subscription_id = provider_subscription_id
            return subscription
        if not user_id:
            raise StripeWebhookError("Webhook subscription event did not include a user_id.")
        subscription = Subscription(
            user_id=user_id,
            provider="stripe",
            provider_subscription_id=provider_subscription_id,
            tier="premium_plus",
            status="incomplete",
        )
        self.db.add(subscription)
        self.db.flush()
        return subscription

    def _stripe_headers(self, *, stripe_version: str | None = None) -> dict[str, str]:
        headers = {"Authorization": f"Bearer {self.settings.stripe_secret_key}"}
        if stripe_version:
            headers["Stripe-Version"] = stripe_version
        return headers

    def _stripe_post(
        self,
        path: str,
        *,
        data: dict[str, Any],
        stripe_version: str | None = None,
    ) -> dict[str, Any]:
        try:
            response = httpx.post(
                f"https://api.stripe.com{path}",
                data=data,
                headers=self._stripe_headers(stripe_version=stripe_version),
                timeout=15,
            )
        except httpx.HTTPError as exc:
            raise StripeBillingError(f"Stripe request failed: {exc}") from exc

        if response.status_code >= 400:
            message = response.text
            try:
                message = response.json().get("error", {}).get("message", message)
            except ValueError:
                pass
            raise StripeBillingError(f"Stripe API error: {message}")
        return response.json()

    def _stripe_get(self, path: str, *, params: dict[str, Any] | None = None) -> dict[str, Any]:
        try:
            response = httpx.get(
                f"https://api.stripe.com{path}",
                params=params,
                headers=self._stripe_headers(),
                timeout=15,
            )
        except httpx.HTTPError as exc:
            raise StripeBillingError(f"Stripe request failed: {exc}") from exc

        if response.status_code >= 400:
            message = response.text
            try:
                message = response.json().get("error", {}).get("message", message)
            except ValueError:
                pass
            raise StripeBillingError(f"Stripe API error: {message}")
        return response.json()

    def _stripe_delete(self, path: str) -> dict[str, Any]:
        try:
            response = httpx.delete(
                f"https://api.stripe.com{path}",
                headers=self._stripe_headers(),
                timeout=15,
            )
        except httpx.HTTPError as exc:
            raise StripeBillingError(f"Stripe request failed: {exc}") from exc

        if response.status_code >= 400:
            message = response.text
            try:
                message = response.json().get("error", {}).get("message", message)
            except ValueError:
                pass
            raise StripeBillingError(f"Stripe API error: {message}")
        return response.json()
