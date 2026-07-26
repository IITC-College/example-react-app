variable "name" {
  description = "Short name for this VPC, used as a prefix for resource names/tags (e.g. \"security\", \"frontend\", \"backend\")."
  type        = string
}

variable "cidr_block" {
  description = "IPv4 CIDR block for the VPC."
  type        = string
}

variable "azs" {
  description = "Availability zones to spread subnets across. Length must match the number of cidr_blocks in each subnet group."
  type        = list(string)
}

variable "subnet_groups" {
  description = <<-EOT
    Map of subnet-group name (e.g. "public", "app", "db", "tgw-attach") to its config.
    `cidr_blocks` must have one entry per AZ in var.azs.
    `public` groups get a default route to the Internet Gateway.
  EOT
  type = map(object({
    cidr_blocks = list(string)
    public      = bool
  }))
}

variable "create_igw" {
  description = "Whether to create an Internet Gateway for this VPC."
  type        = bool
  default     = false
}

variable "create_nat_gateway" {
  description = "Whether to create a single NAT Gateway (in the first public subnet) for this VPC."
  type        = bool
  default     = false
}

variable "nat_route_group_names" {
  description = "Subnet-group names that should receive a 0.0.0.0/0 route to the NAT Gateway (requires create_nat_gateway = true)."
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Common tags applied to all resources in this module."
  type        = map(string)
  default     = {}
}
