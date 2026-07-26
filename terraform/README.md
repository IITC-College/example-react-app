# AWS Multi-VPC Security Architecture — Terraform

Implements: Security VPC (FortiGate HA pair + Gateway Load Balancer +
internet-facing ALB) → Transit Gateway hub → Frontend VPC (internal ALB +
multi-AZ ASG) and Backend VPC (internal ALB + ASG + DocumentDB + RDS Oracle
Multi-AZ + ElastiCache Redis), plus account-wide CloudTrail, GuardDuty,
Security Hub, AWS Backup, and Cloudflare DNS/WAF/CDN in front of the
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

## Module layout

```
modules/
  vpc/              generic VPC + subnets (by role/AZ) + IGW/NAT + route tables
  transit-gateway/  TGW + 3 VPC attachments + hub/spoke route tables
  security-vpc/     FortiGate HA pair, GWLB, GWLB endpoints, internet ALB
  frontend-vpc/     internal ALB + multi-AZ ASG
  backend-vpc/      internal ALB + ASG, DocumentDB, RDS Oracle, ElastiCache Redis
  aws-services/     CloudTrail, GuardDuty, Security Hub, AWS Backup
  cloudflare/       DNS record + WAF managed ruleset
```
