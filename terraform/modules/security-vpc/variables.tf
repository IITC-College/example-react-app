variable "name" {
  type    = string
  default = "security"
}

variable "vpc_id" {
  type = string
}

variable "vpc_cidr_block" {
  type = string
}

variable "public_subnet_ids" {
  description = "Subnets for the internet-facing ALB (one per AZ)."
  type        = list(string)
}

variable "gwlbe_subnet_ids" {
  description = "Subnets for the Gateway Load Balancer VPC Endpoints (one per AZ)."
  type        = list(string)
}

variable "firewall_subnet_ids" {
  description = "Subnets for the FortiGate instances and the GWLB itself (one per AZ)."
  type        = list(string)
}

variable "firewall_route_table_id" {
  description = "Route table ID shared by the firewall subnets, used to add TGW/NAT routes."
  type        = string
}

variable "nat_gateway_id" {
  description = "NAT Gateway ID (in the public subnet) used for the firewall subnets' default internet route."
  type        = string
}

variable "transit_gateway_id" {
  type = string
}

variable "transit_gateway_attachment_id" {
  description = "Security VPC's TGW attachment ID (ensures the TGW routes below aren't created before the attachment exists)."
  type        = string
}

variable "frontend_vpc_cidr" {
  type = string
}

variable "backend_vpc_cidr" {
  type = string
}

variable "azs" {
  type = list(string)
}

variable "fortigate_instance_type" {
  type    = string
  default = "c5.xlarge"
}

variable "fortigate_ami_id" {
  description = "Pin a specific FortiGate Marketplace AMI ID. Leave null to look up the most recent AMI matching fortigate_ami_name_filter (requires the FortiGate BYOL product to already be subscribed to in AWS Marketplace)."
  type        = string
  default     = null
}

variable "fortigate_ami_name_filter" {
  type    = string
  default = "FortiGate-VM64-AWSONDEMAND*"
}

variable "fortigate_key_name" {
  description = "EC2 key pair name for FortiGate SSH/console access."
  type        = string
  default     = null
}

variable "admin_ingress_cidrs" {
  description = "CIDRs allowed to reach FortiGate management (HTTPS/SSH)."
  type        = list(string)
  default     = []
}

variable "alb_ingress_cidrs" {
  description = "CIDRs allowed to reach the internet-facing ALB. Restrict to Cloudflare's published IP ranges in production."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "acm_certificate_arn" {
  description = "Optional ACM certificate ARN for an HTTPS listener on the internet-facing ALB. If null, only an HTTP:80 listener is created (terminate TLS at Cloudflare instead)."
  type        = string
  default     = null
}

variable "tags" {
  type    = map(string)
  default = {}
}
