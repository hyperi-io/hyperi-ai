---
name: docker-standards
description: Docker and container standards using multi-stage builds, security hardening, and health checks. Use when writing Dockerfiles, docker-compose, or containerising applications.
rule_paths:
  - "**/Dockerfile"
  - "**/Dockerfile.*"
  - "**/docker-compose*.yml"
  - "**/docker-compose*.yaml"
detect_markers:
  - "file:Dockerfile"
  - "file:docker-compose.yml"
  - "file:docker-compose.yaml"
  - "deep_file:Dockerfile"
  - "deep_file:docker-compose.yml"
  - "deep_file:docker-compose.yaml"
---

# Docker Standards

**Dockerfile best practices, multi-stage builds, security, and container patterns**

---

## Quick Reference

```bash
docker build -t myapp .              # Build image
docker run -p 8000:8000 myapp        # Run container
docker compose up                    # Start services
docker compose logs -f myapp         # Stream logs
docker exec -it container sh         # Shell into container
docker scout cves myapp              # Scan for vulnerabilities
```

---

## Base Images

**Use minimal base images:**

| Language | Recommended Base | Notes |
|----------|------------------|-------|
| Python | `python:3.12-slim` | Debian-based, most compatible |
| Node.js | `node:22-alpine` | Current LTS, smallest |
| Go | `golang:1.23-alpine` (build) / `scratch` or `alpine` (runtime) | Static binaries |
| Rust | `rust:1.83-alpine` (build) / `scratch` or `alpine` (runtime) | Static binaries |

### Prohibited Image Sources

**Never use images from these sources** in any environment:

```dockerfile
# ❌ Prohibited sources
FROM bitnami/postgresql:16      # Bitnami - non-standard paths
FROM bitnami/redis:7.0
FROM tutum/mongodb              # Tutum - abandoned ~2016
FROM dockercloud/haproxy        # DockerCloud - abandoned 2018

# ✅ Use official images instead
FROM postgres:16-alpine
FROM redis:7-alpine
FROM nginx:1.25-alpine
```

**Prohibited sources and why:**

| Source | Why Prohibited |
| ------ | -------------- |
| `bitnami/*` | Non-standard paths, custom entrypoints, debugging difficulty |
| `tutum/*` | Abandoned (~2016), no security updates, unpatched CVEs |
| `dockercloud/*` | Abandoned (2018), no security updates since Docker Cloud shutdown |
| Random user images | No security guarantees, may contain malware |

**Not recommended for production K8s:**

| Source | Why |
| ------ | --- |
| `linuxserver/*` | Well-maintained but targets home lab use cases. Uses `PUID`/`PGID` env vars that conflict with K8s `securityContext`. Often runs multiple processes (supervisor). Not designed for horizontal scaling. |

**Approved image sources:**

- **Docker Official Images** - `postgres`, `redis`, `nginx`, `python`, etc. (no namespace prefix)
- **Verified Publishers** - `hashicorp/vault`, `grafana/grafana`, `prom/prometheus`
- **Vendor-maintained** - `gcr.io/distroless/*`, `quay.io/coreos/*`
- **Your own registry** - `registry.example.com/myorg/*`

**HyperI standard images:**

| Component | Image |
| --------- | ----- |
| PostgreSQL | `postgres:16-alpine` (dev) / CloudNativePG (K8s) |
| ClickHouse | `clickhouse/clickhouse-server` |
| Kafka | AutoMQ or `apache/kafka` |
| Vector | `timberio/vector` |
| Redis | `redis:7-alpine` |
| ArgoCD | `quay.io/argoproj/argocd` |

**How to verify an image is official:**

```bash
# Official images have no namespace prefix and show "Docker Official Image"
docker search --filter "is-official=true" postgres
```

**Why slim/alpine:**

- Smaller attack surface
- Faster pulls and deployments
- Lower storage costs
- Fewer vulnerabilities

**Distroless (advanced):**

