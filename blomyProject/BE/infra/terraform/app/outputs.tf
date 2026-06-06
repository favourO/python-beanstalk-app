output "ecr_repository_url" {
  value = aws_ecr_repository.app.repository_url
}

output "alb_dns_name" {
  value = aws_lb.app.dns_name
}

output "service_name" {
  value = aws_ecs_service.app.name
}

output "cluster_name" {
  value = aws_ecs_cluster.app.name
}

output "app_url" {
  value = "https://${var.dns_name}"
}


output "alb_zone_id" {
  value = aws_lb.app.zone_id
}

output "dns_name" {
  value = var.dns_name
}

output "redis_endpoint" {
  value       = aws_elasticache_cluster.redis.cache_nodes[0].address
  description = "ElastiCache Redis endpoint used by Celery worker and beat"
}

output "certificate_validation_records" {
  value = var.certificate_arn != null && trimspace(var.certificate_arn) != "" ? [] : [
    for dvo in aws_acm_certificate.app[0].domain_validation_options : {
      domain_name = dvo.domain_name
      name        = dvo.resource_record_name
      type        = dvo.resource_record_type
      value       = dvo.resource_record_value
    }
  ]
}
