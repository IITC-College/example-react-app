locals {
  common_tags = var.tags

  security_subnet_groups = {
    public     = { cidr_blocks = [cidrsubnet(var.security_vpc_cidr, 3, 0), cidrsubnet(var.security_vpc_cidr, 3, 1)], public = true }
    gwlbe      = { cidr_blocks = [cidrsubnet(var.security_vpc_cidr, 3, 2), cidrsubnet(var.security_vpc_cidr, 3, 3)], public = false }
    firewall   = { cidr_blocks = [cidrsubnet(var.security_vpc_cidr, 3, 4), cidrsubnet(var.security_vpc_cidr, 3, 5)], public = false }
    tgw-attach = { cidr_blocks = [cidrsubnet(var.security_vpc_cidr, 3, 6), cidrsubnet(var.security_vpc_cidr, 3, 7)], public = false }
  }

  frontend_subnet_groups = {
    app        = { cidr_blocks = [cidrsubnet(var.frontend_vpc_cidr, 4, 0), cidrsubnet(var.frontend_vpc_cidr, 4, 1)], public = false }
    tgw-attach = { cidr_blocks = [cidrsubnet(var.frontend_vpc_cidr, 4, 2), cidrsubnet(var.frontend_vpc_cidr, 4, 3)], public = false }
  }

  backend_subnet_groups = {
    app        = { cidr_blocks = [cidrsubnet(var.backend_vpc_cidr, 4, 0), cidrsubnet(var.backend_vpc_cidr, 4, 1)], public = false }
    db         = { cidr_blocks = [cidrsubnet(var.backend_vpc_cidr, 4, 2), cidrsubnet(var.backend_vpc_cidr, 4, 3)], public = false }
    tgw-attach = { cidr_blocks = [cidrsubnet(var.backend_vpc_cidr, 4, 4), cidrsubnet(var.backend_vpc_cidr, 4, 5)], public = false }
  }
}

# --- Networking: 3 VPCs -------------------------------------------------------

module "security_vpc_net" {
  source = "./modules/vpc"

  name               = "security"
  cidr_block          = var.security_vpc_cidr
  azs                 = var.azs
  subnet_groups      = local.security_subnet_groups
  create_igw          = true
  create_nat_gateway = true
  tags                = local.common_tags
}

module "frontend_vpc_net" {
  source = "./modules/vpc"

  name          = "frontend"
  cidr_block     = var.frontend_vpc_cidr
  azs            = var.azs
  subnet_groups = local.frontend_subnet_groups
  tags           = local.common_tags
}

module "backend_vpc_net" {
  source = "./modules/vpc"

  name          = "backend"
  cidr_block     = var.backend_vpc_cidr
  azs            = var.azs
  subnet_groups = local.backend_subnet_groups
  tags           = local.common_tags
}

# --- Transit Gateway hub -------------------------------------------------------

module "transit_gateway" {
  source = "./modules/transit-gateway"

  name = var.name_prefix

  security_vpc_id          = module.security_vpc_net.vpc_id
  security_tgw_subnet_ids = module.security_vpc_net.subnet_ids["tgw-attach"]

  frontend_vpc_id          = module.frontend_vpc_net.vpc_id
  frontend_tgw_subnet_ids = module.frontend_vpc_net.subnet_ids["tgw-attach"]

  backend_vpc_id          = module.backend_vpc_net.vpc_id
  backend_tgw_subnet_ids = module.backend_vpc_net.subnet_ids["tgw-attach"]

  tags = local.common_tags
}

# --- Security VPC: FortiGate HA pair + GWLB + internet-facing ALB -------------

module "security_vpc" {
  source = "./modules/security-vpc"

  name                = "security"
  vpc_id               = module.security_vpc_net.vpc_id
  vpc_cidr_block       = module.security_vpc_net.vpc_cidr_block
  public_subnet_ids   = module.security_vpc_net.subnet_ids["public"]
  gwlbe_subnet_ids    = module.security_vpc_net.subnet_ids["gwlbe"]
  firewall_subnet_ids = module.security_vpc_net.subnet_ids["firewall"]

  firewall_route_table_id = module.security_vpc_net.route_table_ids["firewall"]
  nat_gateway_id            = module.security_vpc_net.nat_gateway_id

