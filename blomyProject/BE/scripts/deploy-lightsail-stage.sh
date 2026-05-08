#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
REGION="${AWS_REGION:-eu-west-2}"
EXPECTED_ACCOUNT_ID="${AWS_ACCOUNT_ID:-329937296512}"

SERVICE_NAME="${SERVICE_NAME:-vyla-stage-api}"
DB_RESOURCE_NAME="${DB_RESOURCE_NAME:-vyla-stage-postgres}"
DB_BLUEPRINT_ID="${DB_BLUEPRINT_ID:-postgres_16}"
DB_BUNDLE_ID="${DB_BUNDLE_ID:-micro_2_0}"
DB_NAME="${DB_NAME:-vyla_stage}"
DB_USERNAME="${DB_USERNAME:-vylastage}"
APP_SECRET_ID="${APP_SECRET_ID:-vyla-stage/app-config}"
DB_SECRET_ID="${DB_SECRET_ID:-vyla-stage/db-config}"
CERTIFICATE_NAME="${CERTIFICATE_NAME:-vyla-stage-cert}"
STAGE_DOMAIN="${STAGE_DOMAIN:-stage.vyla.health}"
ROUTE53_ZONE_ID="${ROUTE53_ZONE_ID:-Z08324621C212Q3UVET6I}"
ECR_REPOSITORY_NAME="${ECR_REPOSITORY_NAME:-vyla-stage-api}"

LOCAL_IMAGE_TAG="${LOCAL_IMAGE_TAG:-${SERVICE_NAME}:$(date +%Y%m%d%H%M%S)}"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

command -v aws >/dev/null
command -v docker >/dev/null
command -v python3 >/dev/null
command -v curl >/dev/null

ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
if [[ "$ACCOUNT_ID" != "$EXPECTED_ACCOUNT_ID" ]]; then
  echo "refusing stage deploy: authenticated AWS account ${ACCOUNT_ID} does not match expected ${EXPECTED_ACCOUNT_ID}"
  exit 1
fi

json_get() {
  local json="$1"
  local expr="$2"
  JSON_GET_PAYLOAD="$json" JSON_GET_EXPR="$expr" python3 - <<'PY'
import json
import os

payload = json.loads(os.environ["JSON_GET_PAYLOAD"])
expr = os.environ["JSON_GET_EXPR"]
value = payload
for part in expr.split("."):
    if not part:
        continue
    if isinstance(value, list) and part.isdigit():
        index = int(part)
        if index >= len(value):
            value = None
            break
        value = value[index]
    elif isinstance(value, dict):
        value = value.get(part)
    else:
        value = None
        break
print("" if value is None else value)
PY
}

random_secret() {
  python3 - <<'PY'
import secrets
import string

alphabet = string.ascii_letters + string.digits
print("".join(secrets.choice(alphabet) for _ in range(48)))
PY
}

random_db_password() {
  python3 - <<'PY'
import secrets
import string

alphabet = string.ascii_letters + string.digits + "!#$%^*+=:._-"
print("".join(secrets.choice(alphabet) for _ in range(28)))
PY
}

urlencode() {
  URLENCODE_VALUE="$1" python3 - <<'PY'
import os
import urllib.parse

print(urllib.parse.quote(os.environ["URLENCODE_VALUE"], safe=""))
PY
}

secret_exists() {
  aws secretsmanager describe-secret \
    --secret-id "$1" \
    --region "$REGION" >/dev/null 2>&1
}

ensure_app_secret() {
  local existing="{}"
  if secret_exists "$APP_SECRET_ID"; then
    existing="$(
      aws secretsmanager get-secret-value \
        --secret-id "$APP_SECRET_ID" \
        --region "$REGION" \
        --query SecretString \
        --output text
    )"
  fi

  local merged
  merged="$(
    EXISTING_SECRET_JSON="$existing" python3 - <<'PY'
import json
import os
import secrets
import string

existing = json.loads(os.environ["EXISTING_SECRET_JSON"] or "{}")

def token(length: int) -> str:
    alphabet = string.ascii_letters + string.digits
    return "".join(secrets.choice(alphabet) for _ in range(length))

