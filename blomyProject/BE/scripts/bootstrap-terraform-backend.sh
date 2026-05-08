#!/bin/zsh
set -euo pipefail

ACCOUNT_ID="${1:-329937296512}"
REGION="${2:-eu-west-2}"
STATE_BUCKET="${TF_STATE_BUCKET:-vyla-terraform-state-${ACCOUNT_ID}-${REGION}}"
LOCK_TABLE="${TF_LOCK_TABLE:-vyla-terraform-locks}"

current_account_id="$(aws sts get-caller-identity --query Account --output text)"
if [[ "$current_account_id" != "$ACCOUNT_ID" ]]; then
  echo "refusing backend bootstrap: authenticated AWS account ${current_account_id} does not match expected ${ACCOUNT_ID}"
  exit 1
fi

if ! aws s3api head-bucket --bucket "$STATE_BUCKET" >/dev/null 2>&1; then
  aws s3api create-bucket \
    --bucket "$STATE_BUCKET" \
    --region "$REGION" \
    --create-bucket-configuration "LocationConstraint=${REGION}" >/dev/null
fi

aws s3api put-bucket-versioning \
  --bucket "$STATE_BUCKET" \
  --versioning-configuration Status=Enabled >/dev/null

if ! aws dynamodb describe-table --table-name "$LOCK_TABLE" --region "$REGION" >/dev/null 2>&1; then
  aws dynamodb create-table \
    --table-name "$LOCK_TABLE" \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST \
    --region "$REGION" >/dev/null
fi

echo "Terraform backend ready:"
echo "  bucket=${STATE_BUCKET}"
echo "  lock_table=${LOCK_TABLE}"
