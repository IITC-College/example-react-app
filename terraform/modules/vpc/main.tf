locals {
  subnet_entries = merge([
    for group_name, group in var.subnet_groups : {
      for idx, cidr in group.cidr_blocks :
      "${group_name}-${var.azs[idx]}" => {
        group_name = group_name
        cidr_block = cidr
        az         = var.azs[idx]
        public     = group.public
      }
    }
  ]...)

  first_public_group = try([for k, v in var.subnet_groups : k if v.public][0], null)
}

resource "aws_vpc" "this" {
  cidr_block           = var.cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(var.tags, {
    Name = "${var.name}-vpc"
  })
}

resource "aws_subnet" "this" {
  for_each = local.subnet_entries

  vpc_id                  = aws_vpc.this.id
  cidr_block               = each.value.cidr_block
  availability_zone         = each.value.az
  map_public_ip_on_launch = each.value.public

  tags = merge(var.tags, {
    Name = "${var.name}-${each.key}"
    Tier = each.value.group_name
  })
}

resource "aws_internet_gateway" "this" {
  count = var.create_igw ? 1 : 0

  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, {
    Name = "${var.name}-igw"
  })
}

resource "aws_route_table" "this" {
  for_each = var.subnet_groups

  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, {
    Name = "${var.name}-${each.key}-rt"
  })
}

resource "aws_route_table_association" "this" {
  for_each = local.subnet_entries

  subnet_id      = aws_subnet.this[each.key].id
  route_table_id = aws_route_table.this[each.value.group_name].id
}

resource "aws_route" "public_igw" {
  for_each = var.create_igw ? { for k, v in var.subnet_groups : k => v if v.public } : {}

  route_table_id         = aws_route_table.this[each.key].id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id              = aws_internet_gateway.this[0].id
}

resource "aws_eip" "nat" {
  count  = var.create_nat_gateway ? 1 : 0
  domain = "vpc"

  tags = merge(var.tags, {
    Name = "${var.name}-nat-eip"
  })
}

resource "aws_nat_gateway" "this" {
  count = var.create_nat_gateway ? 1 : 0

  allocation_id = aws_eip.nat[0].id
  subnet_id     = aws_subnet.this["${local.first_public_group}-${var.azs[0]}"].id

  tags = merge(var.tags, {
    Name = "${var.name}-nat"
  })

  depends_on = [aws_internet_gateway.this]
}

resource "aws_route" "nat" {
  for_each = var.create_nat_gateway ? toset(var.nat_route_group_names) : toset([])

  route_table_id         = aws_route_table.this[each.value].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id           = aws_nat_gateway.this[0].id
}
