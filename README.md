# example-react-app

- [`frontend/`](frontend) — Next.js (App Router, TypeScript) app.
- [`backend/`](backend) — NestJS API.
- [`terraform/`](terraform) — AWS infra (Terraform): Security/Frontend/Backend
  VPCs behind a FortiGate + Gateway Load Balancer inspection point, ECS
  Fargate running the two apps above, DocumentDB, RDS Oracle, ElastiCache
  Redis, and a GitHub Actions OIDC deploy role.
- [`cloudformation/`](cloudformation) — the same architecture as plain
  CloudFormation templates, for teams that don't use Terraform.
- [`.github/workflows/`](.github/workflows) — `ci.yml` (lint/test/build on
  every push/PR) and `deploy.yml` (build+push images to ECR, then deploy via
  either the Terraform or the CloudFormation tree, on push to `main`).
- `docker-compose.yml` — run both apps locally.

## Local development

```bash
cd frontend && npm install && npm run dev   # http://localhost:3000
cd backend && npm install && npm run start:dev  # http://localhost:3000 (separate terminal)
```

or `docker compose up --build` to run both together (frontend on 3000,
backend on 3001).

## Deploying

Pick one of `terraform/` or `cloudformation/` — see each folder's README for
the full walkthrough (bootstrap/prerequisites, deploy order, and how CI/CD
wires into it). Both provision the same AWS architecture; `deploy.yml` has a
job for each, since only whichever one you actually applied is meaningful in
a real account.
