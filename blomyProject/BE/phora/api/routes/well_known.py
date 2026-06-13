"""
/.well-known endpoints required for iOS Universal Links and Android App Links.

iOS needs /.well-known/apple-app-site-association served by the domain listed
in the app's Associated Domains entitlement (applinks:vyla.health).

Android needs /.well-known/assetlinks.json served by the domain listed in the
intent-filter with android:autoVerify="true".

Both files must be served over HTTPS with Content-Type application/json and
without redirects — the OS fetches them at install time to verify the link claim.
"""
import json

from fastapi import APIRouter
from fastapi.responses import Response

from phora.core.config import get_settings

router = APIRouter(tags=["well-known"])

_JSON = "application/json"

# Paths in vyla.health that should open the app instead of the website.
# /dashboard is the only one used in emails today; extend as needed.
_APP_PATHS = ["/dashboard", "/dashboard/*"]


@router.get("/.well-known/apple-app-site-association", include_in_schema=False)
def apple_app_site_association() -> Response:
    settings = get_settings()
    team_id = settings.apple_team_id
    bundle_id = settings.apple_bundle_id or "com.vyla.health"
    app_id = f"{team_id}.{bundle_id}"

    payload = {
        "applinks": {
            "details": [
                {
                    "appIDs": [app_id],
                    "components": [{"/" : path} for path in _APP_PATHS],
                }
            ]
        }
    }
    return Response(
        content=json.dumps(payload),
        media_type=_JSON,
        headers={"Cache-Control": "public, max-age=3600"},
    )


@router.get("/.well-known/assetlinks.json", include_in_schema=False)
def assetlinks() -> Response:
    settings = get_settings()
    fingerprints = []
    if settings.android_sha256_fingerprint:
        fingerprints.append(settings.android_sha256_fingerprint)

    payload = [
        {
            "relation": ["delegate_permission/common.handle_all_urls"],
            "target": {
                "namespace": "android_app",
                "package_name": settings.android_package_name,
                "sha256_cert_fingerprints": fingerprints,
            },
        }
    ]
    return Response(
        content=json.dumps(payload),
        media_type=_JSON,
        headers={"Cache-Control": "public, max-age=3600"},
    )
