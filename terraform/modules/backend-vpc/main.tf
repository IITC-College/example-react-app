# --- App tier: internal ALB + ECS Fargate service (backend servers) -------

data "aws_region" "current" {}

resource "aws_security_group" "alb" {
  name_prefix = "${var.name}-alb-"
  description = "Internal ALB for the backend target group"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTP from Frontend VPC (via TGW) and within this VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.frontend_vpc_cidr, var.vpc_cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "${var.name}-alb-sg" })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group" "app" {
  name_prefix = "${var.name}-app-"
  description = "Backend Fargate service"
  vpc_id      = var.vpc_id

  ingress {
    description       = "App port from the internal ALB"
    from_port         = var.container_port
    to_port           = var.container_port
    protocol          = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "${var.name}-app-sg" })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group" "db" {
  name_prefix = "${var.name}-db-"
  description = "DocumentDB + RDS Oracle, reachable only from the backend app tier"
  vpc_id      = var.vpc_id

  ingress {
    description       = "DocumentDB from backend app tier"
    from_port         = 27017
    to_port           = 27017
    protocol          = "tcp"
    security_groups = [aws_security_group.app.id]
  }

  ingress {
    description       = "Oracle from backend app tier"
    from_port         = 1521
    to_port           = 1521
    protocol          = "tcp"
    security_groups = [aws_security_group.app.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "${var.name}-db-sg" })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group" "redis" {
  name_prefix = "${var.name}-redis-"
  description = "ElastiCache Redis, reachable only from the backend app tier"
  vpc_id      = var.vpc_id

  ingress {
    description       = "Redis from backend app tier"
    from_port         = var.redis_port
    to_port           = var.redis_port
    protocol          = "tcp"
    security_groups = [aws_security_group.app.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "${var.name}-redis-sg" })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_lb" "internal" {
  name               = "${var.name}-internal-alb"
  load_balancer_type = "application"
  internal            = true
  subnets             = var.app_subnet_ids
  security_groups    = [aws_security_group.alb.id]

  tags = merge(var.tags, { Name = "${var.name}-internal-alb" })
}

resource "aws_lb_target_group" "app" {
  name        = "${var.name}-tg"
  port        = var.container_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    path                = "/health"
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  tags = var.tags
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.internal.arn
  port                = 80
  protocol            = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

# --- ECS Fargate -------------------------------------------------------------

resource "aws_ecr_repository" "this" {
  name                 = "${var.name}-app"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = var.tags
}

resource "aws_ecs_cluster" "this" {
  name = "${var.name}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = var.tags
}

resource "aws_cloudwatch_log_group" "this" {
  name              = "/ecs/${var.name}"
  retention_in_days = var.log_retention_days
  tags              = var.tags
}

data "aws_iam_policy_document" "ecs_tasks_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "execution" {
  name               = "${var.name}-ecs-execution"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume_role.json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "execution" {
  role       = aws_iam_role.execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role" "task" {
  name               = "${var.name}-ecs-task"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume_role.json
  tags               = var.tags
}

resource "aws_ecs_task_definition" "app" {
  family                    = "${var.name}-app"
  requires_compatibilities = ["FARGATE"]
  network_mode              = "awsvpc"
  cpu                        = var.task_cpu
  memory                     = var.task_memory
  execution_role_arn        = aws_iam_role.execution.arn
  task_role_arn              = aws_iam_role.task.arn

  container_definitions = jsonencode([
    {
      name      = var.name
      image     = "${aws_ecr_repository.this.repository_url}:${var.image_tag}"
      essential = true
      portMappings = [
        {
          containerPort = var.container_port
          protocol       = "tcp"
        }
      ]
      environment = [
        { name = "PORT", value = tostring(var.container_port) },
        { name = "DOCUMENTDB_ENDPOINT", value = aws_docdb_cluster.this.endpoint },
        { name = "DOCUMENTDB_SECRET_ARN", value = aws_secretsmanager_secret.docdb.arn },
        { name = "ORACLE_ENDPOINT", value = aws_db_instance.oracle.endpoint },
        { name = "ORACLE_SECRET_ARN", value = aws_secretsmanager_secret.oracle.arn },
        { name = "REDIS_PRIMARY_ENDPOINT", value = aws_elasticache_replication_group.this.primary_endpoint_address },
        { name = "REDIS_SECRET_ARN", value = aws_secretsmanager_secret.redis.arn },
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"          = aws_cloudwatch_log_group.this.name
          "awslogs-region"          = data.aws_region.current.name
          "awslogs-stream-prefix" = var.name
        }
      }
    }
  ])

  tags = var.tags
}

resource "aws_ecs_service" "app" {
  name                 = "${var.name}-service"
  cluster               = aws_ecs_cluster.this.id
  task_definition       = aws_ecs_task_definition.app.arn
  desired_count        = var.desired_count
  launch_type           = "FARGATE"

  network_configuration {
    subnets            = var.app_subnet_ids
    security_groups    = [aws_security_group.app.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.app.arn
    container_name    = var.name
    container_port    = var.container_port
  }

  # CI/CD registers new task definition revisions and updates the service
  # directly (see the root README) — Terraform owns the service's shape,
  # not which image revision is currently running.
  lifecycle {
    ignore_changes = [task_definition]
  }

  depends_on = [aws_lb_listener.http]

  tags = var.tags
}

# Task role gets read-only access to exactly the three secrets it needs at
# runtime — nothing broader.
resource "aws_iam_role_policy" "task_secrets" {
  name = "${var.name}-task-secrets"
  role = aws_iam_role.task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = [
          aws_secretsmanager_secret.docdb.arn,
          aws_secretsmanager_secret.oracle.arn,
          aws_secretsmanager_secret.redis.arn,
        ]
      }
    ]
  })
}

