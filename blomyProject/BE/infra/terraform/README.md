# Terraform: Vyla AWS RDS PostgreSQL

This stack provisions the cheap persistent prod PostgreSQL layer for Vyla and assumes the prod network already exists.
The defaults are intentionally cost-minimized for the new prod account `329937296512` in `eu-west-2`.

This is phase 3 infrastructure and depends on the phase 2 network baseline in [`infra/terraform/network`](/Users/mac/blomyProject/BE/infra/terraform/network/README.md).

## What it creates

- one on-demand `aws_db_instance` for PostgreSQL 16
- one DB subnet group using existing private subnets
- one security group for Postgres access
- one parameter group with basic connection and slow-query logging
- one Secrets Manager secret containing username, password, host, port, db name, and SQLAlchemy URL
- one IAM role for RDS enhanced monitoring when monitoring is enabled

## Inputs you must provide

- `vpc_id`
- `private_subnet_ids`
- `aws_account_id`
- at least one of:
  - `allowed_security_group_ids`
  - `allowed_cidr_blocks`

## Usage

```bash
  cd infra/terraform
  cp terraform.tfvars.example terraform.tfvars
  terraform init
  terraform plan
  terraform apply
```

## Outputs

Use either:

- `db_secret_arn` and fetch the credentials from Secrets Manager at runtime
- `sqlalchemy_database_url` for a direct backend environment value

Example backend env:

```env
PHORA_DATABASE_URL=postgresql+psycopg://vyla_admin:<password>@<endpoint>:5432/vyla
```

## Notes

- The DB is private-only: `publicly_accessible = false`.
- Defaults are cost-minimized: `db.t4g.micro`, 20 GiB gp3, single-AZ, 1-day backups, no Performance Insights, no Enhanced Monitoring.
- Deletion protection is disabled by default to stay aligned with the low-cost prod baseline requested for the migration.
- Final snapshot is skipped by default to stay aligned with the low-cost prod baseline requested for the migration.
- The backend will need the `psycopg` PostgreSQL driver in its Python environment before switching from SQLite to RDS.
