# infra/terraform

Terraform modules for **AWS** cloud infra.

## Planned modules
- `vpc/` — VPC, subnets (public + private), NAT, route tables
- `rds/` — Aurora PostgreSQL (or RDS PostgreSQL) — one DB per tenant via the application layer
- `ecs/` or `eks/` — runtime for `cloud-api` and sync workers (initial: ECS Fargate; later: EKS — see `infra/kubernetes/`)
- `s3/` — backups (`pg_dump` per tenant), receipt PDFs (later)
- `secrets/` — AWS Secrets Manager for JWT signing keys, DB credentials, third-party API keys
- `kms/` — customer-managed KMS keys for at-rest encryption (RDS, S3, Secrets Manager)
- `route53/` — DNS (`api.<domain>`, per-tenant subdomains later if needed)
- `acm/` — TLS certs for the API gateway
- `cloudwatch/` — log groups, metric filters, alarms

## Conventions
- Terraform state in S3 with DynamoDB lock table (per environment).
- One workspace per environment: `dev`, `staging`, `prod`.
- All resources tagged `Project=pos-platform`, `Environment=<env>`, `ManagedBy=terraform`.

## Status
Empty. Author once Phase 3 (cloud sync) approaches.