merged = {
    "PHORA_SECRET_KEY": existing.get("PHORA_SECRET_KEY") or token(48),
    "PHORA_APPLE_BUNDLE_ID": existing.get("PHORA_APPLE_BUNDLE_ID", ""),
    "PHORA_APPLE_SERVICE_ID": existing.get("PHORA_APPLE_SERVICE_ID", ""),
    "PHORA_STRIPE_SECRET_KEY": existing.get("PHORA_STRIPE_SECRET_KEY", ""),
    "PHORA_STRIPE_PUBLISHABLE_KEY": existing.get("PHORA_STRIPE_PUBLISHABLE_KEY", ""),
    "PHORA_STRIPE_WEBHOOK_SECRET": existing.get("PHORA_STRIPE_WEBHOOK_SECRET", ""),
    "PHORA_FLUTTERWAVE_SECRET_KEY": existing.get("PHORA_FLUTTERWAVE_SECRET_KEY", ""),
    "PHORA_FLUTTERWAVE_PUBLIC_KEY": existing.get("PHORA_FLUTTERWAVE_PUBLIC_KEY", ""),
    "PHORA_FLUTTERWAVE_ENCRYPTION_KEY": existing.get("PHORA_FLUTTERWAVE_ENCRYPTION_KEY", ""),
    "PHORA_FLUTTERWAVE_REDIRECT_URL": existing.get("PHORA_FLUTTERWAVE_REDIRECT_URL", ""),
    "PHORA_FLUTTERWAVE_WEBHOOK_SECRET_HASH": existing.get("PHORA_FLUTTERWAVE_WEBHOOK_SECRET_HASH", ""),
    "PHORA_LLM_API_KEY": existing.get("PHORA_LLM_API_KEY", ""),
    "PHORA_FIREBASE_CREDENTIALS_JSON": existing.get("PHORA_FIREBASE_CREDENTIALS_JSON", ""),
    "PHORA_DATABASE_URL": existing.get("PHORA_DATABASE_URL", ""),
    "PHORA_SMTP_HOST": existing.get("PHORA_SMTP_HOST", ""),
    "PHORA_SMTP_PORT": existing.get("PHORA_SMTP_PORT", "587"),
    "PHORA_SMTP_USERNAME": existing.get("PHORA_SMTP_USERNAME", ""),
    "PHORA_SMTP_PASSWORD": existing.get("PHORA_SMTP_PASSWORD", ""),
    "PHORA_SMTP_FROM_EMAIL": existing.get("PHORA_SMTP_FROM_EMAIL", ""),
    "PHORA_SMTP_FROM_NAME": existing.get("PHORA_SMTP_FROM_NAME", "Vyla Health"),
    "PHORA_SMTP_USE_TLS": existing.get("PHORA_SMTP_USE_TLS", "true"),
    "PHORA_SMTP_USE_SSL": existing.get("PHORA_SMTP_USE_SSL", "false"),
}

print(json.dumps(merged, separators=(",", ":")))
PY
  )"

  if secret_exists "$APP_SECRET_ID"; then
    aws secretsmanager put-secret-value \
      --secret-id "$APP_SECRET_ID" \
      --region "$REGION" \
      --secret-string "$merged" >/dev/null
  else
    aws secretsmanager create-secret \
      --name "$APP_SECRET_ID" \
      --region "$REGION" \
      --secret-string "$merged" >/dev/null
  fi
}

ensure_stage_database() {
  if aws lightsail get-relational-database \
    --region "$REGION" \
    --relational-database-name "$DB_RESOURCE_NAME" >/dev/null 2>&1; then
    return
  fi

  local db_password
  db_password="$(random_db_password)"

  aws lightsail create-relational-database \
    --region "$REGION" \
    --relational-database-name "$DB_RESOURCE_NAME" \
    --relational-database-blueprint-id "$DB_BLUEPRINT_ID" \
    --relational-database-bundle-id "$DB_BUNDLE_ID" \
    --master-database-name "$DB_NAME" \
    --master-username "$DB_USERNAME" \
    --master-user-password "$db_password" \
    --no-publicly-accessible \
    --tags key=Project,value=vyla key=Environment,value=stage >/dev/null

  local db_secret_json
  db_secret_json="$(
    DB_PASSWORD="$db_password" python3 - <<'PY'
import json
import os

print(json.dumps({
    "db_resource_name": "vyla-stage-postgres",
    "database_name": "vyla_stage",
    "username": "vylastage",
    "password": os.environ["DB_PASSWORD"],
}, separators=(",", ":")))
PY
  )"

  if secret_exists "$DB_SECRET_ID"; then
    aws secretsmanager put-secret-value \
      --secret-id "$DB_SECRET_ID" \
      --region "$REGION" \
      --secret-string "$db_secret_json" >/dev/null
  else
    aws secretsmanager create-secret \
      --name "$DB_SECRET_ID" \
      --region "$REGION" \
      --secret-string "$db_secret_json" >/dev/null
  fi
}

