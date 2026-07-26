resource "cloudflare_record" "app" {
  zone_id = var.zone_id
  name    = var.record_name
  type    = "CNAME"
  content = var.alb_dns_name
  proxied = var.proxied
  ttl     = var.proxied ? 1 : 300 # ttl must be 1 (auto) when proxied
}

# CDN is implicit in `proxied = true` above. WAF: execute Cloudflare's
# managed ruleset on every request to this zone.
resource "cloudflare_ruleset" "waf_managed" {
  zone_id     = var.zone_id
  name        = "waf-managed"
  description = "Execute the Cloudflare Managed Ruleset"
  kind         = "zone"
  phase        = "http_request_firewall_managed"

  rules {
    action = "execute"
    action_parameters {
      id = var.managed_ruleset_id
    }
    expression  = "true"
    description = "Execute Cloudflare Managed Ruleset"
    enabled      = true
  }
}