  transit_gateway_id              = module.transit_gateway.transit_gateway_id
  transit_gateway_attachment_id = module.transit_gateway.security_attachment_id

  frontend_vpc_cidr = var.frontend_vpc_cidr
  backend_vpc_cidr  = var.backend_vpc_cidr
  azs                = var.azs

  fortigate_instance_type = var.fortigate_instance_type
  fortigate_ami_id          = var.fortigate_ami_id
  fortigate_key_name       = var.fortigate_key_name
  admin_ingress_cidrs      = var.admin_ingress_cidrs
  alb_ingress_cidrs        = var.alb_ingress_cidrs
  acm_certificate_arn      = var.acm_certificate_arn

  tags = local.common_tags

  depends_on = [module.transit_gateway]
}

# --- Frontend VPC: internal ALB + ECS Fargate service (Next.js) --------------

module "frontend_vpc" {
  source = "./modules/frontend-vpc"

  name            = "frontend"
  vpc_id           = module.frontend_vpc_net.vpc_id
  vpc_cidr_block  = module.frontend_vpc_net.vpc_cidr_block
  app_subnet_ids = module.frontend_vpc_net.subnet_ids["app"]

  app_route_table_id = module.frontend_vpc_net.route_table_ids["app"]
  transit_gateway_id   = module.transit_gateway.transit_gateway_id

  azs                = var.azs
  security_vpc_cidr = var.security_vpc_cidr

  image_tag     = var.frontend_image_tag
  task_cpu       = var.app_task_cpu
  task_memory   = var.app_task_memory
  desired_count = var.app_desired_count

  tags = local.common_tags

  depends_on = [module.transit_gateway]
}

# --- Backend VPC: internal ALB + ECS Fargate service (NestJS) + DBs ---------

module "backend_vpc" {
  source = "./modules/backend-vpc"

  name            = "backend"
  vpc_id           = module.backend_vpc_net.vpc_id
  vpc_cidr_block  = module.backend_vpc_net.vpc_cidr_block
  app_subnet_ids = module.backend_vpc_net.subnet_ids["app"]
  db_subnet_ids  = module.backend_vpc_net.subnet_ids["db"]

  app_route_table_id = module.backend_vpc_net.route_table_ids["app"]
  transit_gateway_id   = module.transit_gateway.transit_gateway_id

  azs               = var.azs
  frontend_vpc_cidr = var.frontend_vpc_cidr

  image_tag     = var.backend_image_tag
  task_cpu       = var.app_task_cpu
  task_memory   = var.app_task_memory
  desired_count = var.app_desired_count

  docdb_instance_class   = var.docdb_instance_class
  oracle_instance_class = var.oracle_instance_class
  redis_node_type          = var.redis_node_type

  tags = local.common_tags

  depends_on = [module.transit_gateway]
}

# --- CI/CD: GitHub Actions OIDC deploy role -----------------------------------

module "cicd" {
  source = "./modules/cicd"

  github_org           = var.github_org
  github_repo          = var.github_repo
  create_oidc_provider = var.create_github_oidc_provider

  ecr_repository_arns = [
    module.frontend_vpc.ecr_repository_arn,
    module.backend_vpc.ecr_repository_arn,
  ]
  ecs_service_arns = [
    module.frontend_vpc.ecs_service_arn,
    module.backend_vpc.ecs_service_arn,
  ]
  task_role_arns = [
    module.frontend_vpc.task_execution_role_arn,
    module.frontend_vpc.task_role_arn,
    module.backend_vpc.task_execution_role_arn,
    module.backend_vpc.task_role_arn,
  ]

  tags = local.common_tags
}

# --- Account-wide security services -------------------------------------------

module "aws_services" {
  source = "./modules/aws-services"

  name = var.name_prefix
  tags = local.common_tags
}

# --- Cloudflare: DNS + WAF + CDN in front of the internet-facing ALB ----------

module "cloudflare" {
  source = "./modules/cloudflare"

  zone_id     = var.cloudflare_zone_id
  record_name = var.cloudflare_record_name
  alb_dns_name = module.security_vpc.alb_dns_name
}
