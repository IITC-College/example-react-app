locals {
  fortigate_instances = {
    primary = { subnet_id = var.firewall_subnet_ids[0], az = var.azs[0] }
    ha      = { subnet_id = var.firewall_subnet_ids[1], az = var.azs[1] }
  }
}

# --- Security groups ---------------------------------------------------

resource "aws_security_group" "alb" {
  name_prefix = "${var.name}-alb-"
  description = "Internet-facing ALB (fronted by Cloudflare)"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTP from allowed CIDRs"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.alb_ingress_cidrs
  }

  dynamic "ingress" {
    for_each = var.acm_certificate_arn == null ? [] : [1]
    content {
      description = "HTTPS from allowed CIDRs"
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = var.alb_ingress_cidrs
    }
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

resource "aws_security_group" "fortigate" {
  name_prefix = "${var.name}-fortigate-"
  description = "FortiGate data + management interface"
  vpc_id      = var.vpc_id

  # GENEVE (6081/udp) + health checks from the GWLB, sourced from anywhere
  # inside the VPC since GWLB endpoint ENIs live in the gwlbe subnets.
  ingress {
    description = "GENEVE from GWLB"
    from_port   = 6081
    to_port     = 6081
    protocol    = "udp"
    cidr_blocks = [var.vpc_cidr_block]
  }

  ingress {
    description = "Inspected traffic from within the VPC/attached spokes"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr_block, var.frontend_vpc_cidr, var.backend_vpc_cidr]
  }

  dynamic "ingress" {
    for_each = length(var.admin_ingress_cidrs) > 0 ? [1] : []
    content {
      description = "FortiGate management (HTTPS/SSH)"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = var.admin_ingress_cidrs
    }
  }

  dynamic "ingress" {
    for_each = length(var.admin_ingress_cidrs) > 0 ? [1] : []
    content {
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = var.admin_ingress_cidrs
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "${var.name}-fortigate-sg" })

  lifecycle {
    create_before_destroy = true
  }
}

# --- FortiGate HA pair ---------------------------------------------------

resource "aws_instance" "fortigate" {
  for_each = local.fortigate_instances

  ami                    = local.fortigate_ami_id
  instance_type           = var.fortigate_instance_type
  subnet_id               = each.value.subnet_id
  availability_zone       = each.value.az
  key_name                = var.fortigate_key_name
  vpc_security_group_ids = [aws_security_group.fortigate.id]
  source_dest_check       = false

  tags = merge(var.tags, {
    Name = "${var.name}-fortigate-${each.key}"
    Role = each.key
  })
}

# --- Gateway Load Balancer + FortiGate target group -----------------------

resource "aws_lb" "gwlb" {
  name               = "${var.name}-gwlb"
  load_balancer_type = "gateway"
  subnets             = var.firewall_subnet_ids

  tags = merge(var.tags, { Name = "${var.name}-gwlb" })
}

resource "aws_lb_target_group" "fortigate" {
  name        = "${var.name}-fortigate-tg"
  port        = 6081
  protocol    = "GENEVE"
  vpc_id      = var.vpc_id
  target_type = "instance"

  health_check {
    protocol = "TCP"
    port     = 22
  }

  tags = var.tags
}

resource "aws_lb_target_group_attachment" "fortigate" {
  for_each = aws_instance.fortigate

  target_group_arn = aws_lb_target_group.fortigate.arn
  target_id         = each.value.id
}

resource "aws_lb_listener" "gwlb" {
  load_balancer_arn = aws_lb.gwlb.arn
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.fortigate.arn
  }
}

resource "aws_vpc_endpoint_service" "gwlb" {
  acceptance_required        = false
  gateway_load_balancer_arns = [aws_lb.gwlb.arn]

  tags = merge(var.tags, { Name = "${var.name}-gwlb-endpoint-service" })
}

resource "aws_vpc_endpoint" "gwlbe" {
  for_each = { for idx, subnet_id in var.gwlbe_subnet_ids : var.azs[idx] => subnet_id }

  vpc_id             = var.vpc_id
  service_name        = aws_vpc_endpoint_service.gwlb.service_name
  vpc_endpoint_type   = "GatewayLoadBalancer"
  subnet_ids          = [each.value]

  tags = merge(var.tags, { Name = "${var.name}-gwlbe-${each.key}" })
}

# --- Internet-facing ALB: targets are the GWLB endpoint IPs, so every ------
# --- request is inspected by FortiGate before continuing on to the TGW. ---

resource "aws_lb" "internet" {
  name               = "${var.name}-alb"
  load_balancer_type = "application"
  internal            = false
  subnets             = var.public_subnet_ids
  security_groups    = [aws_security_group.alb.id]

  tags = merge(var.tags, { Name = "${var.name}-alb" })
}

resource "aws_lb_target_group" "gwlbe_ingress" {
  # ALB target groups only support HTTP/HTTPS (not TCP/UDP). The GWLB
  # endpoint forwards the underlying packets to FortiGate transparently
  # regardless of this L7 protocol setting.
  name        = "${var.name}-gwlbe-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    protocol = "HTTP"
    path      = "/"
    port     = 80
  }

  tags = var.tags
}

resource "aws_lb_target_group_attachment" "gwlbe_ingress" {
  for_each = data.aws_network_interface.gwlbe

  target_group_arn = aws_lb_target_group.gwlbe_ingress.arn
  target_id         = each.value.private_ip
  port               = 80
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.internet.arn
  port                = 80
  protocol            = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.gwlbe_ingress.arn
  }
}

resource "aws_lb_listener" "https" {
  count = var.acm_certificate_arn == null ? 0 : 1

  load_balancer_arn = aws_lb.internet.arn
  port                = 443
  protocol            = "HTTPS"
  ssl_policy          = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn    = var.acm_certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.gwlbe_ingress.arn
  }
}

# --- Firewall subnet routing: onward to TGW spokes, and back out to the ---
# --- internet via the NAT Gateway for centralized/inspected egress. -------
# NOTE: this wires the infrastructure path only. Actual FortiOS policies
# (allow/deny rules, SNAT/DNAT) must still be configured on the appliances.

resource "aws_route" "firewall_to_frontend" {
  route_table_id         = var.firewall_route_table_id
  destination_cidr_block = var.frontend_vpc_cidr
  transit_gateway_id      = var.transit_gateway_id
}

resource "aws_route" "firewall_to_backend" {
  route_table_id         = var.firewall_route_table_id
  destination_cidr_block = var.backend_vpc_cidr
  transit_gateway_id      = var.transit_gateway_id
}

resource "aws_route" "firewall_default_via_nat" {
  route_table_id         = var.firewall_route_table_id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id           = var.nat_gateway_id
}
