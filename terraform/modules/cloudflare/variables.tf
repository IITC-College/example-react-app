variable "zone_id" {
  description = "Cloudflare zone ID for the domain fronting the internet-facing ALB."
  type        = string
}

variable "record_name" {
  description = "DNS record name (e.g. \"app\" for app.example.com, or \"@\" for the apex)."
  type        = string
  default     = "app"
}

variable "alb_dns_name" {
  description = "DNS name of the AWS internet-facing ALB (Security VPC) that Cloudflare should proxy to."
  type        = string
}

variable "proxied" {
  description = "Whether the record is proxied through Cloudflare (enables CDN + WAF). Set false for DNS-only."
  type        = bool
  default     = true
}

variable "managed_ruleset_id" {
  description = "Cloudflare Managed Ruleset ID to execute in the WAF managed-rules phase."
  type        = string
  default     = "efb7b8c949ac4650a09736fc376e9aee" # Cloudflare Managed Ruleset
}