resource "aws_route" "app_default_via_tgw" {
  route_table_id         = var.app_route_table_id
  destination_cidr_block = "0.0.0.0/0"
  transit_gateway_id      = var.transit_gateway_id
}

# --- DocumentDB -------------------------------------------------------------

resource "random_password" "docdb" {
  length           = 24
  special          = true
  override_special = "!#$%^&*()-_=+[]{}<>:?"
}

resource "aws_secretsmanager_secret" "docdb" {
  name = "${var.name}-docdb-credentials"
  tags = var.tags
}

resource "aws_secretsmanager_secret_version" "docdb" {
  secret_id = aws_secretsmanager_secret.docdb.id
  secret_string = jsonencode({
    username = var.docdb_master_username
    password = random_password.docdb.result
  })
}

resource "aws_docdb_subnet_group" "this" {
  name       = "${var.name}-docdb"
  subnet_ids = var.db_subnet_ids
  tags       = var.tags
}

resource "aws_docdb_cluster" "this" {
  cluster_identifier      = "${var.name}-docdb"
  engine                    = "docdb"
  engine_version            = var.docdb_engine_version
  master_username           = var.docdb_master_username
  master_password           = random_password.docdb.result
  db_subnet_group_name       = aws_docdb_subnet_group.this.name
  vpc_security_group_ids    = [aws_security_group.db.id]
  storage_encrypted        = true
  skip_final_snapshot       = var.docdb_skip_final_snapshot
  final_snapshot_identifier = var.docdb_skip_final_snapshot ? null : "${var.name}-docdb-final"

  tags = var.tags
}

resource "aws_docdb_cluster_instance" "this" {
  count = var.docdb_instance_count

  identifier              = "${var.name}-docdb-${count.index}"
  cluster_identifier       = aws_docdb_cluster.this.id
  instance_class           = var.docdb_instance_class
  availability_zone       = var.azs[count.index % length(var.azs)]

  tags = var.tags
}

# --- RDS Oracle (Multi-AZ) ---------------------------------------------------

resource "random_password" "oracle" {
  length           = 24
  special          = true
  override_special = "!#$%^&*()-_=+[]{}<>:?"
}

resource "aws_secretsmanager_secret" "oracle" {
  name = "${var.name}-oracle-credentials"
  tags = var.tags
}

resource "aws_secretsmanager_secret_version" "oracle" {
  secret_id = aws_secretsmanager_secret.oracle.id
  secret_string = jsonencode({
    username = var.oracle_master_username
    password = random_password.oracle.result
  })
}

resource "aws_db_subnet_group" "oracle" {
  name       = "${var.name}-oracle"
  subnet_ids = var.db_subnet_ids
  tags       = var.tags
}

resource "aws_db_instance" "oracle" {
  identifier              = "${var.name}-oracle"
  engine                    = var.oracle_engine
  engine_version            = var.oracle_engine_version
  license_model             = var.oracle_license_model
  instance_class           = var.oracle_instance_class
  allocated_storage       = var.oracle_allocated_storage
  storage_encrypted        = true
  multi_az                 = var.oracle_multi_az
  username                  = var.oracle_master_username
  password                  = random_password.oracle.result
  db_subnet_group_name       = aws_db_subnet_group.oracle.name
  vpc_security_group_ids    = [aws_security_group.db.id]
  skip_final_snapshot       = var.oracle_skip_final_snapshot
  final_snapshot_identifier = var.oracle_skip_final_snapshot ? null : "${var.name}-oracle-final"

  tags = var.tags
}

# --- ElastiCache Redis (replication group, Multi-AZ automatic failover) -----

resource "random_password" "redis" {
  length           = 24
  special          = true
  override_special = "!#$%^&*()-_=+[]{}<>:?" # ElastiCache auth tokens forbid @ " / and spaces; none of these are in this set.
}

resource "aws_secretsmanager_secret" "redis" {
  name = "${var.name}-redis-credentials"
  tags = var.tags
}

resource "aws_secretsmanager_secret_version" "redis" {
  secret_id = aws_secretsmanager_secret.redis.id
  secret_string = jsonencode({
    auth_token = random_password.redis.result
  })
}

resource "aws_elasticache_subnet_group" "this" {
  name       = "${var.name}-redis"
  subnet_ids = var.db_subnet_ids
  tags       = var.tags
}

resource "aws_elasticache_replication_group" "this" {
  replication_group_id       = "${var.name}-redis"
  description                 = "${var.name} Redis cache (Multi-AZ, automatic failover)"
  engine                       = "redis"
  engine_version               = var.redis_engine_version
  node_type                    = var.redis_node_type
  port                          = var.redis_port
  num_cache_clusters          = var.redis_num_cache_clusters
  automatic_failover_enabled = true
  multi_az_enabled            = true
  subnet_group_name           = aws_elasticache_subnet_group.this.name
  security_group_ids          = [aws_security_group.redis.id]
  at_rest_encryption_enabled = true
  transit_encryption_enabled = true
  auth_token                  = random_password.redis.result

  tags = var.tags
}
