provider "aws" {
  region = var.region

  default_tags {
    tags = local.common_tags
  }
}

# Requires CLOUDFLARE_API_TOKEN env var, or set var.cloudflare_api_token.
provider "cloudflare" {
  api_token = var.cloudflare_api_token
}
