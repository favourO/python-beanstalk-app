from __future__ import annotations

import base64
import hashlib
import hmac
import json
from datetime import UTC, datetime, timedelta
from typing import Any
from uuid import uuid4

import httpx
from sqlalchemy.orm import Session

from phora.core.config import Settings
from phora.models import Invoice, Subscription, User
from phora.services.billing_catalog import resolve_billing_price


class FlutterwaveBillingError(ValueError):
    pass


class FlutterwaveWebhookError(ValueError):
    pass


class FlutterwaveBillingService:
    _RECURRING_INTERVALS = {
        "month": "monthly",
        "year": "yearly",
    }

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
        redirect_url: str | None,
    ) -> dict[str, Any]:
        if not self.settings.flutterwave_secret_key:
            raise FlutterwaveBillingError("Flutterwave secret key is not configured.")

        user = self.db.query(User).filter(User.id == user_id).one_or_none()
        if not user or not user.email:
            raise FlutterwaveBillingError("A verified email is required before starting Flutterwave checkout.")

        try:
            price_details = resolve_billing_price(country=country, plan_id=plan_id, interval=interval)
        except ValueError as exc:
            raise FlutterwaveBillingError(str(exc)) from exc

        if price_details["provider"] != "flutterwave":
            raise FlutterwaveBillingError(f"Flutterwave billing is not available for {price_details['country']}.")

        final_redirect_url = redirect_url or self.settings.flutterwave_redirect_url
        if not final_redirect_url:
            raise FlutterwaveBillingError("redirect_url is required for Flutterwave checkout.")

        payment_plan_id = self._ensure_payment_plan(
            country=str(price_details["country"]),
            currency=str(price_details["currency"]),
            interval=interval,
            amount=float(price_details["price_minor"]) / 100,
        )
        tx_ref = f"phora-{user.id}-{plan_id}-{interval}-{uuid4().hex[:12]}"
        payload = {
            "tx_ref": tx_ref,
            "amount": str(float(price_details["price_minor"]) / 100),
            "currency": price_details["currency"],
            "redirect_url": final_redirect_url,
            # Flutterwave recurring billing requires the first charge to reference a payment plan.
            "payment_plan": payment_plan_id,
            "payment_options": "card",
            "customer": {
                "email": user.email,
                "name": user.profile.full_name if user.profile and user.profile.full_name else user.email,
            },
            "customizations": {
                "title": "Vyla Premium",
                "description": f"Premium {interval} plan for {price_details['country']}",
            },
            "meta": {
                "user_id": user.id,
                "plan_id": plan_id,
                "interval": interval,
                "country": price_details["country"],
            },
        }

        response = self._flutterwave_post("/v3/payments", json=payload)
        data = response.get("data") or {}
        checkout_url = data.get("link")
        if not checkout_url:
            raise FlutterwaveBillingError("Flutterwave response did not include a checkout link.")

        subscription = (
            self.db.query(Subscription)
            .filter(Subscription.user_id == user.id)
            .order_by(Subscription.created_at.desc())
            .first()
        )
        if subscription:
            subscription.provider = "flutterwave"
            subscription.provider_subscription_id = tx_ref
            subscription.provider_customer_id = user.email
            subscription.provider_price_id = str(payment_plan_id)
            subscription.status = "pending_checkout"
            subscription.current_period_end = None
            self.db.commit()

        return {
            "checkout_url": checkout_url,
            "tx_ref": tx_ref,
            "public_key": self.settings.flutterwave_public_key,
            "customer_email": user.email,
            "plan_id": plan_id,
            "interval": interval,
            "currency": price_details["currency"],
            "amount_minor": price_details["price_minor"],
            "display_price": price_details["display_price"],
        }

    def handle_webhook(
        self,
        *,
        payload: bytes,
        signature: str | None,
        legacy_hash: str | None,
    ) -> dict[str, str]:
        event = self._verify_event(payload=payload, signature=signature, legacy_hash=legacy_hash)
        event_type = event.get("event") or event.get("type") or ""
        data_object = event.get("data") or {}

        if event_type in {"charge.completed", "charge.failed"}:
            self._handle_charge_event(event_type=event_type, data_object=data_object)
        elif event_type == "subscription.cancelled":
            self._handle_subscription_cancelled(data_object)

        self.db.commit()
        return {"status": "ok"}

    def confirm_transaction(
        self,
        *,
        transaction_id: str | int,
        tx_ref: str | None = None,
        status: str | None = None,
    ) -> dict[str, Any]:
        event_type = "charge.completed"
        normalized_status = (status or "").strip().lower()
        if normalized_status in {"failed", "cancelled", "canceled"}:
            event_type = "charge.failed"

        data_object: dict[str, Any] = {"id": transaction_id}
        if tx_ref:
            data_object["tx_ref"] = tx_ref
        self._handle_charge_event(event_type=event_type, data_object=data_object)
        self.db.commit()
        return {"status": "ok"}

    def cancel_subscription(self, subscription: Subscription) -> None:
        if subscription.provider != "flutterwave":
            raise FlutterwaveBillingError("Subscription is not managed by Flutterwave.")
        if not self.settings.flutterwave_secret_key:
            raise FlutterwaveBillingError("Flutterwave secret key is not configured.")

        remote_subscription_id = self._resolve_remote_subscription_id(subscription)
        if remote_subscription_id:
            self._flutterwave_put(f"/v3/subscriptions/{remote_subscription_id}/cancel")

        subscription.status = "canceled"

    def _verify_event(
        self,
        *,
        payload: bytes,
        signature: str | None,
        legacy_hash: str | None,
    ) -> dict[str, Any]:
        secret_hash = self.settings.flutterwave_webhook_secret_hash or self.settings.flutterwave_secret_key
        if not secret_hash:
            raise FlutterwaveWebhookError("Flutterwave webhook secret is not configured.")

        if signature:
            digest = hmac.new(secret_hash.encode("utf-8"), payload, hashlib.sha256).digest()
            expected_hex = digest.hex()
            expected_base64 = base64.b64encode(digest).decode("utf-8")
            if not (
                hmac.compare_digest(expected_hex, signature)
                or hmac.compare_digest(expected_base64, signature)
                or hmac.compare_digest(secret_hash, signature)
            ):
                raise FlutterwaveWebhookError("Invalid Flutterwave webhook signature.")
        elif legacy_hash:
            if not hmac.compare_digest(secret_hash, legacy_hash):
                raise FlutterwaveWebhookError("Invalid Flutterwave verif-hash header.")
        else:
            raise FlutterwaveWebhookError("Missing Flutterwave webhook signature header.")

        try:
            return json.loads(payload)
        except json.JSONDecodeError as exc:
            raise FlutterwaveWebhookError("Flutterwave webhook payload was not valid JSON.") from exc

    def _handle_charge_event(self, *, event_type: str, data_object: dict[str, Any]) -> None:
        transaction_id = data_object.get("id")
        if transaction_id is None:
            raise FlutterwaveWebhookError("Flutterwave webhook payload did not include a transaction id.")

        verified = self._verify_transaction(transaction_id)
        verified_data = verified.get("data") or {}
        tx_ref = verified_data.get("tx_ref") or data_object.get("tx_ref") or data_object.get("reference")
        metadata = verified_data.get("meta") or data_object.get("meta") or {}
        user_id = metadata.get("user_id")
        customer = verified_data.get("customer") or data_object.get("customer") or {}
        provider_customer_id = customer.get("email") or customer.get("id")
        provider_plan_id = self._extract_plan_id(verified_data) or self._extract_plan_id(data_object)

        subscription = self._find_or_create_subscription(
            user_id=user_id,
            tx_ref=tx_ref,
            provider_customer_id=provider_customer_id,
            provider_plan_id=provider_plan_id,
        )
        subscription.provider = "flutterwave"
        if tx_ref and not subscription.provider_subscription_id:
            subscription.provider_subscription_id = tx_ref
        subscription.provider_customer_id = provider_customer_id or subscription.provider_customer_id
        subscription.provider_price_id = provider_plan_id or subscription.provider_price_id
        subscription.tier = metadata.get("plan_id") or subscription.tier or "premium_plus"
        subscription.billing_interval = metadata.get("interval") or subscription.billing_interval
        subscription.currency = (verified_data.get("currency") or subscription.currency or "").upper() or None
        amount = verified_data.get("charged_amount")
        if amount is None:
            amount = verified_data.get("amount")
        if amount is not None:
            subscription.amount = float(amount)
        subscription.status = self._map_flutterwave_status(
            verified_status=str(verified_data.get("status") or ""),
            event_type=event_type,
        )
        subscription.current_period_end = self._period_end_for_interval(subscription.billing_interval, subscription.status)

        provider_invoice_id = str(verified_data.get("id") or transaction_id)
        invoice = self.db.query(Invoice).filter(Invoice.provider_invoice_id == provider_invoice_id).one_or_none()
        if not invoice:
            invoice = Invoice(provider_invoice_id=provider_invoice_id)
            self.db.add(invoice)
        invoice.subscription_id = subscription.id
        invoice.provider_customer_id = customer.get("email") or customer.get("id")
        invoice.provider_payment_intent_id = verified_data.get("flw_ref") or tx_ref
        invoice.total = float(amount or 0)
        invoice.currency = subscription.currency or invoice.currency
        invoice.status = subscription.status

    def _handle_subscription_cancelled(self, data_object: dict[str, Any]) -> None:
        customer = data_object.get("customer") or {}
        provider_customer_id = customer.get("email") or customer.get("id")
        provider_plan_id = self._extract_plan_id(data_object)
        subscription = self._find_or_create_subscription(
            user_id=None,
            tx_ref=None,
            provider_customer_id=provider_customer_id,
            provider_plan_id=provider_plan_id,
            create_if_missing=False,
        )
        if not subscription:
            return
        subscription.provider = "flutterwave"
        subscription.provider_customer_id = provider_customer_id or subscription.provider_customer_id
        subscription.provider_price_id = provider_plan_id or subscription.provider_price_id
        subscription.status = "canceled"
        subscription.current_period_end = None

        plan = data_object.get("plan") or {}
        interval = self._normalize_plan_interval(plan.get("interval"))
        if interval:
            subscription.billing_interval = interval
        currency = data_object.get("currency")
        if currency:
            subscription.currency = str(currency).upper()
        amount = data_object.get("amount")
        if amount is not None:
            subscription.amount = float(amount)

    def _find_or_create_subscription(
        self,
        *,
        user_id: str | None,
        tx_ref: str | None,
        provider_customer_id: str | None = None,
        provider_plan_id: str | None = None,
        create_if_missing: bool = True,
    ) -> Subscription | None:
        subscription = None
        if tx_ref:
            subscription = (
                self.db.query(Subscription)
                .filter(Subscription.provider_subscription_id == tx_ref)
                .one_or_none()
            )
        if not subscription and user_id:
            subscription = (
                self.db.query(Subscription)
                .filter(Subscription.user_id == user_id, Subscription.provider == "flutterwave")
                .order_by(Subscription.created_at.desc())
                .first()
            )
        if not subscription and provider_customer_id and provider_plan_id:
            subscription = (
                self.db.query(Subscription)
                .filter(
                    Subscription.provider == "flutterwave",
                    Subscription.provider_customer_id == provider_customer_id,
                    Subscription.provider_price_id == provider_plan_id,
                )
                .order_by(Subscription.created_at.desc())
                .first()
            )
        if not subscription and provider_customer_id:
            subscription = (
                self.db.query(Subscription)
                .filter(
                    Subscription.provider == "flutterwave",
                    Subscription.provider_customer_id == provider_customer_id,
                )
                .order_by(Subscription.created_at.desc())
                .first()
            )
        if subscription:
            if tx_ref and not subscription.provider_subscription_id:
                subscription.provider_subscription_id = tx_ref
            if provider_customer_id and not subscription.provider_customer_id:
                subscription.provider_customer_id = provider_customer_id
            if provider_plan_id and not subscription.provider_price_id:
                subscription.provider_price_id = provider_plan_id
            return subscription
        if not user_id and provider_customer_id:
            user = self.db.query(User).filter(User.email == provider_customer_id).one_or_none()
            if user:
                user_id = user.id
        if not create_if_missing:
            return None
        if not user_id:
            raise FlutterwaveWebhookError("Flutterwave webhook transaction could not be matched to a user.")
        subscription = Subscription(
            user_id=user_id,
            provider="flutterwave",
            provider_subscription_id=tx_ref,
            provider_customer_id=provider_customer_id,
            provider_price_id=provider_plan_id,
            tier="premium_plus",
            status="pending_checkout",
        )
        self.db.add(subscription)
        self.db.flush()
        return subscription

    def _verify_transaction(self, transaction_id: str | int) -> dict[str, Any]:
        if not self.settings.flutterwave_secret_key:
            raise FlutterwaveWebhookError("Flutterwave secret key is not configured.")

        try:
            response = httpx.get(
                f"https://api.flutterwave.com/v3/transactions/{transaction_id}/verify",
                headers={"Authorization": f"Bearer {self.settings.flutterwave_secret_key}"},
                timeout=15,
            )
        except httpx.HTTPError as exc:
            raise FlutterwaveWebhookError(f"Flutterwave verification request failed: {exc}") from exc

        if response.status_code >= 400:
            message = response.text
            try:
                payload = response.json()
                message = payload.get("message") or payload.get("error") or message
            except ValueError:
                pass
            raise FlutterwaveWebhookError(f"Flutterwave verification failed: {message}")

        try:
            payload = response.json()
        except ValueError as exc:
            raise FlutterwaveWebhookError("Flutterwave verification returned a non-JSON response.") from exc

        if payload.get("status") != "success":
            raise FlutterwaveWebhookError(payload.get("message") or "Flutterwave verification failed.")
        return payload

    def _map_flutterwave_status(self, *, verified_status: str, event_type: str) -> str:
        normalized = verified_status.lower()
        if normalized in {"successful", "success", "completed"}:
            return "active"
        if normalized in {"failed", "cancelled", "canceled"} or event_type == "charge.failed":
            return "failed"
        if normalized in {"pending"}:
            return "pending_checkout"
        return normalized or "pending_checkout"

    def _period_end_for_interval(self, interval: str | None, status: str) -> datetime | None:
        if status != "active":
            return None
        now = datetime.now(UTC)
        if interval == "year":
            return now + timedelta(days=365)
        if interval == "month":
            return now + timedelta(days=30)
        return None

    def _payment_options_for_currency(self, currency: str) -> str:
        currency = currency.upper()
        if currency == "NGN":
            return "card,banktransfer,ussd"
        if currency in {"GHS", "KES", "UGX", "TZS", "RWF", "MWK", "ZMW", "XAF", "XOF"}:
            return "card,mobilemoney,banktransfer"
        if currency == "ZAR":
            return "card,banktransfer"
        return "card,banktransfer,mobilemoney"

    def _flutterwave_post(self, path: str, *, json: dict[str, Any]) -> dict[str, Any]:
        try:
            response = httpx.post(
                f"https://api.flutterwave.com{path}",
                json=json,
                headers={
                    "Authorization": f"Bearer {self.settings.flutterwave_secret_key}",
                    "Content-Type": "application/json",
                },
                timeout=15,
            )
        except httpx.HTTPError as exc:
            raise FlutterwaveBillingError(f"Flutterwave request failed: {exc}") from exc

        if response.status_code >= 400:
            message = response.text
            try:
                payload = response.json()
                message = payload.get("message") or payload.get("error") or message
            except ValueError:
                pass
            raise FlutterwaveBillingError(f"Flutterwave checkout failed: {message}")

        try:
            payload = response.json()
        except ValueError as exc:
            raise FlutterwaveBillingError("Flutterwave returned a non-JSON response.") from exc

        if payload.get("status") != "success":
            raise FlutterwaveBillingError(payload.get("message") or "Flutterwave checkout failed.")
        return payload

    def _flutterwave_put(self, path: str, *, json: dict[str, Any] | None = None) -> dict[str, Any]:
        try:
            response = httpx.put(
                f"https://api.flutterwave.com{path}",
                json=json or {},
                headers={
                    "Authorization": f"Bearer {self.settings.flutterwave_secret_key}",
                    "Content-Type": "application/json",
                },
                timeout=15,
            )
        except httpx.HTTPError as exc:
            raise FlutterwaveBillingError(f"Flutterwave request failed: {exc}") from exc

        if response.status_code >= 400:
            message = response.text
            try:
                payload = response.json()
                message = payload.get("message") or payload.get("error") or message
            except ValueError:
                pass
            raise FlutterwaveBillingError(f"Flutterwave request failed: {message}")

        try:
            payload = response.json()
        except ValueError as exc:
            raise FlutterwaveBillingError("Flutterwave returned a non-JSON response.") from exc

        if payload.get("status") != "success":
            raise FlutterwaveBillingError(payload.get("message") or "Flutterwave request failed.")
        return payload

    def _flutterwave_get(self, path: str, *, params: dict[str, Any] | None = None) -> dict[str, Any]:
        try:
            response = httpx.get(
                f"https://api.flutterwave.com{path}",
                params=params,
                headers={"Authorization": f"Bearer {self.settings.flutterwave_secret_key}"},
                timeout=15,
            )
        except httpx.HTTPError as exc:
            raise FlutterwaveBillingError(f"Flutterwave request failed: {exc}") from exc

        if response.status_code >= 400:
            message = response.text
            try:
                payload = response.json()
                message = payload.get("message") or payload.get("error") or message
            except ValueError:
                pass
            raise FlutterwaveBillingError(f"Flutterwave request failed: {message}")

        try:
            payload = response.json()
        except ValueError as exc:
            raise FlutterwaveBillingError("Flutterwave returned a non-JSON response.") from exc

        if payload.get("status") != "success":
            raise FlutterwaveBillingError(payload.get("message") or "Flutterwave request failed.")
        return payload

    def _ensure_payment_plan(
        self,
        *,
        country: str,
        currency: str,
        interval: str,
        amount: float,
    ) -> int:
        flutterwave_interval = self._flutterwave_plan_interval(interval)
        plan_name = self._payment_plan_name(country=country, currency=currency, interval=interval)
        existing_plan = self._find_payment_plan(
            name=plan_name,
            currency=currency,
            interval=flutterwave_interval,
            amount=amount,
        )
        if existing_plan:
            return int(existing_plan["id"])

        response = self._flutterwave_post(
            "/v3/payment-plans",
            json={
                "name": plan_name,
                "interval": flutterwave_interval,
                "currency": currency,
                "amount": amount,
            },
        )
        data = response.get("data") or {}
        plan_id = data.get("id")
        if plan_id is None:
            raise FlutterwaveBillingError("Flutterwave response did not include a payment plan id.")
        return int(plan_id)

    def _find_payment_plan(
        self,
        *,
        name: str,
        currency: str,
        interval: str,
        amount: float,
    ) -> dict[str, Any] | None:
        page = 1
        while True:
            response = self._flutterwave_get("/v3/payment-plans", params={"page": page})
            plans = response.get("data") or []
            if not isinstance(plans, list) or not plans:
                return None
            for plan in plans:
                if (
                    plan.get("name") == name
                    and str(plan.get("currency") or "").upper() == currency.upper()
                    and str(plan.get("interval") or "").lower() == interval.lower()
                    and float(plan.get("amount") or 0) == amount
                    and str(plan.get("status") or "").lower() == "active"
                ):
                    return plan
            page += 1

    def _flutterwave_get(self, path: str, *, params: dict[str, Any]) -> dict[str, Any]:
        try:
            response = httpx.get(
                f"https://api.flutterwave.com{path}",
                params=params,
                headers={"Authorization": f"Bearer {self.settings.flutterwave_secret_key}"},
                timeout=15,
            )
        except httpx.HTTPError as exc:
            raise FlutterwaveBillingError(f"Flutterwave request failed: {exc}") from exc

        if response.status_code >= 400:
            message = response.text
            try:
                payload = response.json()
                message = payload.get("message") or payload.get("error") or message
            except ValueError:
                pass
            raise FlutterwaveBillingError(f"Flutterwave request failed: {message}")

        try:
            payload = response.json()
        except ValueError as exc:
            raise FlutterwaveBillingError("Flutterwave returned a non-JSON response.") from exc

        if payload.get("status") != "success":
            raise FlutterwaveBillingError(payload.get("message") or "Flutterwave request failed.")
        return payload

    def _payment_plan_name(self, *, country: str, currency: str, interval: str) -> str:
        return f"Vyla Premium {country} {currency.upper()} {interval}"

    def _flutterwave_plan_interval(self, interval: str) -> str:
        try:
            return self._RECURRING_INTERVALS[interval]
        except KeyError as exc:
            raise FlutterwaveBillingError(f"Unsupported Flutterwave billing interval: {interval}") from exc

    def _normalize_plan_interval(self, interval: str | None) -> str | None:
        if not interval:
            return None
        normalized = str(interval).lower()
        if normalized == "monthly":
            return "month"
        if normalized == "yearly":
            return "year"
        return None

    def _resolve_remote_subscription_id(self, subscription: Subscription) -> str | None:
        provider_subscription_id = subscription.provider_subscription_id or ""
        if provider_subscription_id.isdigit():
            return provider_subscription_id
        if not subscription.provider_customer_id or not subscription.provider_price_id:
            return None

        response = self._flutterwave_get(
            "/v3/subscriptions",
            params={
                "email": subscription.provider_customer_id,
                "plan": subscription.provider_price_id,
                "status": "active",
                "page": 1,
            },
        )
        for item in response.get("data") or []:
            remote_id = item.get("id")
            if remote_id is not None:
                return str(remote_id)
        return None

    def _extract_plan_id(self, payload: dict[str, Any]) -> str | None:
        plan = payload.get("plan")
        if isinstance(plan, dict) and plan.get("id") is not None:
            return str(plan["id"])
        if plan is not None and not isinstance(plan, dict):
            return str(plan)
        payment_plan = payload.get("payment_plan")
        if payment_plan is not None:
            return str(payment_plan)
        meta = payload.get("meta") or {}
        if meta.get("payment_plan") is not None:
            return str(meta["payment_plan"])
        return None