```dockerfile
# Google distroless - minimal, no shell
FROM gcr.io/distroless/python3-debian12
```

---

## Multi-Stage Builds (Required)

**Always use multi-stage builds** to separate build dependencies from runtime.

### Python Example

```dockerfile
# Stage 1: Build
FROM python:3.12-slim AS builder
WORKDIR /build

# Install build dependencies
RUN pip install --no-cache-dir uv

# Copy dependency files
COPY pyproject.toml uv.lock ./

# Install dependencies (cached layer)
RUN uv sync --frozen --no-dev --no-editable

# Copy source
COPY src/ ./src/

# Build wheel
RUN uv build --wheel

# Stage 2: Runtime
FROM python:3.12-slim
WORKDIR /app

# Create non-root user
RUN useradd --create-home --shell /bin/bash appuser

# Copy built wheel and install
COPY --from=builder /build/dist/*.whl ./
RUN pip install --no-cache-dir *.whl && rm *.whl

# Install debug utilities (minimal cost, high value)
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl netcat-openbsd \
    && rm -rf /var/lib/apt/lists/*

# Switch to non-root user
USER appuser

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8000/health/live || exit 1

EXPOSE 8000
CMD ["python", "-m", "myapp", "serve"]
```

### Go Example

```dockerfile
# Stage 1: Build
FROM golang:1.23-alpine AS builder
WORKDIR /build

# Download dependencies (cached)
COPY go.mod go.sum ./
RUN go mod download

# Build static binary
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o /app ./cmd/myapp

# Stage 2: Runtime (scratch = smallest possible)
FROM scratch
COPY --from=builder /app /app
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/

# Non-root user (numeric for scratch)
USER 1000:1000

EXPOSE 8080
ENTRYPOINT ["/app"]
```

### Node.js Example

```dockerfile
# Stage 1: Build
FROM node:22-alpine AS builder
WORKDIR /build

# Install dependencies (cached)
COPY package*.json ./
RUN npm ci --only=production

# Copy source
COPY . .

# Stage 2: Runtime
FROM node:22-alpine
WORKDIR /app

# Create non-root user
RUN addgroup -g 1001 -S nodejs && adduser -S nodejs -u 1001

# Copy from builder
COPY --from=builder --chown=nodejs:nodejs /build/node_modules ./node_modules
COPY --from=builder --chown=nodejs:nodejs /build/dist ./dist
COPY --from=builder --chown=nodejs:nodejs /build/package.json ./

USER nodejs
EXPOSE 3000
CMD ["node", "dist/index.js"]
```

---

## Security Best Practices

### Run as Non-Root (Required)

**58% of production containers still run as root** - this is a significant security risk.

```dockerfile
# Debian/Ubuntu
RUN useradd --create-home --shell /bin/bash appuser
USER appuser

# Alpine
RUN addgroup -g 1001 -S appgroup && adduser -S appuser -u 1001 -G appgroup
USER appuser

# Scratch (use numeric)
USER 1000:1000
```

### Pin Image Versions

```dockerfile
# ❌ Bad - mutable tag
FROM python:latest

# ⚠️ Better - version pinned
FROM python:3.12-slim

# ✅ Best - digest pinned (immutable)
FROM python:3.12-slim@sha256:abc123...
```

**Get digest:**

```bash
docker pull python:3.12-slim
docker images --digests python:3.12-slim
```

### Never Store Secrets in Images

```dockerfile
# ❌ Bad - secrets baked into image
COPY .env /app/.env
ENV API_KEY=secret123

# ✅ Good - secrets at runtime
# Pass via environment variables or volume mounts at docker run/compose
```

**For build-time secrets (e.g., private package repos):**

```dockerfile
# Use BuildKit secrets (never cached in layers)
RUN --mount=type=secret,id=npm_token \
    NPM_TOKEN=$(cat /run/secrets/npm_token) npm ci
```

