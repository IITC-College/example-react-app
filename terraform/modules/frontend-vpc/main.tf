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
  description = "Frontend Auto Scaling Group instances"
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

# Default egress for the frontend app tier routes through the TGW to the
# Security VPC for centralized/inspected internet access.
resource "aws_route" "app_default_via_tgw" {
  route_table_id         = var.app_route_table_id
  destination_cidr_block = "0.0.0.0/0"
  transit_gateway_id      = var.transit_gateway_id
}