wait_for_database() {
  local state=""
  until [[ "$state" == "available" ]]; do
    sleep 20
    state="$(
      aws lightsail get-relational-database \
        --region "$REGION" \
        --relational-database-name "$DB_RESOURCE_NAME" \
        --query 'relationalDatabase.state' \
        --output text
    )"
    echo "stage database state: $state"
  done
}

refresh_stage_database_secret() {
  local db_secret_json
  db_secret_json="$(
    aws secretsmanager get-secret-value \
      --secret-id "$DB_SECRET_ID" \
      --region "$REGION" \
      --query SecretString \
      --output text
  )"

  local password
  password="$(json_get "$db_secret_json" "password")"
  if [[ -z "$password" ]]; then
    echo "stage db secret is missing password"
    exit 1
  fi

  local db_host db_port encoded_password database_url merged_app_secret
  db_host="$(
    aws lightsail get-relational-database \
      --region "$REGION" \
      --relational-database-name "$DB_RESOURCE_NAME" \
      --query 'relationalDatabase.masterEndpoint.address' \
      --output text
  )"
  db_port="$(
    aws lightsail get-relational-database \
      --region "$REGION" \
      --relational-database-name "$DB_RESOURCE_NAME" \
      --query 'relationalDatabase.masterEndpoint.port' \
      --output text
  )"

  encoded_password="$(urlencode "$password")"
  database_url="postgresql+psycopg://${DB_USERNAME}:${encoded_password}@${db_host}:${db_port}/${DB_NAME}?sslmode=require"

  aws secretsmanager put-secret-value \
    --secret-id "$DB_SECRET_ID" \
    --region "$REGION" \
    --secret-string "$(
      DB_HOST="$db_host" DB_PORT="$db_port" DB_PASSWORD="$password" DB_URL="$database_url" python3 - <<'PY'
import json
import os

print(json.dumps({
    "db_resource_name": "vyla-stage-postgres",
    "database_name": "vyla_stage",
    "username": "vylastage",
    "password": os.environ["DB_PASSWORD"],
    "host": os.environ["DB_HOST"],
    "port": os.environ["DB_PORT"],
    "database_url": os.environ["DB_URL"],
}, separators=(",", ":")))
PY
    )" >/dev/null

  merged_app_secret="$(
    EXISTING_SECRET_JSON="$(
      aws secretsmanager get-secret-value \
        --secret-id "$APP_SECRET_ID" \
        --region "$REGION" \
        --query SecretString \
        --output text
    )" DATABASE_URL="$database_url" python3 - <<'PY'
import json
import os

existing = json.loads(os.environ["EXISTING_SECRET_JSON"])
existing["PHORA_DATABASE_URL"] = os.environ["DATABASE_URL"]
print(json.dumps(existing, separators=(",", ":")))
PY
  )"

  aws secretsmanager put-secret-value \
    --secret-id "$APP_SECRET_ID" \
    --region "$REGION" \
    --secret-string "$merged_app_secret" >/dev/null
}

ensure_container_service() {
  if aws lightsail get-container-services \
    --region "$REGION" \
    --service-name "$SERVICE_NAME" >/dev/null 2>&1; then
    aws lightsail update-container-service \
      --region "$REGION" \
      --service-name "$SERVICE_NAME" \
      --private-registry-access 'ecrImagePullerRole={isActive=true}' >/dev/null
    return
  fi

  aws lightsail create-container-service \
    --region "$REGION" \
    --service-name "$SERVICE_NAME" \
    --power nano \
    --scale 1 \
    --private-registry-access 'ecrImagePullerRole={isActive=true}' \
    --tags key=Project,value=vyla key=Environment,value=stage >/dev/null
}

