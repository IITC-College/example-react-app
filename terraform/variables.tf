variable "region" {
  type    = string
  default = "us-east-1"
}

variable "name_prefix" {
  type    = string
  default = "example-react-app"
}

variable "azs" {
  description = "Two Availability Zones to spread every VPC's subnets across. Must be in var.region."
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "security_vpc_cidr" {
  type    = string
  default = "10.0.0.0/22"
}

variable "frontend_vpc_cidr" {
  type    = string
  default = "10.1.0.0/20"
}

variable "backend_vpc_cidr" {
  type    = string
  default = "10.2.0.0/20"
}

# --- FortiGate ---------------------------------------------------------------

variable "fortigate_instance_type" {
  type    = string
  default = "c5.xlarge"
}

variable "fortigate_ami_id" {
  description = "Pin a specific FortiGate Marketplace AMI ID. Leave null to auto-discover the latest BYOL AMI (requires the Marketplace subscription to already exist)."
  type        = string
  default     = null
}

variable "fortigate_key_name" {
  description = "EC2 key pair for FortiGate SSH/console access."
  type        = string
  default     = null
}

variable "admin_ingress_cidrs" {
  description = "CIDRs allowed to reach FortiGate management (HTTPS/SSH). Empty disables management access entirely."
  type        = list(string)
  default     = []
}

variable "alb_ingress_cidrs" {
  description = "CIDRs allowed to reach the internet-facing ALB. Restrict to Cloudflare's published IP ranges in production: https://www.cloudflare.com/ips/"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "acm_certificate_arn" {
  description = "Optional ACM certificate ARN for HTTPS on the internet-facing ALB."
  type        = string
  default     = null
}

# --- Frontend / Backend app tiers --------------------------------------------

variable "app_instance_type" {
  type    = string
  default = "t3.medium"
}

variable "app_key_name" {
  type    = string
  default = null
}

# --- Databases -----------------------------------------------------------------

variable "docdb_instance_class" {
  type    = string
  default = "db.r6g.large"
}

variable "oracle_instance_class" {
  type    = string
  default = "db.r5.large"
}

# --- Cloudflare ---------------------------------------------------------------

variable "cloudflare_api_token" {
  description = "Cloudflare API token (scoped to DNS + WAF edit on the target zone). Prefer the CLOUDFLARE_API_TOKEN env var over setting this in a tfvars file."
  type        = string
  sensitive   = true
  default     = null
}

variable "cloudflare_zone_id" {
  description = "Cloudflare zone ID for the domain fronting the internet-facing ALB."
  type        = string
  default     = "CHANGEME-cloudflare-zone-id"
}

variable "cloudflare_record_name" {
  description = "DNS record name to create, e.g. \"app\" for app.example.com."
  type        = string
  default     = "app"
}

variable "tags" {
  type = map(string)
  default = {
    Project   = "example-react-app"
    ManagedBy = "terraform"
  }
}
