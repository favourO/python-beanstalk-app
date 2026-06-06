# Phora Backend

Greenfield FastAPI backend scaffold for Phora with:

- versioned REST API under `/api/v1`
- SQLAlchemy persistence models for `health`, `billing`, and `audit` domains
- internal ML client for `GET /health`, `GET /models/versions`, and `POST /predict/ensemble`
- immutable prediction snapshot persistence with shadow-mode ML integration
- Celery worker scaffolding for prediction, ingest, and scheduled jobs
- tests covering age logic, feature-vector assembly, and the prediction API flow

## Local run

Install dependencies:

```bash
python3 -m pip install -e .
```

Start the API:

```bash
uvicorn phora.main:app --reload
```

Run tests:

```bash
pytest
```

## Billing webhooks

Stripe subscription webhooks should be sent to your deployed API URL:

```text
POST /api/v1/billing/stripe/webhook
```

Required environment variables:

```bash
PHORA_STRIPE_WEBHOOK_SECRET=whsec_...[,whsec_old_or_second_endpoint...]
LOCAL_CURRENCY_PRICING_ENABLED=true
AFRICA_FREE_LAUNCH_ENABLED=true
DEFAULT_PRICING_COUNTRY=GB
DEFAULT_CURRENCY=GBP
```

Stripe webhooks remain the source of truth for paid subscription activation. Africa free launch users are activated internally without Stripe subscription rows.

## Current scope

Implemented first:

- auth registration/login
- onboarding profile, cycle history, goal, wearable
- cycle period start, LH log, mucus log
- sensor ingest for temperature, heart rate, sleep
- prediction reads from persisted snapshots
- age-profile and reproductive-stage endpoints
- health and metrics endpoints

The code is structured so Postgres, Redis, RabbitMQ, and the internal ML service can replace the local defaults without changing the public API shape.

Terraform for a real AWS RDS PostgreSQL deployment is in [infra/terraform/README.md](/Users/mac/blomyProject/BE/infra/terraform/README.md).

App deployment for ECS/ALB/Route53 is in [infra/terraform/app/README.md](/Users/mac/blomyProject/BE/infra/terraform/app/README.md).

# phora
