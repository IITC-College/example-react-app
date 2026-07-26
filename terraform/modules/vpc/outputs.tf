output "vpc_id" {
  value = aws_vpc.this.id
}

output "vpc_cidr_block" {
  value = aws_vpc.this.cidr_block
}

output "subnet_ids" {
  description = "Map of subnet-group name to an ordered list of subnet IDs (one per AZ)."
  value = {
    for g in keys(var.subnet_groups) : g => [for az in var.azs : aws_subnet.this["${g}-${az}"].id]
  }
}

output "route_table_ids" {
  description = "Map of subnet-group name to its route table ID."
  value       = { for g, rt in aws_route_table.this : g => rt.id }
}

output "internet_gateway_id" {
  value = try(aws_internet_gateway.this[0].id, null)
}

output "nat_gateway_id" {
  value = try(aws_nat_gateway.this[0].id, null)
}
