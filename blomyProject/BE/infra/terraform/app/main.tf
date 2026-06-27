locals {
  name_prefix              = "${var.project}-${var.environment}"
  app_name                 = "${local.name_prefix}-api"
  report_share_bucket_name = "${var.project}-${var.environment}-share-reports-${data.aws_caller_identity.current.account_id}"
  blog_media_bucket_name   = "${var.project}-${var.environment}-blog-media-${data.aws_caller_identity.current.account_id}"
  manage_route53_records   = var.route53_zone_id != null && trimspace(var.route53_zone_id) != ""
  use_provided_certificate = var.certificate_arn != null && trimspace(var.certificate_arn) != ""
  common_tags = merge(
    {
      Project     = var.project
      Environment = var.environment
      ManagedBy   = "terraform"
      Service     = "api"
    },
    var.tags,
  )

  plain_environment = merge(
    {
      PHORA_APP_NAME               = local.app_name
      PHORA_ENVIRONMENT            = var.environment
      PHORA_API_PREFIX             = "/api/v1"
      PHORA_API_PREFIX_LEGACY      = "/api/0.1.0"
      PHORA_ML_ENABLED             = "false"
      PHORA_ML_TIMEOUT_MS          = "5000"
      PHORA_ML_RETRY_COUNT         = "2"
      PHORA_ML_SHADOW_MODE         = "true"
      PHORA_AUTO_CREATE_TABLES     = "true"
      PHORA_HEALTH_SCHEMA          = "health"
      PHORA_BILLING_SCHEMA         = "billing"
      PHORA_AUDIT_SCHEMA           = "audit"
      PHORA_OTP_EXPIRATION_MINUTES = "10"
      PHORA_OTP_LENGTH             = "6"
      PHORA_PUBLIC_APP_URL         = "https://${var.dns_name}"
      PHORA_REPORT_SHARE_BUCKET    = aws_s3_bucket.report_shares.bucket
      PHORA_BLOG_MEDIA_BUCKET      = aws_s3_bucket.blog_media.bucket
    },
    var.extra_environment,
  )

  # Environment for Celery worker and beat — same as API plus the broker URL.
  # Kept separate so the API task definition does not depend on the Redis cluster.
  worker_environment = merge(
    local.plain_environment,
    {
      PHORA_BROKER_URL     = "redis://${aws_elasticache_cluster.redis.cache_nodes[0].address}:6379/1"
      PHORA_RESULT_BACKEND = "redis://${aws_elasticache_cluster.redis.cache_nodes[0].address}:6379/2"
    }
  )

  secret_environment = merge(
    {
      PHORA_SECRET_KEY                           = coalesce(var.app_secret_key, random_password.app_secret.result)
      PHORA_APPLE_BUNDLE_ID                      = ""
      PHORA_APPLE_SERVICE_ID                     = ""
      PHORA_APPLE_IAP_SHARED_SECRET              = ""
      PHORA_STRIPE_SECRET_KEY                    = ""
      PHORA_STRIPE_PUBLISHABLE_KEY               = ""
      PHORA_STRIPE_WEBHOOK_SECRET                = ""
      PHORA_FLUTTERWAVE_SECRET_KEY               = ""
      PHORA_FLUTTERWAVE_PUBLIC_KEY               = ""
      PHORA_FLUTTERWAVE_ENCRYPTION_KEY           = ""
      PHORA_FLUTTERWAVE_REDIRECT_URL             = ""
      PHORA_FLUTTERWAVE_WEBHOOK_SECRET_HASH      = ""
      PHORA_LLM_API_KEY                          = ""
      PHORA_FIREBASE_CREDENTIALS_JSON            = ""
      PHORA_GOOGLE_HEALTH_CLIENT_ID              = ""
      PHORA_GOOGLE_HEALTH_CLIENT_SECRET          = ""
      PHORA_GOOGLE_HEALTH_REDIRECT_URI           = ""
      PHORA_GOOGLE_HEALTH_OAUTH_SUCCESS_REDIRECT = "vyla://wearables/google-health?status=connected"
      PHORA_GOOGLE_HEALTH_OAUTH_ERROR_REDIRECT   = "vyla://wearables/google-health?status=error"
    },
    var.extra_secret_environment,
  )
}

