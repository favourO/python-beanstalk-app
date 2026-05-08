# Terraform: Vyla Prod Network Baseline

This stack creates the lean prod network baseline in AWS account `329937296512` and region `eu-west-2`.

## What it creates

- one VPC
- two public subnets for the internet-facing ALB and ECS tasks
- two private subnets for RDS
- one internet gateway
- one NAT gateway
- one public route table and one private route table with subnet associations

## What it does not create

- no ECS service
- no ALB listeners
- no RDS
- no extra networking services

This is intentional. The goal is to keep phase 2 minimal and feed clean outputs into later prod app and prod DB stacks.

## Usage

```bash
cd infra/terraform/network
cp prod.tfvars.example prod.tfvars
terraform init
terraform plan -var-file=prod.tfvars
terraform apply -var-file=prod.tfvars
```

## Outputs used later

- `vpc_id`
- `public_subnet_ids`
- `private_subnet_ids`

Feed these outputs into:

- `infra/terraform/app/envs/prod.tfvars`
- `infra/terraform/prod.tfvars`
