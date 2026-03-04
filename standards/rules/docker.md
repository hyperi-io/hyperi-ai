---
paths:
  - "**/Dockerfile"
  - "**/Dockerfile.*"
  - "**/docker-compose*.yml"
  - "**/docker-compose*.yaml"
---

## Base Images

- Use minimal bases: Python → `python:3.12-slim`, Node → `node:22-alpine`, Go → `golang:1.23-alpine` (build) / `scratch` (runtime), Rust → `rust:1.83-alpine` (build) / `scratch` (runtime)
- For no-shell minimal images: `gcr.io/distroless/python3-debian12`
- **Prohibited sources:** `bitnami/*`, `tutum/*`, `dockercloud/*`, random user images
- **Not recommended for production K8s:** `linuxserver/*` (PUID/PGID conflicts with securityContext, runs supervisord)
- **Approved sources:** Docker Official (no namespace prefix), Verified Publishers (`hashicorp/vault`, `grafana/grafana`), vendor-maintained (`gcr.io/distroless/*`), your own registry
- Standard images: `postgres:16-alpine`, `clickhouse/clickhouse-server`, `apache/kafka`, `timberio/vector`, `redis:7-alpine`, `quay.io/argoproj/argocd`

## Multi-Stage Builds (Required)

- Always separate build dependencies from runtime
- Copy only built artifacts into runtime stage
- Copy dependency manifests before source for layer caching

## Security

- **Always run as non-root** — Debian: `RUN useradd --create-home --shell /bin/bash appuser && USER appuser` / Alpine: `RUN addgroup -g 1001 -S appgroup && adduser -S appuser -u 1001 -G appgroup && USER appuser` / Scratch: `USER 1000:1000`
- Pin image versions; prefer digest pinning: `FROM python:3.12-slim@sha256:abc123...`
- ❌ `FROM python:latest`
- ✅ `FROM python:3.12-slim@sha256:abc123...`
- Never store secrets in images — no `COPY .env`, no `ENV API_KEY=secret`
- Use BuildKit secrets for build-time needs: `RUN --mount=type=secret,id=npm_token NPM_TOKEN=$(cat /run/secrets/npm_token) npm ci`
- Scan images: `docker scout cves myapp:latest` or `trivy image myapp:latest`
- Lint with Hadolint: `hadolint Dockerfile`

## Layer Optimization

- Copy dependency files before source code for caching
- ❌ `COPY . . && RUN uv sync`
- ✅ `COPY pyproject.toml uv.lock ./ && RUN uv sync --frozen && COPY src/ ./src/`
- Combine RUN commands and clean up in same layer
- ❌ Separate `RUN apt-get update`, `RUN apt-get install`, `RUN apt-get clean`
- ✅ Single `RUN apt-get update && apt-get install -y --no-install-recommends curl && rm -rf /var/lib/apt/lists/*`
- Always include `.dockerignore` — exclude `.git`, `.venv`, `__pycache__`, `node_modules`, `.env*`, `tests/`, `docs/`
- Enable BuildKit: `export DOCKER_BUILDKIT=1`
- Use cache mounts: `RUN --mount=type=cache,target=/root/.cache/pip pip install -r requirements.txt`

## Debug Utilities

- Include `curl` and `netcat-openbsd` in production images (2-5% size cost, high debug value)
- Do NOT include build tools, package managers, text editors, or bash (sh suffices)

## Health Checks

- Always define HEALTHCHECK: `HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 CMD curl -f http://localhost:8000/health/live || exit 1`
- Use `--timeout` 3-5s, `--start-period` 5-60s, `--retries` 2-3

## Docker Compose

- Use `depends_on` with `condition: service_healthy`
- Mount source for hot reload in dev; exclude venv: `volumes: [".:/app", "/app/.venv"]`
- Set resource limits in production-like compose to match K8s constraints
- Use `env_file` for secrets (gitignored), never commit `.env.prod`

## Docker → Kubernetes Promotion

- **Every container MUST be deployable to K8s without modification**
- Implement all three health endpoints: `/health/live` (liveness), `/health/ready` (readiness), `/health/startup` (startup)
- Configure exclusively via environment variables — same pattern works in compose and K8s
- Run as non-root (UID 1000+) — root containers FAIL with PodSecurityPolicies
- Never bake secrets into images — pass via ENV/volumes at runtime
- **Always bind to `0.0.0.0`** — not `localhost` or `127.0.0.1`
- Test with resource limits in compose matching K8s limits
- Handle SIGTERM for graceful shutdown
- Use exec form CMD to receive signals: `CMD ["python", "-m", "myapp", "serve"]`
- ❌ `CMD python -m myapp serve` (shell form — SIGTERM goes to shell)
- ✅ `CMD ["python", "-m", "myapp", "serve"]` (exec form — app receives SIGTERM)
- Log to stdout/stderr only — no file logging
- One main process per container — no supervisord
- Stateless — use external storage/cache

## Registry and Tagging

- Tag with semver + git SHA: `docker build -t myapp:${GIT_SHA} -t myapp:${VERSION} .`
- Use `docker buildx build --push` for build-and-push in one command

## Troubleshooting

- Analyze large images: `docker history myapp:latest`
- Container exits immediately: check `docker logs`, ensure CMD runs in foreground (no `-d` flags)
- Permission denied: use `COPY --chown=appuser:appuser` or `RUN chown -R appuser:appuser /app`

## K8s-Ready Checklist

- [ ] Multi-stage build, minimal base image (slim/alpine)
- [ ] All three health endpoints implemented (`/health/live`, `/health/ready`, `/health/startup`)
- [ ] Non-root user (UID 1000+)
- [ ] Image version pinned (or digest)
- [ ] No secrets in image; BuildKit secrets for build-time
- [ ] Config via environment variables
- [ ] Binds to `0.0.0.0`
- [ ] Handles SIGTERM gracefully
- [ ] Resource limits tested
- [ ] Logs to stdout/stderr, stateless, single process
- [ ] .dockerignore present, layers optimized for caching
- [ ] Debug utilities included (curl, nc)
- [ ] Vulnerability scan and Hadolint passed
