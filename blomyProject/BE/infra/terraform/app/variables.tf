variable "aws_region" {
  type    = string
  default = "eu-west-2"
}

variable "project" {
  type    = string
  default = "vyla"
}

variable "aws_account_id" {
  type = string
}

variable "environment" {
  type = string
}

variable "dns_name" {
  type = string
}

variable "route53_zone_id" {
  type    = string
  default = null
}

variable "certificate_arn" {
  type    = string
  default = null
}

variable "vpc_id" {
  type = string
}

variable "public_subnet_ids" {
  type = list(string)
}

variable "db_security_group_id" {
  type = string
}

variable "db_secret_arn" {
  type = string
}

variable "container_image" {
  type    = string
  default = "public.ecr.aws/docker/library/python:3.12-slim"
}

variable "app_port" {
  type    = number
  default = 8000
}

variable "desired_count" {
  type    = number
  default = 1
}

variable "cpu" {
  type    = number
  default = 256
}

variable "memory" {
  type    = number
  default = 512
}

variable "health_check_path" {
  type    = string
  default = "/api/v1/health"
}

variable "app_secret_key" {
  type      = string
  default   = null
  sensitive = true
}

variable "extra_environment" {
  type    = map(string)
  default = {}
}

variable "extra_secret_environment" {
  type      = map(string)
  default   = {}
  sensitive = true
}

variable "tags" {
  type    = map(string)
  default = {}
}
