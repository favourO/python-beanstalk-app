import pytest

from phora.core.deploy_guard import (
    merge_existing_secret_environment,
    merge_preserved_smtp_secret_environment,
    validate_deployed_smtp_config,
    validate_desired_smtp_config,
)


def test_merge_preserves_existing_secret_values_outside_smtp():
    existing_secret = {
        "PHORA_STRIPE_SECRET_KEY": "sk_live_existing",
        "PHORA_LLM_API_KEY": "existing-llm-key",
    }

    merged = merge_existing_secret_environment(existing_secret, {"PHORA_SECRET_KEY": "new-app-secret"})

    assert merged["PHORA_STRIPE_SECRET_KEY"] == "sk_live_existing"
    assert merged["PHORA_LLM_API_KEY"] == "existing-llm-key"
    assert merged["PHORA_SECRET_KEY"] == "new-app-secret"


def test_merge_preserves_existing_smtp_secret_values():
    existing_secret = {
        "PHORA_SMTP_HOST": "mail.privateemail.com",
        "PHORA_SMTP_FROM_EMAIL": "noreply@demycorp.com",
        "PHORA_SMTP_PORT": "587",
    }

    merged = merge_preserved_smtp_secret_environment(existing_secret, {"PHORA_LLM_API_KEY": ""})

    assert merged["PHORA_SMTP_HOST"] == "mail.privateemail.com"
    assert merged["PHORA_SMTP_FROM_EMAIL"] == "noreply@demycorp.com"
    assert merged["PHORA_SMTP_PORT"] == "587"
    assert merged["PHORA_LLM_API_KEY"] == ""


def test_merge_prefers_explicit_overrides_for_smtp_secret_values():
    existing_secret = {
        "PHORA_SMTP_HOST": "old.mail.example.com",
        "PHORA_SMTP_FROM_EMAIL": "old@example.com",
    }

    merged = merge_preserved_smtp_secret_environment(
        existing_secret,
        {
            "PHORA_SMTP_HOST": "new.mail.example.com",
            "PHORA_SMTP_FROM_EMAIL": "new@example.com",
        },
    )

    assert merged["PHORA_SMTP_HOST"] == "new.mail.example.com"
    assert merged["PHORA_SMTP_FROM_EMAIL"] == "new@example.com"


def test_merge_allows_explicit_secret_clears():
    existing_secret = {
        "PHORA_STRIPE_PUBLISHABLE_KEY": "pk_live_old",
    }

    merged = merge_existing_secret_environment(
        existing_secret,
        {"PHORA_STRIPE_PUBLISHABLE_KEY": ""},
    )

    assert merged["PHORA_STRIPE_PUBLISHABLE_KEY"] == ""


def test_validate_deployed_smtp_config_rejects_missing_required_secret_keys():
    task_definition = {
        "taskDefinition": {
            "containerDefinitions": [
                {
                    "environment": [
                        {"name": "PHORA_SMTP_ENABLED", "value": "true"},
                    ],
                    "secrets": [],
                }
            ]
        }
    }

    with pytest.raises(ValueError, match="missing required keys"):
        validate_deployed_smtp_config(task_definition, {})


def test_validate_deployed_smtp_config_rejects_missing_required_secret_refs():
    task_definition = {
        "taskDefinition": {
            "containerDefinitions": [
                {
                    "environment": [
                        {"name": "PHORA_SMTP_ENABLED", "value": "true"},
                    ],
                    "secrets": [
                        {"name": "PHORA_SMTP_HOST"},
                    ],
                }
            ]
        }
    }
    secret_environment = {
        "PHORA_SMTP_HOST": "mail.privateemail.com",
        "PHORA_SMTP_FROM_EMAIL": "noreply@demycorp.com",
    }

    with pytest.raises(ValueError, match="missing required secret refs"):
        validate_deployed_smtp_config(task_definition, secret_environment)


def test_validate_deployed_smtp_config_accepts_complete_smtp_configuration():
    task_definition = {
        "taskDefinition": {
            "containerDefinitions": [
                {
                    "environment": [
                        {"name": "PHORA_SMTP_ENABLED", "value": "true"},
                    ],
                    "secrets": [
                        {"name": "PHORA_SMTP_HOST"},
                        {"name": "PHORA_SMTP_FROM_EMAIL"},
                    ],
                }
            ]
        }
    }
    secret_environment = {
        "PHORA_SMTP_HOST": "mail.privateemail.com",
        "PHORA_SMTP_FROM_EMAIL": "noreply@demycorp.com",
    }

    validate_deployed_smtp_config(task_definition, secret_environment)


def test_validate_desired_smtp_config_rejects_missing_required_values():
    tfvars_text = '''
extra_environment = {
  PHORA_SMTP_ENABLED = "true"
}
'''

    with pytest.raises(ValueError, match="missing required keys"):
        validate_desired_smtp_config(tfvars_text, {})


def test_validate_desired_smtp_config_accepts_complete_secret_values():
    tfvars_text = '''
extra_environment = {
  PHORA_SMTP_ENABLED = "true"
}
'''
    secret_environment = {
        "PHORA_SMTP_HOST": "mail.privateemail.com",
        "PHORA_SMTP_FROM_EMAIL": "noreply@demycorp.com",
    }

    validate_desired_smtp_config(tfvars_text, secret_environment)
