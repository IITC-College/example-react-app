# AWS Multi-VPC Security Architecture — CloudFormation

Implements the same architecture as `../terraform` (Security/Frontend/Backend
VPCs, Transit Gateway hub, FortiGate + Gateway Load Balancer inspection,
internal ALBs + Auto Scaling Groups, DocumentDB, RDS Oracle Multi-AZ,
ElastiCache Redis, and account-wide CloudTrail/GuardDuty/Security Hub/Backup)
using plain AWS resources — no third-party CLI/CDK required, just the AWS
CLI (or console).

Cloudflare has no CloudFormation resource provider, so DNS/WAF/CDN in front
of the ALB is out of scope here — see `../terraform/modules/cloudflare` if
you need that managed as code, or point Cloudflare's DNS manually at the
`AlbDnsName` output from stack 03.

Each template is independent (no nested stacks / no S3 template upload
required) and shares state via CloudFormation **Exports** +
**Fn::ImportValue**, so **stack names matter** — the defaults below are
assumed by every downstream template's parameters.

## Prerequisites

1. Subscribe to a FortiGate BYOL AMI in AWS Marketplace, then look up its
   AMI ID for your region (`aws ec2 describe-images --owners aws-marketplace
   --filters "Name=name,Values=FortiGate-VM64-AWSONDEMAND*"`).
2. Look up the current Amazon Linux 2023 AMI ID for your region for the
   frontend/backend Auto Scaling Groups.
3. Fill in `pFortiGateAmiId` / `pAmiId` in the relevant `parameters/*.json`
   files (or pass `--parameter-overrides` on the CLI).
4. Check `aws rds describe-db-engine-versions --engine oracle-se2` for a
   valid `pOracleEngineVersion` in your region.

## Deploy order

Deploy in this order — each stack imports outputs from the ones before it.

```bash
REGION=us-east-1

aws cloudformation deploy \
  --stack-name example-vpcs \
  --template-file templates/01-vpcs.yaml \
  --parameter-overrides file://parameters/01-vpcs.params.json \
  --region $REGION

aws cloudformation deploy \
  --stack-name example-tgw \
  --template-file templates/02-transit-gateway.yaml \
  --parameter-overrides file://parameters/02-transit-gateway.params.json \
  --region $REGION

aws cloudformation deploy \
  --stack-name example-security \
  --template-file templates/03-security-appliances.yaml \
  --parameter-overrides file://parameters/03-security-appliances.params.json \
  --capabilities CAPABILITY_IAM \
  --region $REGION

aws cloudformation deploy \
  --stack-name example-frontend \
  --template-file templates/04-frontend.yaml \
  --parameter-overrides file://parameters/04-frontend.params.json \
  --region $REGION

aws cloudformation deploy \
  --stack-name example-backend \
  --template-file templates/05-backend.yaml \
  --parameter-overrides file://parameters/05-backend.params.json \
  --region $REGION

aws cloudformation deploy \
  --stack-name example-aws-services \
  --template-file templates/06-aws-services.yaml \
  --parameter-overrides file://parameters/06-aws-services.params.json \
  --capabilities CAPABILITY_IAM \
  --region $REGION
```

`aws cloudformation deploy` doesn't natively accept a JSON parameters file
via `--parameter-overrides` (it expects `Key=Value` pairs) — convert first,
e.g.:

```bash
jq -r '.[] | "\(.ParameterKey)=\(.ParameterValue)"' parameters/01-vpcs.params.json
```

or use `aws cloudformation create-stack --parameters file://parameters/01-vpcs.params.json`
instead, which accepts the JSON list format directly.

If you name stacks differently than the defaults above, override
`pNetworkStackName` / `pTgwStackName` in the downstream templates'
parameter files to match.

## Validate before deploying

```bash
for f in templates/*.yaml; do
  aws cloudformation validate-template --template-body "file://$f"
done
```

## Scope notes

- **GWLB "sandwich" wiring** (ALB → GWLB endpoint → GWLB → FortiGate → back
  out to the Transit Gateway) is implemented at the infrastructure level.
  Actual FortiOS policy/SNAT/DNAT configuration on the FortiGate instances
  themselves is out of scope — that's appliance configuration, not AWS
  infrastructure.
- `03-security-appliances.yaml` includes a small Lambda-backed custom
  resource (`GwlbeIpLookupFunction`) to resolve each Gateway Load Balancer
  Endpoint's private IP, since CloudFormation has no native way to read an
  ENI's IP from a VPC Endpoint. It only calls `ec2:DescribeVpcEndpoints` /
  `ec2:DescribeNetworkInterfaces` and cleans up on stack deletion.
- DocumentDB instance count is a simple 1-vs-2 toggle (`pDocDbInstanceCount`)
  rather than arbitrary N, to keep the template's `Conditions` simple.
- Redis (`AWS::ElastiCache::ReplicationGroup` in `05-backend.yaml`) is a
  Multi-AZ replication group (1 primary + 1 replica, automatic failover)
  with at-rest + in-transit encryption. Its auth token is generated into
  `RedisAuthSecret` (Secrets Manager) the same way the DocumentDB/Oracle
  master passwords are, and it's reachable only from the backend app tier's
  security group.
