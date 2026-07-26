# AWS Multi-VPC Security Architecture — Terraform

Implements: Security VPC (FortiGate HA pair + Gateway Load Balancer +
internet-facing ALB) → Transit Gateway hub → Frontend VPC (internal ALB +
ECS Fargate service running the `../frontend` Next.js app) and Backend VPC
(internal ALB + ECS Fargate service running the `../backend` NestJS app +
DocumentDB + RDS Oracle Multi-AZ + ElastiCache Redis), plus account-wide
CloudTrail, GuardDuty, Security Hub, AWS Backup, a GitHub Actions OIDC
deploy role (`modules/cicd`), and Cloudflare DNS/WAF/CDN in front of the
internet-facing ALB.

## Prerequisites

1. Subscribe to a FortiGate BYOL AMI in AWS Marketplace for the target
   region/account (required before `apply` — Terraform can look up the AMI
   ID automatically once subscribed, or you can pin one via
   `fortigate_ami_id`).
2. A Cloudflare API token scoped to DNS + WAF edit on the target zone, and
   that zone's ID.
3. Terraform >= 1.5, the AWS provider `~> 5.0`, and credentials for the
   target AWS account/region.

## 1. Bootstrap remote state (one-time)

```bash
cd bootstrap
terraform init
terraform apply \
  -var="state_bucket_name=your-unique-bucket-name" \
  -var="lock_table_name=your-lock-table-name"
```

Copy the bucket/table names into `../backend.tf` (Terraform can't
interpolate variables in a `backend` block).

## 2. Deploy the architecture

```bash
cd ..
cp terraform.tfvars.example terraform.tfvars   # fill in the CHANGEME values
export CLOUDFLARE_API_TOKEN=...                # prefer this over putting it in tfvars

terraform init
terraform validate
terraform plan
terraform apply
```

## 3. Application deploy (ECS Fargate + ECR)

The `frontend_vpc`/`backend_vpc` modules each create their own ECR repo and
Fargate service. **Both repos start empty**, so on first `apply` the ECS
services will show 0 healthy tasks until an image is pushed — that's
expected, not a bug.

1. After the first `apply`, copy `github_actions_deploy_role_arn` and the
   `*_ecr_repository_url` outputs into the GitHub repo's Actions variables:
   `AWS_DEPLOY_ROLE_ARN`, `AWS_REGION`, `FRONTEND_ECR_REPO`, `BACKEND_ECR_REPO`
   (this one manual step is unavoidable — GitHub repo settings aren't
   something Terraform touches). See `../.github/workflows/deploy.yml`.
2. From then on, every push to `main` builds+pushes both images and runs
   `terraform apply -var="frontend_image_tag=$SHA" -var="backend_image_tag=$SHA"`.
   The `aws_ecs_service` resources have `lifecycle { ignore_changes =
   [task_definition] }`, so this CD-driven task definition swap won't get
   reverted by a later unrelated `terraform apply` — Terraform owns the
   service's shape (CPU/memory/roles/networking), CI owns which image
   revision is running.

## Scope notes

- **GWLB "sandwich" wiring** (internet ALB → GWLB endpoint → GWLB →
  FortiGate → back out to the Transit Gateway) is implemented at the
  infrastructure level in `modules/security-vpc`. Actual FortiOS
  policy/SNAT/DNAT configuration on the FortiGate instances themselves is
  out of scope — that's appliance configuration, not AWS infrastructure.
- Database master passwords and the Redis auth token are generated with
  `random_password` and stored in Secrets Manager (`docdb_secret_arn` /
  `oracle_secret_arn` / `redis_auth_secret_arn` outputs) — nothing is
  written to state or tfvars in plaintext beyond what Terraform state
  always contains.
- Redis (`aws_elasticache_replication_group`) is a Multi-AZ replication
  group (1 primary + 1 replica, automatic failover) with at-rest + in-transit
  encryption, reachable only from the backend app tier's security group.
- `docdb_skip_final_snapshot` / `oracle_skip_final_snapshot` default to
  `true` so `terraform destroy` doesn't get stuck in this example — set to
  `false` for production.
- `oracle_engine_version` defaults to `"19"`; check
  `aws rds describe-db-engine-versions --engine oracle-se2` for a valid
  full version string in your region before applying.
- `create_github_oidc_provider` defaults to `true`. An AWS account can only
  register `token.actions.githubusercontent.com` once — set this `false` if
  the account already has one (`modules/cicd` will look it up instead).

## Module layout

```
modules/
  vpc/              generic VPC + subnets (by role/AZ) + IGW/NAT + route tables
  transit-gateway/  TGW + 3 VPC attachments + hub/spoke route tables
  security-vpc/     FortiGate HA pair, GWLB, GWLB endpoints, internet ALB
  frontend-vpc/     internal ALB + ECS Fargate service (Next.js) + ECR repo
  backend-vpc/      internal ALB + ECS Fargate service (NestJS) + ECR repo,
                     DocumentDB, RDS Oracle, ElastiCache Redis
  aws-services/     CloudTrail, GuardDuty, Security Hub, AWS Backup
  cloudflare/       DNS record + WAF managed ruleset
  cicd/             GitHub Actions OIDC provider + deploy role
```
