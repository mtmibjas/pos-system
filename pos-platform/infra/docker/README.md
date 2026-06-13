# infra/docker

Dockerfiles + compose files for **dev** and **cloud** deployments.

## Planned files
- `local-store-server.Dockerfile` — single Go binary + SQLite, exposed on `:8080`
- `cloud-api.Dockerfile` — Go binary; reads tenant routing from JWT
- `docker-compose.dev.yml` — postgres + cloud-api + local-store-server for local development
- `docker-compose.test.yml` — chaos-testing setup (slow network, partition simulation)

## Status
Scaffold.
