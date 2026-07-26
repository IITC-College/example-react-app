data "aws_ami" "fortigate" {
  count = var.fortigate_ami_id == null ? 1 : 0

  most_recent = true
  owners      = ["aws-marketplace"]

  filter {
    name   = "name"
    values = [var.fortigate_ami_name_filter]
  }
}

locals {
  fortigate_ami_id = coalesce(var.fortigate_ami_id, try(data.aws_ami.fortigate[0].id, null))
}

# GWLB endpoint IPs are needed as "ip" targets for the internet-facing ALB
# (the "ALB + GWLB sandwich" ingress-inspection pattern).
data "aws_network_interface" "gwlbe" {
  for_each = aws_vpc_endpoint.gwlbe

  id = each.value.network_interface_ids[0]
}
