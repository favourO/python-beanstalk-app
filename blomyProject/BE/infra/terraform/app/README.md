# Terraform: Vyla Prod App Deployment

This stack deploys the current FastAPI app to AWS with:

- ECR for container images
- ECS Fargate for the API service
- an internet-facing ALB
- ACM-managed TLS
- optional Route53 DNS for environment hostnames
- Secrets Manager for the app secret key

## Environments

- prod: `prod.vyla.health`

## Locked architecture

The target shape for the migration is locked as:

- prod runs in AWS account `329937296512`
- prod stays minimal: ECS Fargate + ALB + small RDS
- prod defaults remain `desired_count = 1`, `cpu = 256`, `memory = 512`
- stage is not deployed through this Terraform AWS path
- stage is expected to move to a separate Lightsail container + Lightsail PostgreSQL flow
- ML stays out of deployment
- the old AWS account `396913731550` stays intact until cutover is complete

`./deploy` only supports `prod`.
The prod var file is intentionally a template with placeholders until the new prod VPC, subnets, certificate, and DB outputs exist.

## Required tools

- `terraform`
- `aws`
- `docker buildx`

## Usage

Local deploy:

```bash
./deploy prod
```

If you want Terraform remote state, export:

```bash
export TF_STATE_BUCKET=vyla-terraform-state-329937296512-eu-west-2
export TF_LOCK_TABLE=vyla-terraform-locks
```

The deploy script will then initialize the app stack with the S3 backend instead of local state.

## GitHub Actions

The repository keeps separate GitHub Actions workflows for release intent, but only prod is active on AWS:

- stage workflow -> `.github/workflows/deploy-stage.yml` (intentionally disabled until the Lightsail flow exists)
- `prod` branch -> `.github/workflows/deploy-prod.yml`

The prod workflow should use the `prod` GitHub Actions environment.

Recommended environment secrets:

- `AWS_ROLE_ARN`
- `TF_STATE_BUCKET`
- `TF_LOCK_TABLE`
- `PHORA_SECRET_KEY`
- `PHORA_LLM_API_KEY`
- `PHORA_SMTP_HOST`
- `PHORA_SMTP_PORT`
- `PHORA_SMTP_USERNAME`
- `PHORA_SMTP_PASSWORD`
- `PHORA_SMTP_FROM_EMAIL`
- `PHORA_SMTP_FROM_NAME`
- `PHORA_SMTP_USE_TLS`
- `PHORA_SMTP_USE_SSL`
- `PHORA_STRIPE_SECRET_KEY`
- `PHORA_STRIPE_PUBLISHABLE_KEY`
- `PHORA_STRIPE_WEBHOOK_SECRET`
- `PHORA_FLUTTERWAVE_SECRET_KEY`
- `PHORA_FLUTTERWAVE_PUBLIC_KEY`
- `PHORA_FLUTTERWAVE_ENCRYPTION_KEY`
- `PHORA_FLUTTERWAVE_REDIRECT_URL`
- `PHORA_FLUTTERWAVE_WEBHOOK_SECRET_HASH`

The deploy flow preserves any existing AWS Secrets Manager values that are not explicitly overridden by the workflow.


## External DNS (Namecheap)

If `vyla.health` stays on Namecheap rather than Route53:

- set `route53_zone_id = null`
- request or validate an ACM certificate in `eu-west-2` and place its ARN in `certificate_arn`
- use `terraform output alb_dns_name` for the final ALB target
- use `terraform output alb_zone_id` if you need the AWS alias zone reference

For Namecheap, use an `ALIAS` record for `@` pointing to the prod ALB hostname.
If you need AWS to generate the ACM validation CNAMEs first, request the certificate separately with the AWS CLI or console, add the returned CNAMEs in Namecheap, wait for the cert to become `ISSUED`, then set `certificate_arn` in the tfvars file before deploy.
