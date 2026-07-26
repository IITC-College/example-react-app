data "aws_region" "current" {}

resource "aws_security_group" "alb" {
  name_prefix = "${var.name}-alb-"
  description = "Internal ALB for the frontend target groups"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTP from Security VPC (via TGW) and within this VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.security_vpc_cidr, var.vpc_cidr_block]
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
  description = "Frontend Fargate service"
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
    path                = "/api/health"
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

# --- ECS Fargate ---------------------------------------------------------

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
        { name = "PORT", value = tostring(var.container_port) }
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

# Default egress for the frontend app tier routes through the TGW to the
# Security VPC for centralized/inspected internet access.
resource "aws_route" "app_default_via_tgw" {
  route_table_id         = var.app_route_table_id
  destination_cidr_block = "0.0.0.0/0"
  transit_gateway_id      = var.transit_gateway_id
}