wait_for_container_service() {
  local state=""
  until [[ "$state" == "READY" || "$state" == "RUNNING" ]]; do
    sleep 10
    state="$(
      aws lightsail get-container-services \
        --region "$REGION" \
        --service-name "$SERVICE_NAME" \
        --query 'containerServices[0].state' \
        --output text
    )"
    echo "stage container service state: $state"
  done
}

ensure_ecr_repository() {
  if aws ecr describe-repositories \
    --repository-names "$ECR_REPOSITORY_NAME" \
    --region "$REGION" >/dev/null 2>&1; then
    return
  fi

  aws ecr create-repository \
    --repository-name "$ECR_REPOSITORY_NAME" \
    --image-scanning-configuration scanOnPush=true \
    --region "$REGION" >/dev/null
}

ensure_ecr_repository_policy() {
  local principal_arn policy_json
  principal_arn="$(
    aws lightsail get-container-services \
      --region "$REGION" \
      --service-name "$SERVICE_NAME" \
      --query 'containerServices[0].privateRegistryAccess.ecrImagePullerRole.principalArn' \
      --output text
  )"

  if [[ -z "$principal_arn" || "$principal_arn" == "None" ]]; then
    echo "Lightsail ECR puller principal is not available yet"
    exit 1
  fi

  policy_json="$(
    PRINCIPAL_ARN="$principal_arn" python3 - <<'PY'
import json
import os

print(json.dumps({
    "Version": "2008-10-17",
    "Statement": [
        {
            "Sid": "AllowLightsailStagePull",
            "Effect": "Allow",
            "Principal": {"AWS": os.environ["PRINCIPAL_ARN"]},
            "Action": [
                "ecr:BatchCheckLayerAvailability",
                "ecr:BatchGetImage",
                "ecr:GetDownloadUrlForLayer",
            ],
        }
    ],
}, separators=(",", ":")))
PY
  )"

  aws ecr set-repository-policy \
    --repository-name "$ECR_REPOSITORY_NAME" \
    --region "$REGION" \
    --policy-text "$policy_json" >/dev/null
}

build_and_push_image() {
  local repository_url registry_host remote_image_uri
  repository_url="$(
    aws ecr describe-repositories \
      --repository-names "$ECR_REPOSITORY_NAME" \
      --region "$REGION" \
      --query 'repositories[0].repositoryUri' \
      --output text
  )"
  registry_host="${repository_url%/*}"
  remote_image_uri="${repository_url}:stage-$(date +%Y%m%d%H%M%S)"

  docker buildx build \
    --platform linux/amd64 \
    --load \
    -t "$LOCAL_IMAGE_TAG" \
    "$ROOT_DIR" >/dev/null

  aws ecr get-login-password --region "$REGION" \
    | docker login --username AWS --password-stdin "$registry_host" >/dev/null

  docker tag "$LOCAL_IMAGE_TAG" "$remote_image_uri"
  docker push "$remote_image_uri" >/dev/null

  echo "$remote_image_uri"
}

deploy_container_service() {
  local service_url app_secret_json deployment_json remote_image_uri
  remote_image_uri="$1"
  service_url="$(
    aws lightsail get-container-services \
      --region "$REGION" \
      --service-name "$SERVICE_NAME" \
      --query 'containerServices[0].url' \
      --output text
  )"
  app_secret_json="$(
    aws secretsmanager get-secret-value \
      --secret-id "$APP_SECRET_ID" \
      --region "$REGION" \
      --query SecretString \
      --output text
  )"

  deployment_json="$TMP_DIR/stage-deployment.json"
  APP_SECRET_JSON="$app_secret_json" SERVICE_NAME="$SERVICE_NAME" SERVICE_URL="$service_url" STAGE_DOMAIN="$STAGE_DOMAIN" REMOTE_IMAGE_URI="$remote_image_uri" python3 - <<'PY' > "$deployment_json"
import json
import os

