# Hub-and-spoke Transit Gateway:
#  - Security VPC is the hub: it can reach both spokes and owns the shared
#    default route (spokes egress through it for centralized inspection).
#  - Frontend/Backend VPCs are spokes sharing one route table so they can
#    also reach each other directly through the TGW.

resource "aws_ec2_transit_gateway" "this" {
  description                    = "${var.name}-tgw"
  amazon_side_asn                 = 64512
  default_route_table_association = "disable"
  default_route_table_propagation = "disable"
  auto_accept_shared_attachments  = "disable"

  tags = merge(var.tags, {
    Name = "${var.name}-tgw"
  })
}

resource "aws_ec2_transit_gateway_vpc_attachment" "security" {
  transit_gateway_id = aws_ec2_transit_gateway.this.id
  vpc_id              = var.security_vpc_id
  subnet_ids          = var.security_tgw_subnet_ids

  transit_gateway_default_route_table_association = false
  transit_gateway_default_route_table_propagation  = false

  tags = merge(var.tags, {
    Name = "${var.name}-security-attachment"
  })
}

resource "aws_ec2_transit_gateway_vpc_attachment" "frontend" {
  transit_gateway_id = aws_ec2_transit_gateway.this.id
  vpc_id              = var.frontend_vpc_id
  subnet_ids          = var.frontend_tgw_subnet_ids

  transit_gateway_default_route_table_association = false
  transit_gateway_default_route_table_propagation  = false

  tags = merge(var.tags, {
    Name = "${var.name}-frontend-attachment"
  })
}

resource "aws_ec2_transit_gateway_vpc_attachment" "backend" {
  transit_gateway_id = aws_ec2_transit_gateway.this.id
  vpc_id              = var.backend_vpc_id
  subnet_ids          = var.backend_tgw_subnet_ids

  transit_gateway_default_route_table_association = false
  transit_gateway_default_route_table_propagation  = false

  tags = merge(var.tags, {
    Name = "${var.name}-backend-attachment"
  })
}

resource "aws_ec2_transit_gateway_route_table" "security" {
  transit_gateway_id = aws_ec2_transit_gateway.this.id

  tags = merge(var.tags, {
    Name = "${var.name}-security-rt"
  })
}

resource "aws_ec2_transit_gateway_route_table" "spoke" {
  transit_gateway_id = aws_ec2_transit_gateway.this.id

  tags = merge(var.tags, {
    Name = "${var.name}-spoke-rt"
  })
}

resource "aws_ec2_transit_gateway_route_table_association" "security" {
  transit_gateway_attachment_id = aws_ec2_transit_gateway_vpc_attachment.security.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.security.id
}

resource "aws_ec2_transit_gateway_route_table_association" "frontend" {
  transit_gateway_attachment_id = aws_ec2_transit_gateway_vpc_attachment.frontend.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.spoke.id
}

resource "aws_ec2_transit_gateway_route_table_association" "backend" {
  transit_gateway_attachment_id = aws_ec2_transit_gateway_vpc_attachment.backend.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.spoke.id
}

# Security RT learns routes to both spokes so return traffic from FortiGate
# inspection can reach Frontend/Backend.
resource "aws_ec2_transit_gateway_route_table_propagation" "security_learns_frontend" {
  transit_gateway_attachment_id = aws_ec2_transit_gateway_vpc_attachment.frontend.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.security.id
}

resource "aws_ec2_transit_gateway_route_table_propagation" "security_learns_backend" {
  transit_gateway_attachment_id = aws_ec2_transit_gateway_vpc_attachment.backend.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.security.id
}

# Spoke RT learns routes to both spokes (so Frontend <-> Backend works
# directly) and gets a static default route to the Security VPC for
# centralized/inspected internet egress.
resource "aws_ec2_transit_gateway_route_table_propagation" "spoke_learns_frontend" {
  transit_gateway_attachment_id = aws_ec2_transit_gateway_vpc_attachment.frontend.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.spoke.id
}

resource "aws_ec2_transit_gateway_route_table_propagation" "spoke_learns_backend" {
  transit_gateway_attachment_id = aws_ec2_transit_gateway_vpc_attachment.backend.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.spoke.id
}

resource "aws_ec2_transit_gateway_route" "spoke_default_via_security" {
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.spoke.id
  destination_cidr_block          = "0.0.0.0/0"
  transit_gateway_attachment_id    = aws_ec2_transit_gateway_vpc_attachment.security.id
}
