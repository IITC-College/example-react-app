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

# --- Frontend / Backend app tiers (ECS Fargate) ------------------------------

variable "frontend_image_tag" {
  description = "Image tag to deploy from the frontend ECR repo. Set by CI/CD on each deploy."
  type        = string
  default     = "latest"
}

variable "backend_image_tag" {
  description = "Image tag to deploy from the backend ECR repo. Set by CI/CD on each deploy."
  type        = string
  default     = "latest"
}

variable "app_task_cpu" {
  description = "Fargate task vCPU units (256 = 0.25 vCPU), used by both the frontend and backend services."
  type        = string
  default     = "256"
}

variable "app_task_memory" {
  description = "Fargate task memory in MiB, used by both the frontend and backend services."
  type        = string
  default     = "512"
}

variable "app_desired_count" {
  type    = number
  default = 2
}

# --- CI/CD ---------------------------------------------------------------------

variable "github_org" {
  description = "GitHub organization/owner that owns this repo, used to scope the GitHub Actions OIDC deploy role."
  type        = string
  default     = "IITC-College"
}

variable "github_repo" {
  type    = string
  default = "example-react-app"
}

variable "create_github_oidc_provider" {
  description = "Set false if this AWS account already has a token.actions.githubusercontent.com OIDC provider registered (an account can only have one)."
  type        = bool
  default     = true
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

variable "redis_node_type" {
  type    = string
  default = "cache.r6g.large"
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