secret_env = json.loads(os.environ["APP_SECRET_JSON"])
env = {
    "PHORA_APP_NAME": "vyla-stage-api",
    "PHORA_ENVIRONMENT": "stage",
    "PHORA_API_PREFIX": "/api/v1",
    "PHORA_API_PREFIX_LEGACY": "/api/0.1.0",
    "PHORA_ML_ENABLED": "false",
    "PHORA_ML_TIMEOUT_MS": "5000",
    "PHORA_ML_RETRY_COUNT": "2",
    "PHORA_ML_SHADOW_MODE": "true",
    "PHORA_AUTO_CREATE_TABLES": "true",
    "PHORA_HEALTH_SCHEMA": "health",
    "PHORA_BILLING_SCHEMA": "billing",
    "PHORA_AUDIT_SCHEMA": "audit",
    "PHORA_OTP_EXPIRATION_MINUTES": "10",
    "PHORA_OTP_LENGTH": "6",
    "PHORA_PUBLIC_APP_URL": f"https://{os.environ['STAGE_DOMAIN']}",
    "PHORA_REPORT_SHARE_BUCKET": "",
    "PHORA_FIREBASE_PROJECT_ID": "vyla-41e3a",
    "PHORA_SMTP_ENABLED": "true",
}
env.update(secret_env)
if env.get("PHORA_SMTP_ENABLED", "").lower() == "true":
    missing = [
        key
        for key in ("PHORA_SMTP_HOST", "PHORA_SMTP_FROM_EMAIL")
        if not str(env.get(key, "")).strip()
    ]
    if missing:
        raise SystemExit(
            "SMTP is enabled but stage app config is missing required keys: "
            + ", ".join(missing)
        )

payload = {
    "containers": {
        "app": {
            "image": os.environ["REMOTE_IMAGE_URI"],
            "ports": {"8000": "HTTP"},
            "environment": env,
        }
    },
    "publicEndpoint": {
        "containerName": "app",
        "containerPort": 8000,
        "healthCheck": {
            "path": "/api/v1/health",
            "successCodes": "200-399",
            "healthyThreshold": 2,
            "unhealthyThreshold": 3,
            "intervalSeconds": 10,
            "timeoutSeconds": 5,
        },
    },
}
print(json.dumps(payload))
PY

  aws lightsail create-container-service-deployment \
    --region "$REGION" \
    --service-name "$SERVICE_NAME" \
    --cli-input-json "file://$deployment_json" >/dev/null
}

ensure_stage_certificate() {
  local cert_count
  cert_count="$(
    aws lightsail get-certificates \
      --region "$REGION" \
      --certificate-name "$CERTIFICATE_NAME" \
      --query 'length(certificates)' \
      --output text 2>/dev/null || echo "0"
  )"

  if [[ "$cert_count" != "0" ]]; then
    return
  fi

  aws lightsail create-certificate \
    --region "$REGION" \
    --certificate-name "$CERTIFICATE_NAME" \
    --domain-name "$STAGE_DOMAIN" \
    --tags key=Project,value=vyla key=Environment,value=stage >/dev/null
}

upsert_stage_certificate_validation_record() {
  local cert_details record_name record_type record_value
  cert_details="$(
    aws lightsail get-certificates \
      --region "$REGION" \
      --certificate-name "$CERTIFICATE_NAME" \
      --include-certificate-details \
      --output json
  )"
  record_name="$(json_get "$cert_details" "certificates.0.certificateDetail.domainValidationRecords.0.name")"
  record_type="$(json_get "$cert_details" "certificates.0.certificateDetail.domainValidationRecords.0.type")"
  record_value="$(json_get "$cert_details" "certificates.0.certificateDetail.domainValidationRecords.0.value")"

  if [[ -z "$record_name" || -z "$record_type" || -z "$record_value" ]]; then
    echo "stage certificate validation record is not available yet"
    return
  fi

  cat > "$TMP_DIR/route53-stage-cert-validation.json" <<EOF
{
  "Comment": "UPSERT stage Lightsail certificate validation",
  "Changes": [
    {
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "${record_name}",
        "Type": "${record_type}",
        "TTL": 60,
        "ResourceRecords": [
          {
            "Value": "${record_value}"
          }
        ]
      }
    }
  ]
}
EOF

  aws route53 change-resource-record-sets \
    --hosted-zone-id "$ROUTE53_ZONE_ID" \
    --change-batch "file://$TMP_DIR/route53-stage-cert-validation.json" >/dev/null
}

