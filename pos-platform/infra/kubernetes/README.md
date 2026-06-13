# infra/kubernetes

K8s manifests for cloud deployment. **Later-stage** infra (Development Guide §24 "Cloud — Later").

The initial cloud deploys to a VPS via Docker. K8s comes once autoscaling is needed.

## Planned
- `cloud-api/` — Deployment, Service, HPA, ConfigMap
- `sync-workers/` — Deployment + queue config
- `postgres/` — references managed Postgres (e.g. RDS, Cloud SQL); not self-hosted in cluster

## Status
Empty. Do not implement until Phase 5+.