data "aws_caller_identity" "current" {}

resource "random_password" "app_secret" {
  length  = 48
  special = false
}

resource "aws_ecr_repository" "app" {
  name                 = local.app_name
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = merge(local.common_tags, { Name = local.app_name })
}

resource "aws_cloudwatch_log_group" "app" {
  name              = "/ecs/${local.app_name}"
  retention_in_days = 14
  tags              = local.common_tags
}

resource "aws_ecs_cluster" "app" {
  name = "${local.name_prefix}-cluster"
  tags = merge(local.common_tags, { Name = "${local.name_prefix}-cluster" })
}

resource "aws_iam_role" "ecs_task_execution" {
  name = "${local.name_prefix}-ecs-execution"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_managed" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy" "ecs_task_execution_secrets" {
  name = "${local.name_prefix}-ecs-secrets"
  role = aws_iam_role.ecs_task_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "kms:Decrypt"
        ]
        Resource = ["${aws_secretsmanager_secret.app.arn}*", "${var.db_secret_arn}*"]
      }
    ]
  })
}

resource "aws_iam_role" "ecs_task" {
  name = "${local.name_prefix}-ecs-task"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy" "ecs_task_s3_media" {
  name = "${local.name_prefix}-ecs-task-s3-media"
  role = aws_iam_role.ecs_task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject"
        ]
        Resource = [
          "${aws_s3_bucket.report_shares.arn}/*",
          "${aws_s3_bucket.blog_media.arn}/*"
        ]
      }
    ]
  })
}

resource "aws_s3_bucket" "report_shares" {
  bucket = local.report_share_bucket_name
  tags   = merge(local.common_tags, { Name = local.report_share_bucket_name })
}

