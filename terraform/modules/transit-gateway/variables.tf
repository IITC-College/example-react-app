variable "name" {
  description = "Short name prefix for TGW resources."
  type        = string
  default     = "hub"
}

variable "security_vpc_id" {
  type = string
}

variable "security_tgw_subnet_ids" {
  description = "Subnet IDs (one per AZ) in the Security VPC's tgw-attach subnet group."
  type        = list(string)
}

variable "frontend_vpc_id" {
  type = string
}

variable "frontend_tgw_subnet_ids" {
  description = "Subnet IDs (one per AZ) in the Frontend VPC's tgw-attach subnet group."
  type        = list(string)
}

variable "backend_vpc_id" {
  type = string
}

variable "backend_tgw_subnet_ids" {
  description = "Subnet IDs (one per AZ) in the Backend VPC's tgw-attach subnet group."
  type        = list(string)
}

variable "tags" {
  type    = map(string)
  default = {}
}
