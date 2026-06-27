"""
Apple In-App Purchase receipt verification via Apple's verifyReceipt API.
Tries production first; retries with sandbox on status 21007.
"""
import logging
from datetime import UTC, datetime

import httpx

_log = logging.getLogger(__name__)

_VERIFY_PROD = "https://buy.itunes.apple.com/verifyReceipt"
_VERIFY_SANDBOX = "https://sandbox.itunes.apple.com/verifyReceipt"

APPLE_PRODUCT_INTERVAL: dict[str, str] = {
    "com.vyla.health.premium.monthly": "month",
    "com.vyla.health.premium.annual": "year",
}


class AppleBillingError(Exception):
    pass


class AppleBillingService:
    def __init__(self, shared_secret: str | None, bundle_id: str = "com.vyla.health"):
        self._secret = shared_secret
        self._bundle_id = bundle_id

    def verify_receipt(self, receipt_data: str, product_id: str) -> dict:
        """
        Verify an Apple receipt and return parsed subscription info.

        Returns a dict with keys:
          product_id, transaction_id, original_transaction_id,
          purchase_date, expires_date, is_trial_period
        """
        if not self._secret:
            raise AppleBillingError(
                "Apple IAP shared secret is not configured. "
                "Set PHORA_APPLE_IAP_SHARED_SECRET in your environment."
            )

        payload = {
            "receipt-data": receipt_data,
            "password": self._secret,
            "exclude-old-transactions": True,
        }

        result = self._post(url=_VERIFY_PROD, payload=payload)

        # Status 21007 means a sandbox receipt was sent to production — retry.
        if result.get("status") == 21007:
            _log.info("Apple receipt is a sandbox receipt; retrying with sandbox URL")
            result = self._post(url=_VERIFY_SANDBOX, payload=payload)

        status = result.get("status", -1)
        if status != 0:
            raise AppleBillingError(
                f"Apple receipt validation failed (status={status}). "
                "The receipt may be invalid or expired."
            )

        receipt = result.get("receipt", {})
        if receipt.get("bundle_id") != self._bundle_id:
            raise AppleBillingError(
                f"Receipt bundle ID '{receipt.get('bundle_id')}' does not match "
                f"expected '{self._bundle_id}'."
            )

        latest = result.get("latest_receipt_info") or []
        if not latest:
            raise AppleBillingError("Apple returned no receipt info.")

        # Prefer entries matching the requested product; fall back to most recent.
        relevant = [r for r in latest if r.get("product_id") == product_id] or latest
        relevant.sort(key=lambda r: int(r.get("expires_date_ms") or 0), reverse=True)
        info = relevant[0]

        expires_ms = int(info.get("expires_date_ms") or 0)
        purchase_ms = int(info.get("purchase_date_ms") or 0)

        return {
            "product_id": info.get("product_id", product_id),
            "transaction_id": info.get("transaction_id"),
            "original_transaction_id": info.get("original_transaction_id"),
            "purchase_date": (
                datetime.fromtimestamp(purchase_ms / 1000, tz=UTC) if purchase_ms else None
            ),
            "expires_date": (
                datetime.fromtimestamp(expires_ms / 1000, tz=UTC) if expires_ms else None
            ),
            "is_trial_period": info.get("is_trial_period", "false") == "true",
        }

    def _post(self, url: str, payload: dict) -> dict:
        try:
            response = httpx.post(url, json=payload, timeout=15.0)
            response.raise_for_status()
            return response.json()
        except httpx.HTTPError as exc:
            raise AppleBillingError(
                f"Failed to contact Apple verification server: {exc}"
            ) from exc