resource "aws_s3_bucket_public_access_block" "report_shares" {
  bucket = aws_s3_bucket.report_shares.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "report_shares" {
  bucket = aws_s3_bucket.report_shares.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "report_shares" {
  bucket = aws_s3_bucket.report_shares.id

  rule {
    id     = "expire-shared-reports"
    status = "Enabled"

    filter {}

    expiration {
      days = 7
    }
  }
}

resource "aws_s3_bucket" "blog_media" {
  bucket = local.blog_media_bucket_name
  tags   = merge(local.common_tags, { Name = local.blog_media_bucket_name })
}

resource "aws_s3_bucket_public_access_block" "blog_media" {
  bucket = aws_s3_bucket.blog_media.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "blog_media" {
  bucket = aws_s3_bucket.blog_media.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_secretsmanager_secret" "app" {
  name                    = "${local.name_prefix}/app-config"
  recovery_window_in_days = 7
  tags                    = merge(local.common_tags, { Name = "${local.name_prefix}-app-config" })
}

resource "aws_secretsmanager_secret_version" "app" {
  secret_id     = aws_secretsmanager_secret.app.id
  secret_string = jsonencode(local.secret_environment)

  lifecycle {
    ignore_changes = [secret_string]
  }
}

resource "aws_security_group" "alb" {
  name        = "${local.name_prefix}-alb"
  description = "ALB security group for ${local.name_prefix}"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-alb" })
}

resource "aws_security_group" "service" {
  name        = "${local.name_prefix}-service"
  description = "App security group for ${local.name_prefix}"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-service" })
}

resource "aws_vpc_security_group_ingress_rule" "service_from_alb" {
  security_group_id            = aws_security_group.service.id
  referenced_security_group_id = aws_security_group.alb.id
  from_port                    = var.app_port
  to_port                      = var.app_port
  ip_protocol                  = "tcp"
  description                  = "Allow ALB to reach ECS tasks"
}

resource "aws_vpc_security_group_ingress_rule" "db_from_service" {
  security_group_id            = var.db_security_group_id
  referenced_security_group_id = aws_security_group.service.id
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
  description                  = "Allow ECS tasks to reach Postgres"
}

resource "aws_lb" "app" {
  name               = replace(substr("${local.name_prefix}-alb", 0, 32), "_", "-")
  load_balancer_type = "application"
  internal           = false
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.public_subnet_ids

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-alb" })
}

resource "aws_lb_target_group" "app" {
  name        = replace(substr("${local.name_prefix}-tg", 0, 32), "_", "-")
  port        = var.app_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  deregistration_delay = 15

  health_check {
    path                = var.health_check_path
    healthy_threshold   = 2
    unhealthy_threshold = 5
    timeout             = 10
    interval            = 30
    matcher             = "200-399"
  }

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-tg" })
}

resource "aws_acm_certificate" "app" {
  count             = local.use_provided_certificate ? 0 : 1
  domain_name       = var.dns_name
  validation_method = "DNS"
  tags              = merge(local.common_tags, { Name = var.dns_name })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "cert_validation" {
  for_each = local.manage_route53_records && !local.use_provided_certificate ? {
    for dvo in aws_acm_certificate.app[0].domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  } : {}

  zone_id = var.route53_zone_id
  name    = each.value.name
  type    = each.value.type
  ttl     = 60
  records = [each.value.record]
}

resource "aws_acm_certificate_validation" "app" {
  count                   = local.manage_route53_records && !local.use_provided_certificate ? 1 : 0
  certificate_arn         = aws_acm_certificate.app[0].arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.app.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = local.use_provided_certificate ? var.certificate_arn : aws_acm_certificate.app[0].arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

resource "aws_route53_record" "app" {
  count   = local.manage_route53_records ? 1 : 0
  zone_id = var.route53_zone_id
  name    = var.dns_name
  type    = "A"

  alias {
    name                   = aws_lb.app.dns_name
    zone_id                = aws_lb.app.zone_id
    evaluate_target_health = true
  }
}

resource "aws_ecs_task_definition" "app" {
  family                   = local.app_name
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = tostring(var.cpu)
  memory                   = tostring(var.memory)
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([
    {
      name      = "api"
      image     = var.container_image
      essential = true
      portMappings = [
        {
          containerPort = var.app_port
          hostPort      = var.app_port
          protocol      = "tcp"
        }
      ]
      environment = [
        for key, value in local.plain_environment : {
          name  = key
          value = value
        }
      ]
      secrets = concat(
        [
          {
            name      = "PHORA_DATABASE_URL"
            valueFrom = "${var.db_secret_arn}:url::"
          }
        ],
        [
          for key, value in local.secret_environment : {
            name      = key
            valueFrom = "${aws_secretsmanager_secret.app.arn}:${key}::"
          }
        ]
      )
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.app.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "ecs"
        }
      }
    }
  ])

  tags = local.common_tags
}

resource "aws_ecs_service" "app" {
  name                              = local.app_name
  cluster                           = aws_ecs_cluster.app.id
  task_definition                   = aws_ecs_task_definition.app.arn
  desired_count                     = var.desired_count
  launch_type                       = "FARGATE"
  health_check_grace_period_seconds = 180

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  network_configuration {
    subnets          = var.public_subnet_ids
    security_groups  = [aws_security_group.service.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.app.arn
    container_name   = "api"
    container_port   = var.app_port
  }

  depends_on = [aws_lb_listener.https]

  tags = local.common_tags
}

# ── Redis (ElastiCache) for Celery broker ────────────────────────────────────

resource "aws_security_group" "redis" {
  name        = "${local.name_prefix}-redis"
  description = "Redis broker for ${local.name_prefix} Celery workers"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-redis" })
}

resource "aws_vpc_security_group_ingress_rule" "redis_from_service" {
  security_group_id            = aws_security_group.redis.id
  referenced_security_group_id = aws_security_group.service.id
  from_port                    = 6379
  to_port                      = 6379
  ip_protocol                  = "tcp"
  description                  = "Allow ECS tasks (API/worker/beat) to reach Redis"
}

resource "aws_elasticache_subnet_group" "redis" {
  name       = "${local.name_prefix}-redis"
  subnet_ids = var.public_subnet_ids
  tags       = merge(local.common_tags, { Name = "${local.name_prefix}-redis" })
}

resource "aws_elasticache_cluster" "redis" {
  cluster_id           = "${local.name_prefix}-redis"
  engine               = "redis"
  node_type            = "cache.t4g.micro"
  num_cache_nodes      = 1
  parameter_group_name = "default.redis7"
  engine_version       = "7.1"
  port                 = 6379
  subnet_group_name    = aws_elasticache_subnet_group.redis.name
  security_group_ids   = [aws_security_group.redis.id]
  tags                 = merge(local.common_tags, { Name = "${local.name_prefix}-redis" })
}

# ── Celery worker ────────────────────────────────────────────────────────────

resource "aws_cloudwatch_log_group" "worker" {
  name              = "/ecs/${local.name_prefix}-worker"
  retention_in_days = 14
  tags              = local.common_tags
}

resource "aws_ecs_task_definition" "worker" {
  family                   = "${local.name_prefix}-worker"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([
    {
      name      = "worker"
      image     = var.container_image
      essential = true
      command   = ["celery", "-A", "phora.workers.celery_app", "worker", "--loglevel=info", "-Q", "default,critical,low", "--concurrency=2"]
      environment = [
        for key, value in local.worker_environment : {
          name  = key
          value = value
        }
      ]
      secrets = concat(
        [{ name = "PHORA_DATABASE_URL", valueFrom = "${var.db_secret_arn}:url::" }],
        [for key, value in local.secret_environment : { name = key, valueFrom = "${aws_secretsmanager_secret.app.arn}:${key}::" }]
      )
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.worker.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "ecs"
        }
      }
    }
  ])

  tags = local.common_tags
}

resource "aws_ecs_service" "worker" {
  name            = "${local.name_prefix}-worker"
  cluster         = aws_ecs_cluster.app.id
  task_definition = aws_ecs_task_definition.worker.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  network_configuration {
    subnets          = var.public_subnet_ids
    security_groups  = [aws_security_group.service.id]
    assign_public_ip = true
  }

  tags = local.common_tags
}

# ── Celery beat scheduler ────────────────────────────────────────────────────

resource "aws_cloudwatch_log_group" "beat" {
  name              = "/ecs/${local.name_prefix}-beat"
  retention_in_days = 14
  tags              = local.common_tags
}

resource "aws_ecs_task_definition" "beat" {
  family                   = "${local.name_prefix}-beat"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([
    {
      name      = "beat"
      image     = var.container_image
      essential = true
      command   = ["celery", "-A", "phora.workers.celery_app", "beat", "--loglevel=info", "--scheduler=celery.beat:PersistentScheduler"]
      environment = [
        for key, value in local.worker_environment : {
          name  = key
          value = value
        }
      ]
      secrets = concat(
        [{ name = "PHORA_DATABASE_URL", valueFrom = "${var.db_secret_arn}:url::" }],
        [for key, value in local.secret_environment : { name = key, valueFrom = "${aws_secretsmanager_secret.app.arn}:${key}::" }]
      )
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.beat.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "ecs"
        }
      }
    }
  ])

  tags = local.common_tags
}

resource "aws_ecs_service" "beat" {
  name            = "${local.name_prefix}-beat"
  cluster         = aws_ecs_cluster.app.id
  task_definition = aws_ecs_task_definition.beat.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  network_configuration {
    subnets          = var.public_subnet_ids
    security_groups  = [aws_security_group.service.id]
    assign_public_ip = true
  }

  tags = local.common_tags
}
