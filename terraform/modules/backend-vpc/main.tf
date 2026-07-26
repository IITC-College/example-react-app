# --- App tier: internal ALB + ASG (backend servers) -----------------------

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
  description = "Backend Auto Scaling Group instances"
  vpc_id      = var.vpc_id

  ingress {
    description       = "HTTP from the internal ALB"
    from_port         = 80
    to_port           = 80
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
  name     = "${var.name}-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    path                = "/"
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

resource "aws_launch_template" "app" {
  name_prefix   = "${var.name}-app-"
  image_id      = local.ami_id
  instance_type = var.instance_type
  key_name      = var.key_name

  vpc_security_group_ids = [aws_security_group.app.id]

  tag_specifications {
    resource_type = "instance"
    tags          = merge(var.tags, { Name = "${var.name}-app" })
  }
}

resource "aws_autoscaling_group" "app" {
  name                 = "${var.name}-asg"
  vpc_zone_identifier = var.app_subnet_ids
  target_group_arns   = [aws_lb_target_group.app.arn]
  health_check_type    = "ELB"
  min_size              = var.min_size
  max_size              = var.max_size
  desired_capacity     = var.desired_capacity

  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }

  dynamic "tag" {
    for_each = merge(var.tags, { Name = "${var.name}-asg" })
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }
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
