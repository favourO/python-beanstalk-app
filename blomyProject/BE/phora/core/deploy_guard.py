import json
import os
from typing import Any

SMTP_SECRET_KEYS = (
    "PHORA_SMTP_HOST",
    "PHORA_SMTP_PORT",
    "PHORA_SMTP_USERNAME",
    "PHORA_SMTP_PASSWORD",
    "PHORA_SMTP_FROM_EMAIL",
    "PHORA_SMTP_FROM_NAME",
    "PHORA_SMTP_USE_TLS",
    "PHORA_SMTP_USE_SSL",
)
SMTP_REQUIRED_SECRET_KEYS = (
    "PHORA_SMTP_HOST",
    "PHORA_SMTP_FROM_EMAIL",
)


def merge_existing_secret_environment(
    existing_secret: dict[str, str],
    extra_secret_environment: dict[str, str],
) -> dict[str, str]:
    merged = {key: value for key, value in existing_secret.items() if value}
    merged.update(extra_secret_environment)
    return merged


def _json_object(raw: str | None) -> dict[str, str]:
    if not raw:
        return {}
    parsed = json.loads(raw)
    if not isinstance(parsed, dict):
        raise ValueError("expected a JSON object")
    return {str(key): "" if value is None else str(value) for key, value in parsed.items()}


def merge_preserved_smtp_secret_environment(
    existing_secret: dict[str, str],
    extra_secret_environment: dict[str, str],
) -> dict[str, str]:
    return merge_existing_secret_environment(existing_secret, extra_secret_environment)


def smtp_enabled(task_definition: dict[str, Any]) -> bool:
    container = task_definition["taskDefinition"]["containerDefinitions"][0]
    plain_environment = {
        item["name"]: item["value"]
        for item in container.get("environment", [])
    }
    return plain_environment.get("PHORA_SMTP_ENABLED", "").lower() == "true"


def validate_deployed_smtp_config(task_definition: dict[str, Any], secret_environment: dict[str, str]) -> None:
    if not smtp_enabled(task_definition):
        return

    missing_secret_values = [key for key in SMTP_REQUIRED_SECRET_KEYS if not secret_environment.get(key)]
    if missing_secret_values:
        raise ValueError(
            "SMTP is enabled but the app secret is missing required keys: "
            + ", ".join(missing_secret_values)
        )

    container = task_definition["taskDefinition"]["containerDefinitions"][0]
    secret_refs = {item["name"] for item in container.get("secrets", [])}
    missing_secret_refs = [key for key in SMTP_REQUIRED_SECRET_KEYS if key not in secret_refs]
    if missing_secret_refs:
        raise ValueError(
            "SMTP is enabled but the ECS task definition is missing required secret refs: "
            + ", ".join(missing_secret_refs)
        )


def validate_desired_smtp_config(tfvars_text: str, secret_environment: dict[str, str]) -> None:
    smtp_enabled_in_tfvars = (
        "PHORA_SMTP_ENABLED" in tfvars_text
        and '"true"' in tfvars_text.split("PHORA_SMTP_ENABLED", 1)[1].splitlines()[0].lower()
    )
    if not smtp_enabled_in_tfvars:
        return

    missing_secret_values = [key for key in SMTP_REQUIRED_SECRET_KEYS if not secret_environment.get(key)]
    if missing_secret_values:
        raise ValueError(
            "SMTP is enabled but the app secret is missing required keys: "
            + ", ".join(missing_secret_values)
        )


def _run_merge_secret_json() -> int:
    existing_secret = _json_object(os.environ.get("CURRENT_SECRET_JSON"))
    extra_secret_environment = _json_object(os.environ.get("EXTRA_SECRET_JSON"))
    merged = merge_existing_secret_environment(existing_secret, extra_secret_environment)
    print(json.dumps(merged, separators=(",", ":")))
    return 0


def _run_validate_deployed_smtp() -> int:
    task_definition = json.loads(os.environ["TASK_DEFINITION_JSON"])
    secret_environment = _json_object(os.environ.get("CURRENT_SECRET_JSON"))
    validate_deployed_smtp_config(task_definition, secret_environment)
    return 0


def _run_validate_desired_smtp() -> int:
    tfvars = os.environ.get("TFVARS_FILE")
    tfvars_text = open(tfvars, encoding="utf-8").read() if tfvars else ""
    secret_environment = _json_object(os.environ.get("TF_VAR_extra_secret_environment"))
    validate_desired_smtp_config(tfvars_text, secret_environment)
    return 0


def main() -> int:
    command = os.environ.get("DEPLOY_GUARD_COMMAND")
    if command == "merge-secret-json":
        return _run_merge_secret_json()
    if command == "validate-deployed-smtp":
        return _run_validate_deployed_smtp()
    if command == "validate-desired-smtp":
        return _run_validate_desired_smtp()
    raise SystemExit("unsupported DEPLOY_GUARD_COMMAND")


if __name__ == "__main__":
    raise SystemExit(main())