```bash
docker build --secret id=npm_token,src=.npm_token .
```

### Scan for Vulnerabilities

```bash
# Docker Scout (built-in)
docker scout cves myapp:latest
docker scout recommendations myapp:latest

# Trivy (open source)
trivy image myapp:latest

# Snyk
snyk container test myapp:latest
```

**Integrate in CI:**

```yaml
# GitHub Actions
- name: Scan image
  uses: docker/scout-action@v1
  with:
    command: cves
    image: myapp:${{ github.sha }}
    only-severities: critical,high
```

### Use Linter (Hadolint)

```bash
# Install
brew install hadolint  # macOS
apt-get install hadolint  # Debian

# Run
hadolint Dockerfile

# In CI
docker run --rm -i hadolint/hadolint < Dockerfile
```

---

## Layer Optimization

### Order Instructions for Caching

```dockerfile
# ✅ Good - dependencies before source (cached)
COPY pyproject.toml uv.lock ./
RUN uv sync --frozen
COPY src/ ./src/

# ❌ Bad - any source change invalidates dependency cache
COPY . .
RUN uv sync --frozen
```

### Combine RUN Commands

```dockerfile
# ❌ Bad - multiple layers
RUN apt-get update
RUN apt-get install -y curl
RUN apt-get clean

# ✅ Good - single layer, cleaned up
RUN apt-get update \
    && apt-get install -y --no-install-recommends curl \
    && rm -rf /var/lib/apt/lists/*
```

### Use .dockerignore

```dockerignore
# .dockerignore
.git
.github
.venv
__pycache__
*.pyc
.env
.env.*
node_modules
dist
*.md
!README.md
Dockerfile*
docker-compose*
.dockerignore
tests/
docs/
```

### Enable BuildKit

```bash
# Enable BuildKit (faster, more features)
export DOCKER_BUILDKIT=1
docker build .

# Or in docker-compose.yml
services:
  myapp:
    build:
      context: .
      dockerfile: Dockerfile
```

**BuildKit cache mounts (faster dependency installs):**

```dockerfile
# Python - cache pip downloads
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install -r requirements.txt

# Node.js - cache npm
RUN --mount=type=cache,target=/root/.npm \
    npm ci

# Go - cache modules
RUN --mount=type=cache,target=/go/pkg/mod \
    go mod download
```

---

## Debug Utilities

**Include minimal debug utilities in production containers.**

HyperI policy: Include small debug utilities. Removing tiny utilities for disk savings is inefficient. Containers should be debug-ready if cost is minimal (2-5% size increase).

```dockerfile
# Debian/Ubuntu
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    netcat-openbsd \
    && rm -rf /var/lib/apt/lists/*

# Alpine
RUN apk add --no-cache curl netcat-openbsd
```

**Include:**

- `curl` - HTTP debugging, health checks
- `netcat` (`nc`) - Network connectivity testing

**Don't include:**

- Build tools (gcc, make)
- Package managers (pip, npm)
- Text editors (vim, nano)
- Full shells (bash) - sh is sufficient

---

## Health Checks

```dockerfile
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8000/health/live || exit 1
```

**Parameters:**

| Parameter | Default | Recommendation |
|-----------|---------|----------------|
| `--interval` | 30s | 10-30s for most apps |
| `--timeout` | 30s | 3-5s (fail fast) |
| `--start-period` | 0s | 5-60s (startup grace) |
| `--retries` | 3 | 2-3 attempts |

**Check health:**

```bash
docker ps  # Shows health status
docker inspect --format='{{.State.Health.Status}}' mycontainer
```

---

## Docker Compose

### Development Setup

