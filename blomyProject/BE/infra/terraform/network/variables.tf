variable "aws_region" {
  description = "AWS region for the prod VPC baseline."
  type        = string
  default     = "eu-west-2"
}

variable "aws_account_id" {
  description = "Expected AWS account ID for this stack."
  type        = string
}

variable "project" {
  description = "Project name used in tags and resource names."
  type        = string
  default     = "vyla"
}

variable "environment" {
  description = "Deployment environment name."
  type        = string
  default     = "prod"
}

variable "vpc_cidr" {
  description = "CIDR block for the prod VPC."
  type        = string
  default     = "10.42.0.0/16"
}

variable "availability_zones" {
  description = "Availability zones used for the lean prod network."
  type        = list(string)
  default     = ["eu-west-2a", "eu-west-2b"]
}

variable "public_subnet_cidrs" {
  description = "CIDRs for the public subnets used by ALB and app tasks."
  type        = list(string)
  default     = ["10.42.0.0/20", "10.42.16.0/20"]
}

variable "private_subnet_cidrs" {
  description = "CIDRs for the private subnets used by RDS."
  type        = list(string)
  default     = ["10.42.128.0/20", "10.42.144.0/20"]
}

variable "tags" {
  description = "Additional tags for all resources."
  type        = map(string)
  default     = {}
}
