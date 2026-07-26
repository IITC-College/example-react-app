output "internet_alb_dns_name" {
  description = "Point Cloudflare's CNAME at this (already wired automatically by the cloudflare module)."
  value       = module.security_vpc.alb_dns_name
}

output "cloudflare_hostname" {
  value = module.cloudflare.hostname
}

output "transit_gateway_id" {
  value = module.transit_gateway.transit_gateway_id
}

output "frontend_internal_alb_dns_name" {
  value = module.frontend_vpc.internal_alb_dns_name
}

output "backend_internal_alb_dns_name" {
  value = module.backend_vpc.internal_alb_dns_name
}

output "docdb_cluster_endpoint" {
  value = module.backend_vpc.docdb_cluster_endpoint
}

output "docdb_secret_arn" {
  value = module.backend_vpc.docdb_secret_arn
}

output "oracle_endpoint" {
  value = module.backend_vpc.oracle_endpoint
}

output "oracle_secret_arn" {
  value = module.backend_vpc.oracle_secret_arn
}

output "redis_primary_endpoint" {
  value = module.backend_vpc.redis_primary_endpoint
}

output "redis_reader_endpoint" {
  value = module.backend_vpc.redis_reader_endpoint
}

output "redis_auth_secret_arn" {
  value = module.backend_vpc.redis_auth_secret_arn
}

output "cloudtrail_bucket_name" {
  value = module.aws_services.cloudtrail_bucket_name
}

output "guardduty_detector_id" {
  value = module.aws_services.guardduty_detector_id
}

output "frontend_ecr_repository_url" {
  description = "docker push target for the frontend image (e.g. in CI)."
  value       = module.frontend_vpc.ecr_repository_url
}

output "backend_ecr_repository_url" {
  description = "docker push target for the backend image (e.g. in CI)."
  value       = module.backend_vpc.ecr_repository_url
}

output "frontend_ecs_cluster_name" {
  value = module.frontend_vpc.ecs_cluster_name
}

output "frontend_ecs_service_name" {
  value = module.frontend_vpc.ecs_service_name
}

output "backend_ecs_cluster_name" {
  value = module.backend_vpc.ecs_cluster_name
}

output "backend_ecs_service_name" {
  value = module.backend_vpc.ecs_service_name
}

output "github_actions_deploy_role_arn" {
  description = "Copy this into the GitHub repo's Actions variables as AWS_DEPLOY_ROLE_ARN."
  value       = module.cicd.deploy_role_arn
}
