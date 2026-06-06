from __future__ import annotations

import hashlib
import hmac
import json
import logging
from datetime import UTC, datetime
from typing import Any

logger = logging.getLogger(__name__)

import httpx
from sqlalchemy.orm import Session

from phora.core.config import Settings
from phora.models import Invoice, Subscription, User
from phora.services.billing_catalog import resolve_stripe_price, stripe_price_metadata


class StripeBillingError(ValueError):
    pass


class StripeWebhookError(ValueError):
    pass


def _format_price(amount_minor: int, currency: str) -> str:
    symbol = {"GBP": "£", "USD": "$", "EUR": "€"}.get(currency.upper(), "")
    return f"{symbol}{amount_minor / 100:.2f}"


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
            "metadata[pricing_tier]": price_details["pricing_tier"],
            "metadata[pricing_strategy]": price_details["pricing_strategy"],
            "metadata[fallback_applied]": str(price_details["fallback_applied"]).lower(),
            "subscription_data[metadata][user_id]": user.id,
            "subscription_data[metadata][plan_id]": plan_id,
            "subscription_data[metadata][interval]": interval,
            "subscription_data[metadata][country]": price_details["country"],
            "subscription_data[metadata][pricing_tier]": price_details["pricing_tier"],
            "subscription_data[metadata][pricing_strategy]": price_details["pricing_strategy"],
            "subscription_data[metadata][fallback_applied]": str(price_details["fallback_applied"]).lower(),
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
        wearable_sku: str | None = None,
        wearable_price_minor: int = 0,
        shipping_address: dict | None = None,
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
        else:
            # Cancel any incomplete subscriptions on this customer before creating a new one.
            # Incomplete subscriptions lock in the customer's currency and block new subscriptions
            # in a different currency ("You cannot combine currencies on a single customer").
            self._cancel_incomplete_subscriptions(customer_id, price_details["currency"])

        # If wearable add-on requested, create an invoice item on the customer
        # so it is included in the first subscription invoice (Stripe billing add-on pattern).
        if wearable_sku and wearable_price_minor > 0:
            self._stripe_post(
                "/v1/invoiceitems",
                data={
                    "customer": customer_id,
                    "amount": str(wearable_price_minor),
                    "currency": price_details["currency"],
                    "description": "Vyla Wearable (one-time)",
                    "metadata[wearable_sku]": wearable_sku,
                    "metadata[user_id]": user.id,
                },
            )

        subscription_payload = {
            "customer": customer_id,
            "items[0][price]": str(price_details["provider_price_id"]),
            "payment_behavior": "default_incomplete",
            "payment_settings[save_default_payment_method]": "on_subscription",
            "expand[0]": "latest_invoice.payment_intent",
            "metadata[user_id]": user.id,
            "metadata[account_mode]": user.account_mode,
            "metadata[plan_id]": plan_id,
            "metadata[interval]": interval,
            "metadata[country]": str(price_details["country"]),
            "metadata[pricing_tier]": str(price_details["pricing_tier"]),
            "metadata[pricing_strategy]": str(price_details["pricing_strategy"]),
            "metadata[fallback_applied]": str(price_details["fallback_applied"]).lower(),
        }
        if wearable_sku:
            subscription_payload["metadata[wearable_sku]"] = wearable_sku
            if shipping_address:
                import json as _json
                subscription_payload["metadata[shipping_address]"] = _json.dumps(shipping_address)[:500]

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
            "provider_payment_intent_id": payment_intent.get("id"),
        }

    def create_payment_sheet_wearable_purchase(
        self,
        *,
        user_id: str,
        wearable_sku: str,
        wearable_price_minor: int,
        currency: str,
        shipping_address: dict | None = None,
    ) -> dict[str, Any]:
        if not self.settings.stripe_secret_key:
            raise StripeBillingError("Stripe secret key is not configured.")
        if not self.settings.stripe_publishable_key:
            raise StripeBillingError("Stripe publishable key is not configured.")
        if wearable_price_minor <= 0:
            raise StripeBillingError("Wearable price is unavailable.")

        user = self.db.query(User).filter(User.id == user_id).one_or_none()
        if not user or not user.email:
            raise StripeBillingError("A verified email is required before starting Stripe checkout.")

        customer_payload = {
            "email": user.email,
            "metadata[user_id]": user.id,
        }
        if user.profile and user.profile.full_name:
            customer_payload["name"] = user.profile.full_name
        customer = self._stripe_post("/v1/customers", data=customer_payload)
        customer_id = customer["id"]

        import json as _json
        metadata = {
            "user_id": user.id,
            "wearable_sku": wearable_sku,
            "checkout_type": "wearable_only",
        }
        if shipping_address:
            metadata["shipping_address"] = _json.dumps(shipping_address)[:500]

        payment_intent = self._stripe_post(
            "/v1/payment_intents",
            data={
                "amount": str(wearable_price_minor),
                "currency": currency.lower(),
                "customer": customer_id,
                "automatic_payment_methods[enabled]": "true",
                **{f"metadata[{key}]": value for key, value in metadata.items()},
            },
        )
        payment_intent_client_secret = payment_intent.get("client_secret")
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

        return {
            "payment_intent_client_secret": payment_intent_client_secret,
            "customer_id": customer_id,
            "customer_ephemeral_key_secret": ephemeral_key_secret,
            "publishable_key": self.settings.stripe_publishable_key,
            "customer_email": user.email,
            "provider_subscription_id": "",
            "provider_product_id": "",
            "provider_price_id": "",
            "plan_id": "wearable_only",
            "interval": "one_time",
            "currency": currency.upper(),
            "amount_minor": wearable_price_minor,
            "display_price": _format_price(wearable_price_minor, currency),
            "provider_payment_intent_id": payment_intent.get("id"),
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
        elif event_type == "payment_intent.succeeded":
            self._handle_payment_intent_succeeded(data_object)

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
            subscription.cancel_at_period_end = bool(response.get("cancel_at_period_end")) and not immediate
            period_end = response.get("current_period_end")
            if immediate:
                subscription.current_period_end = None
            elif period_end:
                subscription.current_period_end = datetime.fromtimestamp(period_end, tz=UTC)
        else:
            subscription.status = "canceled"
            subscription.cancel_at_period_end = False
        subscription.pending_billing_interval = None
        subscription.pending_provider_price_id = None
        subscription.pending_amount = None
        subscription.pending_currency = None
        subscription.pending_change_effective_at = None

    def restart_subscription(self, subscription: Subscription) -> None:
        if subscription.provider != "stripe":
            raise StripeBillingError("Subscription is not managed by Stripe.")
        if not self.settings.stripe_secret_key:
            raise StripeBillingError("Stripe secret key is not configured.")
        if not subscription.provider_subscription_id:
            raise StripeBillingError("Stripe subscription id is missing.")
        response = self._stripe_post(
            f"/v1/subscriptions/{subscription.provider_subscription_id}",
            data={"cancel_at_period_end": "false"},
        )
        subscription.status = response.get("status") or subscription.status
        subscription.cancel_at_period_end = bool(response.get("cancel_at_period_end"))
        period_end = response.get("current_period_end")
        if period_end:
            subscription.current_period_end = datetime.fromtimestamp(period_end, tz=UTC)

    def change_subscription_interval(
        self,
        subscription: Subscription,
        *,
        country: str,
        interval: str,
    ) -> None:
        if subscription.provider != "stripe":
            raise StripeBillingError("Subscription is not managed by Stripe.")
        if not self.settings.stripe_secret_key:
            raise StripeBillingError("Stripe secret key is not configured.")
        if not subscription.provider_subscription_id:
            raise StripeBillingError("Stripe subscription id is missing.")
        if interval not in {"month", "year"}:
            raise StripeBillingError("interval must be month or year")
        if subscription.billing_interval == interval:
            return

        price_details = resolve_stripe_price(
            country=country,
            plan_id="premium_plus",
            interval=interval,
        )
        stripe_subscription = self._stripe_get(
            f"/v1/subscriptions/{subscription.provider_subscription_id}",
            params={"expand[]": "items.data.price"},
        )
        items = ((stripe_subscription.get("items") or {}).get("data")) or []
        if not items:
            raise StripeBillingError("Stripe subscription has no billable items.")
        current_item = items[0]
        current_price = (current_item.get("price") or {}).get("id") or subscription.provider_price_id
        if not current_price:
            raise StripeBillingError("Current Stripe subscription price id is missing.")
        quantity = int(current_item.get("quantity") or 1)
        period_start = stripe_subscription.get("current_period_start")
        period_end = stripe_subscription.get("current_period_end")
        if not period_end:
            raise StripeBillingError("Stripe subscription period end is missing.")

        self._schedule_interval_change(
            stripe_subscription=stripe_subscription,
            current_price_id=str(current_price),
            current_interval=subscription.billing_interval or "month",
            target_price_id=str(price_details["provider_price_id"]),
            target_interval=interval,
            quantity=quantity,
            current_period_start=period_start,
            current_period_end=period_end,
            country=str(price_details["country"]),
        )
        subscription.current_period_end = datetime.fromtimestamp(period_end, tz=UTC)
        subscription.cancel_at_period_end = False
        subscription.pending_billing_interval = interval
        subscription.pending_provider_price_id = str(price_details["provider_price_id"])
        subscription.pending_currency = str(price_details["currency"])
        subscription.pending_amount = float(price_details["price_minor"]) / 100
        subscription.pending_change_effective_at = subscription.current_period_end

    def cancel_scheduled_interval_change(self, subscription: Subscription) -> None:
        if subscription.provider != "stripe":
            raise StripeBillingError("Subscription is not managed by Stripe.")
        if not self.settings.stripe_secret_key:
            raise StripeBillingError("Stripe secret key is not configured.")
        if not subscription.provider_subscription_id:
            raise StripeBillingError("Stripe subscription id is missing.")
        if not subscription.pending_billing_interval:
            raise StripeBillingError("No scheduled plan change to cancel.")
        if not subscription.provider_price_id:
            raise StripeBillingError("Current subscription price id is missing.")

        stripe_subscription = self._stripe_get(
            f"/v1/subscriptions/{subscription.provider_subscription_id}",
            params={"expand[]": "schedule"},
        )
        schedule_id = self._subscription_schedule_id(stripe_subscription)
        if schedule_id:
            self._stripe_post(
                f"/v1/subscription_schedules/{schedule_id}/release",
                data={},
            )
        subscription.status = stripe_subscription.get("status") or subscription.status
        subscription.cancel_at_period_end = bool(stripe_subscription.get("cancel_at_period_end"))
        period_end = stripe_subscription.get("current_period_end")
        if period_end:
            subscription.current_period_end = datetime.fromtimestamp(period_end, tz=UTC)
        subscription.pending_billing_interval = None
        subscription.pending_provider_price_id = None
        subscription.pending_amount = None
        subscription.pending_currency = None
        subscription.pending_change_effective_at = None

    def _schedule_interval_change(
        self,
        *,
        stripe_subscription: dict[str, Any],
        current_price_id: str,
        current_interval: str,
        target_price_id: str,
        target_interval: str,
        quantity: int,
        current_period_start: int | None,
        current_period_end: int,
        country: str,
    ) -> None:
        subscription_id = stripe_subscription.get("id")
        if not subscription_id:
            raise StripeBillingError("Stripe subscription id is missing.")

        schedule_id = self._subscription_schedule_id(stripe_subscription)
        if schedule_id:
            schedule = self._stripe_get(f"/v1/subscription_schedules/{schedule_id}")
        else:
            schedule = self._stripe_post(
                "/v1/subscription_schedules",
                data={"from_subscription": subscription_id},
            )
            schedule_id = str(schedule["id"])

        current_phase = schedule.get("current_phase") or {}
        phase_start = current_phase.get("start_date") or current_period_start
        if not phase_start:
            raise StripeBillingError("Stripe subscription period start is missing.")

        self._stripe_post(
            f"/v1/subscription_schedules/{schedule_id}",
            data={
                "end_behavior": "release",
                "proration_behavior": "none",
                "phases[0][start_date]": str(phase_start),
                "phases[0][end_date]": str(current_period_end),
                "phases[0][items][0][price]": current_price_id,
                "phases[0][items][0][quantity]": str(quantity),
                "phases[0][metadata][plan_id]": "premium_plus",
                "phases[0][metadata][interval]": current_interval,
                "phases[0][metadata][country]": country,
                "phases[1][items][0][price]": target_price_id,
                "phases[1][items][0][quantity]": str(quantity),
                "phases[1][iterations]": "1",
                "phases[1][metadata][plan_id]": "premium_plus",
                "phases[1][metadata][interval]": target_interval,
                "phases[1][metadata][country]": country,
            },
        )

    def _subscription_schedule_id(self, stripe_subscription: dict[str, Any]) -> str | None:
        schedule = stripe_subscription.get("schedule")
        if isinstance(schedule, dict):
            return schedule.get("id")
        if isinstance(schedule, str) and schedule:
            return schedule
        return None

    def _pending_change_is_active(self, subscription: Subscription) -> bool:
        effective = subscription.pending_change_effective_at
        if effective and effective.tzinfo is None:
            effective = effective.replace(tzinfo=UTC)
        return bool(
            subscription.pending_billing_interval
            and effective
            and effective > datetime.now(UTC)
        )

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
        subscription.status = stripe_subscription.get("status") or subscription.status
        subscription.cancel_at_period_end = bool(stripe_subscription.get("cancel_at_period_end"))
        period_end = stripe_subscription.get("current_period_end")
        if period_end:
            subscription.current_period_end = datetime.fromtimestamp(period_end, tz=UTC)

        pending_is_active = self._pending_change_is_active(subscription)
        if not pending_is_active:
            subscription.provider_price_id = price_id
            subscription.currency = (stripe_subscription.get("currency") or price.get("currency") or subscription.currency or "").upper() or None
            subscription.billing_interval = ((price.get("recurring") or {}).get("interval")) or metadata.get("interval") or subscription.billing_interval
            unit_amount = price.get("unit_amount")
            if unit_amount is not None:
                subscription.amount = float(unit_amount) / 100
            subscription.pending_billing_interval = None
            subscription.pending_provider_price_id = None
            subscription.pending_amount = None
            subscription.pending_currency = None
            subscription.pending_change_effective_at = None
        if derived_metadata:
            subscription.tier = derived_metadata["plan_id"]
            if not pending_is_active:
                subscription.billing_interval = subscription.billing_interval or derived_metadata["interval"]
        elif metadata.get("plan_id"):
            subscription.tier = metadata["plan_id"]

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
            if metadata.get("plan_id"):
                subscription.tier = metadata["plan_id"]
            period_end = self._invoice_period_end(stripe_invoice)
            if period_end:
                subscription.current_period_end = datetime.fromtimestamp(period_end, tz=UTC)
            if not self._pending_change_is_active(subscription):
                if price.get("id"):
                    subscription.provider_price_id = price["id"]
                subscription.currency = (stripe_invoice.get("currency") or price.get("currency") or subscription.currency or "").upper() or None
                subscription.billing_interval = ((price.get("recurring") or {}).get("interval")) or metadata.get("interval") or subscription.billing_interval
                unit_amount = price.get("unit_amount")
                if unit_amount is not None:
                    subscription.amount = float(unit_amount) / 100
                subscription.pending_billing_interval = None
                subscription.pending_provider_price_id = None
                subscription.pending_amount = None
                subscription.pending_currency = None
                subscription.pending_change_effective_at = None

        if subscription and stripe_invoice.get("status") == "paid":
            subscription.status = "active"
            # Auto-create wearable order if this subscription has a wearable add-on.
            wearable_sku = metadata.get("wearable_sku")
            if wearable_sku and subscription.user_id:
                self._create_wearable_order_if_absent(
                    user_id=subscription.user_id,
                    subscription_id=subscription.id,
                    wearable_sku=wearable_sku,
                    payment_intent_id=stripe_invoice.get("payment_intent"),
                    shipping_address_json=self._parse_shipping_address(metadata),
                )
        elif subscription and stripe_invoice.get("status") in {"open", "uncollectible"}:
            subscription.status = "payment_failed"

    def _handle_payment_intent_succeeded(self, payment_intent: dict[str, Any]) -> None:
        metadata = payment_intent.get("metadata") or {}
        if metadata.get("checkout_type") != "wearable_only":
            return
        user_id = metadata.get("user_id")
        wearable_sku = metadata.get("wearable_sku")
        if not user_id or not wearable_sku:
            return
        self._create_wearable_order_if_absent(
            user_id=user_id,
            subscription_id=None,
            wearable_sku=wearable_sku,
            payment_intent_id=payment_intent.get("id"),
            shipping_address_json=self._parse_shipping_address(metadata),
        )

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

    def confirm_wearable_payment(
        self,
        *,
        user_id: str,
        payment_intent_id: str,
        wearable_sku: str,
        shipping_address_json: dict,
        provider_subscription_id: str | None = None,
    ) -> None:
        if not self.settings.stripe_secret_key:
            raise StripeBillingError("Stripe secret key is not configured.")
        if not payment_intent_id:
            raise StripeBillingError("Missing Stripe payment intent.")
        if not wearable_sku:
            raise StripeBillingError("Missing wearable SKU.")

        payment_intent = self._stripe_get(f"/v1/payment_intents/{payment_intent_id}")
        if payment_intent.get("status") != "succeeded":
            raise StripeBillingError("Wearable payment has not succeeded yet.")

        metadata = payment_intent.get("metadata") or {}
        metadata_user_id = metadata.get("user_id")
        if metadata_user_id and metadata_user_id != user_id:
            raise StripeBillingError("Payment intent does not belong to this user.")

        subscription_id = None
        if provider_subscription_id:
            subscription = (
                self.db.query(Subscription)
                .filter(
                    Subscription.provider_subscription_id == provider_subscription_id,
                    Subscription.user_id == user_id,
                )
                .one_or_none()
            )
            if not subscription:
                raise StripeBillingError("Subscription does not belong to this user.")
            subscription_id = subscription.id
        elif not metadata_user_id:
            raise StripeBillingError("Payment intent ownership could not be verified.")

        self._create_wearable_order_if_absent(
            user_id=user_id,
            subscription_id=subscription_id,
            wearable_sku=wearable_sku,
            payment_intent_id=payment_intent_id,
            shipping_address_json=shipping_address_json,
            suppress_errors=False,
        )

    def _invoice_metadata(self, stripe_invoice: dict[str, Any]) -> dict[str, str]:
        sources = [
            stripe_invoice,
            stripe_invoice.get("subscription_details") or {},
            ((stripe_invoice.get("parent") or {}).get("subscription_details") or {}),
        ]
        lines = ((stripe_invoice.get("lines") or {}).get("data")) or []
        sources.extend(lines)

        merged: dict[str, str] = {}
        for source in sources:
            metadata = source.get("metadata") or {}
            if metadata:
                merged.update({key: value for key, value in metadata.items() if value not in (None, "")})
        return merged

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

    def _cancel_incomplete_subscriptions(self, customer_id: str, target_currency: str) -> None:
        """Cancel incomplete Stripe subscriptions so they don't block a new currency subscription."""
        try:
            existing = self._stripe_get("/v1/subscriptions", params={"customer": customer_id, "status": "incomplete"})
            for sub in existing.get("data", []):
                sub_currency = (sub.get("currency") or "").upper()
                if sub_currency and sub_currency != target_currency.upper():
                    try:
                        self._stripe_delete(f"/v1/subscriptions/{sub['id']}")
                    except Exception:
                        pass
        except Exception:
            pass

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
        subscription.cancel_at_period_end = bool(stripe_subscription.get("cancel_at_period_end"))
        subscription.currency = str(price_details["currency"])
        subscription.amount = float(price_details["price_minor"]) / 100
        subscription.billing_interval = interval
        subscription.pending_billing_interval = None
        subscription.pending_provider_price_id = None
        subscription.pending_amount = None
        subscription.pending_currency = None
        subscription.pending_change_effective_at = None
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

    # ── Wearable commerce helpers ──────────────────────────────────────────────

    def _create_wearable_order_if_absent(
        self,
        *,
        user_id: str,
        subscription_id: str | None,
        wearable_sku: str,
        payment_intent_id: str | None,
        shipping_address_json: dict,
        suppress_errors: bool = True,
    ) -> None:
        from phora.models.wearable_commerce import WearableOrder
        from phora.services.wearable_commerce import WearableCommerceService
        existing = (
            self.db.query(WearableOrder)
            .filter(
                WearableOrder.user_id == user_id,
                WearableOrder.provider_payment_intent_id == payment_intent_id,
            )
            .one_or_none()
        ) if payment_intent_id else None
        if existing:
            return
        try:
            svc = WearableCommerceService(self.db)
            svc.create_order(
                user_id=user_id,
                subscription_id=subscription_id,
                sku=wearable_sku,
                shipping_address=shipping_address_json,
                payment_intent_id=payment_intent_id,
            )
        except Exception:
            logger.exception("Failed to auto-create wearable order for user %s", user_id)
            if not suppress_errors:
                raise

    @staticmethod
    def _parse_shipping_address(metadata: dict) -> dict:
        import json as _json
        raw = metadata.get("shipping_address", "")
        if not raw:
            return {}
        try:
            return _json.loads(raw)
        except Exception:
            return {}