```yaml
# docker-compose.yml
services:
  app:
    build:
      context: .
      target: builder  # Use build stage for dev (has dev deps)
    ports:
      - "8000:8000"
    environment:
      - LOG_LEVEL=debug
      - DATABASE_URL=postgresql://user:pass@db:5432/mydb
    volumes:
      - .:/app  # Mount source for hot reload
      - /app/.venv  # Exclude venv from mount
    depends_on:
      db:
        condition: service_healthy
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/health/live"]
      interval: 10s
      timeout: 3s
      retries: 3

  db:
    image: postgres:16-alpine
    environment:
      POSTGRES_USER: user
      POSTGRES_PASSWORD: pass
      POSTGRES_DB: mydb
    volumes:
      - postgres_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U user -d mydb"]
      interval: 5s
      timeout: 3s
      retries: 5

volumes:
  postgres_data:
```

### Production-Like Setup

```yaml
# docker-compose.prod.yml
services:
  app:
    image: registry.example.com/myapp:${VERSION:-latest}
    deploy:
      replicas: 2
      resources:
        limits:
          cpus: '1.0'
          memory: 512M
        reservations:
          cpus: '0.25'
          memory: 128M
    env_file:
      - .env.prod  # Never commit
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/health/live"]
      interval: 30s
      timeout: 5s
      retries: 3
      start_period: 10s
```

### Common Commands

```bash
# Development
docker compose up              # Start all services
docker compose up -d           # Detached
docker compose up --build      # Rebuild images
docker compose logs -f app     # Follow logs
docker compose exec app sh     # Shell into container
docker compose down            # Stop and remove

# Debugging
docker compose ps              # Status
docker compose top             # Running processes
docker compose config          # Validate compose file
```

---

## Registry and Tagging

### Tag Strategy

```bash
# Build with multiple tags
docker build -t myapp:1.2.3 -t myapp:1.2 -t myapp:1 -t myapp:latest .

# For CI/CD
docker build -t myapp:${GIT_SHA} -t myapp:${VERSION} .
```

### Push to Registry

```bash
# Tag for registry
docker tag myapp:1.2.3 registry.example.com/myapp:1.2.3

# Push
docker push registry.example.com/myapp:1.2.3

# Or build and push in one command (BuildKit)
docker buildx build --push -t registry.example.com/myapp:1.2.3 .
```

---

## Common Issues

### Image Too Large

```bash
# Analyze image layers
docker history myapp:latest
docker scout analyze myapp:latest

# Check what's taking space
docker run --rm -it myapp:latest du -sh /*
```

**Solutions:**

1. Use multi-stage builds
2. Use slim/alpine base images
3. Clean up in same RUN command
4. Use .dockerignore

### Container Exits Immediately

```bash
# Check logs
docker logs mycontainer

# Run interactively to debug
docker run -it myapp:latest sh

# Check if process is running in foreground
# CMD should NOT daemonize (no -d flags)
```

### Permission Denied

```dockerfile
# Ensure correct ownership
COPY --chown=appuser:appuser . /app/

# Or fix permissions
RUN chown -R appuser:appuser /app
```

---

## Docker → Kubernetes Promotion

**CRITICAL:** Every Docker container developed locally MUST be deployable to Kubernetes without modification. Follow these patterns to ensure seamless promotion.

### Health Endpoints (Required)

Docker health checks translate directly to Kubernetes probes. **Always implement all three endpoints:**

| Endpoint | Docker HEALTHCHECK | K8s Probe | Purpose |
|----------|-------------------|-----------|---------|
| `/health/live` | ✅ Use this | livenessProbe | Is process alive? Restart if failing |
| `/health/ready` | Optional | readinessProbe | Can handle traffic? Remove from LB if failing |
| `/health/startup` | Optional | startupProbe | Initialization done? Delay other probes |

```dockerfile
# Docker - uses /health/live (K8s will use all three)
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8000/health/live || exit 1
```

```yaml
# Kubernetes - same endpoints, more granular control
livenessProbe:
  httpGet:
    path: /health/live
    port: http
  initialDelaySeconds: 10
  periodSeconds: 10

readinessProbe:
  httpGet:
    path: /health/ready
    port: http
  initialDelaySeconds: 5
  periodSeconds: 5

startupProbe:
  httpGet:
    path: /health/startup
    port: http
  failureThreshold: 30
  periodSeconds: 5
```