attach_stage_domain_if_ready() {
  local cert_status
  cert_status="$(
    aws lightsail get-certificates \
      --region "$REGION" \
      --certificate-name "$CERTIFICATE_NAME" \
      --query 'certificates[0].certificateDetail.status' \
      --output text
  )"

  if [[ "$cert_status" != "ISSUED" ]]; then
    echo "stage certificate status: $cert_status"
    return
  fi

  aws lightsail update-container-service \
    --region "$REGION" \
    --service-name "$SERVICE_NAME" \
    --public-domain-names "${CERTIFICATE_NAME}=${STAGE_DOMAIN}" >/dev/null

  local service_url record_target
  service_url="$(
    aws lightsail get-container-services \
      --region "$REGION" \
      --service-name "$SERVICE_NAME" \
      --query 'containerServices[0].url' \
      --output text
  )"
  record_target="${service_url#https://}"
  record_target="${record_target%/}"

  cat > "$TMP_DIR/route53-stage-cname.json" <<EOF
{
  "Comment": "UPSERT stage Lightsail endpoint",
  "Changes": [
    {
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "${STAGE_DOMAIN}.",
        "Type": "CNAME",
        "TTL": 60,
        "ResourceRecords": [
          {
            "Value": "${record_target}"
          }
        ]
      }
    }
  ]
}
EOF

  aws route53 change-resource-record-sets \
    --hosted-zone-id "$ROUTE53_ZONE_ID" \
    --change-batch "file://$TMP_DIR/route53-stage-cname.json" >/dev/null
}

wait_for_deployment_ready() {
  local state=""
  until [[ "$state" == "READY" || "$state" == "RUNNING" ]]; do
    sleep 10
    state="$(
      aws lightsail get-container-services \
        --region "$REGION" \
        --service-name "$SERVICE_NAME" \
        --query 'containerServices[0].state' \
        --output text
    )"
    echo "stage deployment state: $state"
  done
}

validate_stage_health() {
  local service_url
  service_url="$(
    aws lightsail get-container-services \
      --region "$REGION" \
      --service-name "$SERVICE_NAME" \
      --query 'containerServices[0].url' \
      --output text
  )"

  curl -fsS "${service_url%/}/api/v1/health" >/dev/null
}

print_summary() {
  local service_url db_host cert_status
  service_url="$(
    aws lightsail get-container-services \
      --region "$REGION" \
      --service-name "$SERVICE_NAME" \
      --query 'containerServices[0].url' \
      --output text
  )"
  db_host="$(
    aws lightsail get-relational-database \
      --region "$REGION" \
      --relational-database-name "$DB_RESOURCE_NAME" \
      --query 'relationalDatabase.masterEndpoint.address' \
      --output text
  )"
  cert_status="$(
    aws lightsail get-certificates \
      --region "$REGION" \
      --certificate-name "$CERTIFICATE_NAME" \
      --query 'certificates[0].certificateDetail.status' \
      --output text 2>/dev/null || echo "NOT_REQUESTED"
  )"

  echo "Stage deploy complete."
  echo "Container service: $SERVICE_NAME"
  echo "Stage endpoint: $service_url"
  echo "Stage database: $DB_RESOURCE_NAME ($db_host)"
  echo "Stage app secret: $APP_SECRET_ID"
  echo "Stage db secret: $DB_SECRET_ID"
  echo "Stage certificate: $CERTIFICATE_NAME ($cert_status)"
}

ensure_app_secret
ensure_stage_database
wait_for_database
refresh_stage_database_secret
ensure_container_service
wait_for_container_service
ensure_ecr_repository
ensure_ecr_repository_policy
REMOTE_IMAGE_URI="$(build_and_push_image)"
deploy_container_service "$REMOTE_IMAGE_URI"
wait_for_deployment_ready
validate_stage_health
ensure_stage_certificate
upsert_stage_certificate_validation_record
attach_stage_domain_if_ready
print_summary
