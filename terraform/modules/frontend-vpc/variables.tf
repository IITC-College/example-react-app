variable "name" {
  type    = string
  default = "frontend"
}

variable "vpc_id" {
  type = string
}

variable "vpc_cidr_block" {
  type = string
}

variable "app_subnet_ids" {
  description = "Subnets for the internal ALB and the frontend ASG (one per AZ)."
  type        = list(string)
}

variable "app_route_table_id" {
  description = "Route table ID shared by the app subnets, used to add the default route to the TGW."
  type        = string
}

variable "azs" {
  type = list(string)
}

variable "security_vpc_cidr" {
  description = "Security VPC CIDR (traffic to the internal ALB arrives via TGW from here)."
  type        = string
}

variable "transit_gateway_id" {
  type = string
}

variable "ami_id" {
  description = "AMI for the frontend Auto Scaling Group. Defaults to the latest Amazon Linux 2023 AMI."
  type        = string
  default     = null
}

variable "instance_type" {
  type    = string
  default = "t3.medium"
}

variable "key_name" {
  type    = string
  default = null
}

variable "min_size" {
  type    = number
  default = 2
}

variable "max_size" {
  type    = number
  default = 4
}

variable "desired_capacity" {
  type    = number
  default = 2
}

variable "tags" {
  type    = map(string)
  default = {}
}
