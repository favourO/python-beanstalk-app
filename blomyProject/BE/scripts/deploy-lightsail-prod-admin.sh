#!/bin/bash
set -euo pipefail

ADMIN_DIR="$(cd "$(dirname "$0")/../../admin" && pwd)"
REGION="${AWS_REGION:-eu-west-2}"
EXPECTED_ACCOUNT_ID="${AWS_ACCOUNT_ID:-329937296512}"

SERVICE_NAME="${SERVICE_NAME:-vyla-prod-admin}"
ECR_REPOSITORY_NAME="${ECR_REPOSITORY_NAME:-vyla-prod-admin}"
NEXT_PUBLIC_API_URL="${NEXT_PUBLIC_API_URL:-https://prod.api.vyla.health}"
LOCAL_IMAGE_TAG="${LOCAL_IMAGE_TAG:-${SERVICE_NAME}:$(date +%Y%m%d%H%M%S)}"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

command -v aws >/dev/null
command -v docker >/dev/null

ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
if [[ "$ACCOUNT_ID" != "$EXPECTED_ACCOUNT_ID" ]]; then
  echo "refusing prod admin deploy: authenticated AWS account ${ACCOUNT_ID} does not match expected ${EXPECTED_ACCOUNT_ID}"
  exit 1
fi

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
  echo "Created ECR repository: $ECR_REPOSITORY_NAME"
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
    --tags key=Project,value=vyla key=Environment,value=prod >/dev/null
  echo "Created Lightsail container service: $SERVICE_NAME"
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
    echo "container service state: $state"
  done
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
            "Sid": "AllowLightsailProdAdminPull",
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
  remote_image_uri="${repository_url}:prod-$(date +%Y%m%d%H%M%S)"

  docker buildx build \
    --platform linux/amd64 \
    --load \
    --build-arg "NEXT_PUBLIC_API_URL=${NEXT_PUBLIC_API_URL}" \
    -t "$LOCAL_IMAGE_TAG" \
    "$ADMIN_DIR"

  aws ecr get-login-password --region "$REGION" \
    | docker login --username AWS --password-stdin "$registry_host" >/dev/null

  docker tag "$LOCAL_IMAGE_TAG" "$remote_image_uri"
  docker push "$remote_image_uri" >/dev/null

  echo "$remote_image_uri"
}

deploy_container_service() {
  local remote_image_uri deployment_json
  remote_image_uri="$1"

  deployment_json="$TMP_DIR/prod-admin-deployment.json"
  REMOTE_IMAGE_URI="$remote_image_uri" SERVICE_NAME="$SERVICE_NAME" python3 - <<'PY' > "$deployment_json"
import json
import os

payload = {
    "containers": {
        "app": {
            "image": os.environ["REMOTE_IMAGE_URI"],
            "ports": {"80": "HTTP"},
            "environment": {
                "NODE_ENV": "production",
            },
        }
    },
    "publicEndpoint": {
        "containerName": "app",
        "containerPort": 80,
        "healthCheck": {
            "path": "/",
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
    echo "deployment state: $state"
  done
}

print_summary() {
  local service_url
  service_url="$(
    aws lightsail get-container-services \
      --region "$REGION" \
      --service-name "$SERVICE_NAME" \
      --query 'containerServices[0].url' \
      --output text
  )"

  echo "Prod admin deploy complete."
  echo "Container service: $SERVICE_NAME"
  echo "Admin endpoint: $service_url"
  echo "API URL baked in: $NEXT_PUBLIC_API_URL"
}

ensure_ecr_repository
ensure_container_service
wait_for_container_service
ensure_ecr_repository_policy
REMOTE_IMAGE_URI="$(build_and_push_image)"
deploy_container_service "$REMOTE_IMAGE_URI"
wait_for_deployment_ready
print_summary