**Implementation:**

```python
# FastAPI - implement all three for K8s compatibility
from fastapi import FastAPI, Response, status

app = FastAPI()
app_ready = False  # Set True after initialization

@app.get("/health/live")
async def liveness():
    """Process alive? K8s restarts if this fails."""
    return {"status": "alive"}

@app.get("/health/ready")
async def readiness():
    """Can handle traffic? K8s removes from load balancer if failing."""
    if not app_ready:
        return Response(status_code=status.HTTP_503_SERVICE_UNAVAILABLE)
    if not await check_database_connection():
        return Response(status_code=status.HTTP_503_SERVICE_UNAVAILABLE)
    return {"status": "ready"}

@app.get("/health/startup")
async def startup():
    """Initialization complete? K8s waits before checking liveness."""
    if not app_ready:
        return Response(status_code=status.HTTP_503_SERVICE_UNAVAILABLE)
    return {"status": "started"}

@app.on_event("startup")
async def on_startup():
    global app_ready
    await initialize_connections()
    await warm_caches()
    app_ready = True
```

### Configuration via Environment Variables

**Docker Compose and Kubernetes both use environment variables.** Design your app to read config from ENV:

```dockerfile
# Dockerfile - no hardcoded config
ENV LOG_LEVEL=info
ENV DATABASE_HOST=localhost
ENV DATABASE_PORT=5432
CMD ["python", "-m", "myapp", "serve"]
```

```yaml
# docker-compose.yml - override via environment
services:
  app:
    environment:
      - LOG_LEVEL=debug
      - DATABASE_HOST=db
```

```yaml
# Kubernetes values.yaml - same pattern
env:
  - name: LOG_LEVEL
    value: "info"
  - name: DATABASE_HOST
    valueFrom:
      configMapKeyRef:
        name: myapp-config
        key: database-host
```

**Config cascade (same for Docker and K8s):**

1. CLI args (if supported)
2. Environment variables ← **Primary config method**
3. Config files (mounted as volumes/ConfigMaps)
4. Defaults in code

### Non-Root User (Required for K8s)

Kubernetes security policies often **require** non-root containers:

```dockerfile
# Dockerfile - MUST run as non-root
RUN useradd --create-home --uid 1000 appuser
USER appuser
WORKDIR /home/appuser/app
```

```yaml
# Kubernetes - enforces non-root
securityContext:
  runAsNonRoot: true
  runAsUser: 1000
  runAsGroup: 1000
  fsGroup: 1000
```

**If your Docker container runs as root, it will FAIL in K8s with PodSecurityPolicies enabled.**

### Secrets Management Pattern

**Never bake secrets into images.** Use the same pattern for Docker and K8s:

```yaml
# docker-compose.yml
services:
  app:
    env_file:
      - .env  # Local development secrets (gitignored)
    environment:
      - DATABASE_PASSWORD=${DATABASE_PASSWORD}
```

```yaml
# Kubernetes - secrets mounted same way
env:
  - name: DATABASE_PASSWORD
    valueFrom:
      secretKeyRef:
        name: myapp-secrets
        key: database-password
```

**Your app reads `DATABASE_PASSWORD` from ENV - works in both environments.**

### Port and Network Patterns

**Use consistent ports between Docker and K8s:**

```dockerfile
# Dockerfile
EXPOSE 8000
CMD ["python", "-m", "myapp", "serve", "--host", "0.0.0.0", "--port", "8000"]
```

```yaml
# docker-compose.yml
services:
  app:
    ports:
      - "8000:8000"  # Same port
```

```yaml
# Kubernetes service
spec:
  ports:
    - port: 80           # External port (can differ)
      targetPort: 8000   # Container port (must match EXPOSE)
```

