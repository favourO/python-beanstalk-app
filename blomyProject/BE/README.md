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

Flutterwave payment status is synced into the local subscription and invoice tables through:

```text
POST /api/v1/billing/flutterwave/webhook
```

Configure Flutterwave to send webhook events to your deployed API URL, for example:

```text
https://api.example.com/api/v1/billing/flutterwave/webhook
```

Required environment variables:

```bash
PHORA_FLUTTERWAVE_SECRET_KEY=...
PHORA_FLUTTERWAVE_WEBHOOK_SECRET_HASH=...
PHORA_STRIPE_WEBHOOK_SECRET=whsec_...[,whsec_old_or_second_endpoint...]
```

The webhook handler verifies the request signature, verifies the transaction with Flutterwave, and then updates the matching `Subscription` and `Invoice` rows so the user becomes `active` after a successful charge.

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
