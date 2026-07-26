output "transit_gateway_id" {
  value = aws_ec2_transit_gateway.this.id
}

output "security_attachment_id" {
  value = aws_ec2_transit_gateway_vpc_attachment.security.id
}

output "frontend_attachment_id" {
  value = aws_ec2_transit_gateway_vpc_attachment.frontend.id
}

output "backend_attachment_id" {
  value = aws_ec2_transit_gateway_vpc_attachment.backend.id
}

output "security_route_table_id" {
  value = aws_ec2_transit_gateway_route_table.security.id
}

output "spoke_route_table_id" {
  value = aws_ec2_transit_gateway_route_table.spoke.id
}