**Always bind to `0.0.0.0`** - not `localhost` or `127.0.0.1` (won't work in K8s).

### Resource Constraints

**Test with resource limits in Docker that match K8s:**

```yaml
# docker-compose.yml - simulate K8s limits
services:
  app:
    deploy:
      resources:
        limits:
          cpus: '1.0'
          memory: 512M
        reservations:
          cpus: '0.25'
          memory: 128M
```

```yaml
# Kubernetes - same limits
resources:
  limits:
    cpu: 1000m      # 1.0 CPU
    memory: 512Mi
  requests:
    cpu: 250m       # 0.25 CPU
    memory: 128Mi
```

### Graceful Shutdown

**K8s sends SIGTERM before killing pods.** Handle it:

```python
import signal
import sys

def handle_sigterm(signum, frame):
    """Graceful shutdown on SIGTERM (K8s pod termination)."""
    print("Received SIGTERM, shutting down gracefully...")
    # Close connections, finish current requests
    cleanup()
    sys.exit(0)

signal.signal(signal.SIGTERM, handle_sigterm)
```

```dockerfile
# Use exec form to receive signals properly
CMD ["python", "-m", "myapp", "serve"]  # ✅ exec form - receives SIGTERM

# NOT shell form
CMD python -m myapp serve  # ❌ shell form - SIGTERM goes to shell, not app
```

### Directory Structure for K8s-Ready Projects

```text
my-service/
├── Dockerfile                 # Container definition
├── .dockerignore
├── docker-compose.yml         # Local development
├── docker-compose.prod.yml    # Production-like local testing
│
├── helm/                      # K8s deployment (uses same image)
│   ├── Chart.yaml
│   ├── values.yaml
│   ├── values-dev.yaml
│   ├── values-staging.yaml
│   ├── values-prod.yaml
│   └── templates/
│       ├── deployment.yaml
│       ├── service.yaml
│       └── ...
│
├── src/                       # Application code
│   └── myapp/
│       ├── __init__.py
│       ├── main.py
│       └── health.py          # Health endpoints
│
└── pyproject.toml
```

### K8s-Ready Checklist

Before promoting a Docker container to Kubernetes:

- [ ] **Health endpoints:** All three (`/health/live`, `/health/ready`, `/health/startup`) implemented
- [ ] **Non-root user:** Container runs as UID 1000+ (not root)
- [ ] **Config via ENV:** All configuration via environment variables
- [ ] **No secrets in image:** Secrets passed at runtime via ENV/volumes
- [ ] **Binds to 0.0.0.0:** Not localhost/127.0.0.1
- [ ] **Handles SIGTERM:** Graceful shutdown on termination
- [ ] **Resource limits tested:** Works within memory/CPU constraints
- [ ] **Logs to stdout/stderr:** No file logging (K8s captures stdout)
- [ ] **Stateless:** No local state (use external storage/cache)
- [ ] **Single process:** One main process per container (no supervisord)

---

## Checklist

### Dockerfile

- [ ] Multi-stage build used
- [ ] Minimal base image (slim/alpine)
- [ ] Non-root user
- [ ] Image version pinned (or digest)
- [ ] No secrets in image
- [ ] HEALTHCHECK defined
- [ ] .dockerignore present
- [ ] Layers optimized for caching
- [ ] Debug utilities included (curl, nc)

### Security

- [ ] Vulnerability scan passed
- [ ] Hadolint linter passed
- [ ] No sensitive files in image
- [ ] BuildKit secrets for build-time secrets

---

## See Also

- [K8S.md](K8S.md) - Kubernetes/HELM deployment standards
- [Docker Best Practices](https://docs.docker.com/build/building/best-practices/)
- [Docker Multi-Stage Builds](https://docs.docker.com/build/building/multi-stage/)
- [Docker Security Best Practices](https://betterstack.com/community/guides/scaling-docker/docker-security-best-practices/)
- [Hadolint](https://github.com/hadolint/hadolint)
