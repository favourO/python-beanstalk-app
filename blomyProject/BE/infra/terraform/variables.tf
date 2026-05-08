variable "aws_region" {
  description = "AWS region for the RDS deployment."
  type        = string
  default     = "eu-west-2"
}

variable "project" {
  description = "Project name used in tags and resource names."
  type        = string
  default     = "vyla"
}

variable "aws_account_id" {
  description = "Expected AWS account ID for this stack."
  type        = string
}

variable "environment" {
  description = "Deployment environment name."
  type        = string
  default     = "dev"
}

variable "vpc_id" {
  description = "Existing VPC ID for the database."
  type        = string
}

variable "private_subnet_ids" {
  description = "Existing private subnet IDs for the DB subnet group."
  type        = list(string)
}

variable "allowed_security_group_ids" {
  description = "Application security groups allowed to connect to Postgres on 5432."
  type        = list(string)
  default     = []
}

variable "allowed_cidr_blocks" {
  description = "CIDR ranges allowed to connect to Postgres on 5432. Keep this empty unless strictly needed."
  type        = list(string)
  default     = []
}

variable "db_name" {
  description = "Initial PostgreSQL database name."
  type        = string
  default     = "vyla"
}

variable "db_username" {
  description = "Master username for PostgreSQL."
  type        = string
  default     = "vyla_admin"
}

variable "db_port" {
  description = "PostgreSQL listener port."
  type        = number
  default     = 5432
}

variable "engine_version" {
  description = "PostgreSQL engine version."
  type        = string
  default     = "16.13"
}

variable "instance_class" {
  description = "RDS instance class."
  type        = string
  default     = "db.t4g.micro"
}

variable "allocated_storage" {
  description = "Allocated storage in GiB."
  type        = number
  default     = 20
}

variable "max_allocated_storage" {
  description = "Autoscaling storage ceiling in GiB."
  type        = number
  default     = 100
}

variable "storage_type" {
  description = "RDS storage type."
  type        = string
  default     = "gp3"
}

variable "storage_encrypted" {
  description = "Whether storage encryption is enabled."
  type        = bool
  default     = true
}

variable "multi_az" {
  description = "Whether to run the instance in Multi-AZ mode."
  type        = bool
  default     = false
}

variable "backup_retention_period" {
  description = "Days to retain automated backups."
  type        = number
  default     = 1
}

variable "backup_window" {
  description = "Preferred backup window in UTC."
  type        = string
  default     = "02:00-03:00"
}

variable "maintenance_window" {
  description = "Preferred maintenance window in UTC."
  type        = string
  default     = "sun:03:00-sun:04:00"
}

variable "deletion_protection" {
  description = "Whether to enable deletion protection."
  type        = bool
  default     = false
}

variable "skip_final_snapshot" {
  description = "Whether to skip the final snapshot on destroy."
  type        = bool
  default     = true
}

variable "performance_insights_enabled" {
  description = "Whether to enable Performance Insights."
  type        = bool
  default     = false
}

variable "monitoring_interval" {
  description = "Enhanced monitoring interval in seconds. Set 0 to disable."
  type        = number
  default     = 0
}

variable "apply_immediately" {
  description = "Whether modifications are applied immediately."
  type        = bool
  default     = true
}

variable "secret_recovery_window_in_days" {
  description = "Recovery window for Secrets Manager secret deletion."
  type        = number
  default     = 7
}

variable "tags" {
  description = "Additional tags for all resources."
  type        = map(string)
  default     = {}
}
