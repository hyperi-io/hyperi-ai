# Containerization Standards

**Container patterns for Docker standalone (local dev) and Kubernetes + HELM + ArgoCD (production)**

---

## Overview

HyperSec projects use containerization with two deployment targets:

1. **Docker Standalone** - Local development, testing, CI/CD builds
2. **Kubernetes + HELM + ArgoCD** - Production deployments

**Design Principle:** Components work standalone on Docker AND deploy to Kubernetes with HELM charts managed by ArgoCD.

### Deployment Target Comparison

| Aspect | Docker Standalone | Kubernetes + HELM + ArgoCD |
|--------|------------------|----------------------------|
| **Use Cases** | Local dev, testing, simple deployments | Production, multi-env, high availability |
| **Orchestration** | Docker Compose | Kubernetes |
| **Configuration** | `.env` files, `docker-compose.yml` | HELM values.yaml (per environment) |
| **Health Checks** | `HEALTHCHECK` instruction | Liveness/Readiness/Startup probes |
| **Scaling** | Manual (`docker compose scale`) | Auto-scaling (HPA, KEDA) |
| **Secrets** | Environment variables, volume mounts | Kubernetes secrets, sealed secrets |
| **Deployment** | `docker compose up` | ArgoCD GitOps (automatic) |
| **Rollbacks** | Manual (`docker compose down/up`) | Automatic (Kubernetes rollback) |
| **Monitoring** | Docker logs, manual | Prometheus, Grafana, alerts |
| **Complexity** | Low | Medium-High |

This guide covers image standards, debugging utilities, health checks, and deployment patterns for both targets.

---

## Container Image Standards

### Base Images

**Use official minimal base images:**

- **Python:** `python:3.12-slim` or `python:3.12-alpine`
- **Node.js:** `node:20-alpine`
- **Go:** `golang:1.21-alpine` (build), `alpine:3.18` (runtime)

**Why slim/alpine:** Smaller attack surface, faster pulls, lower storage costs

### Multi-Stage Builds (Required)

**Always use multi-stage builds** to separate build dependencies from runtime:

```dockerfile
# Stage 1: Build
FROM python:3.12-slim AS builder
WORKDIR /build
COPY pyproject.toml uv.lock ./
RUN pip install uv && uv sync --frozen --no-dev
COPY src/ ./src/
RUN uv build

# Stage 2: Runtime
FROM python:3.12-slim
WORKDIR /app
COPY --from=builder /build/dist/*.whl ./
RUN pip install *.whl && rm *.whl
USER nobody
CMD ["python", "-m", "myapp", "serve"]
```

**Benefits:** Build tools excluded from runtime (smaller, more secure), consistent dependencies (uv.lock), minimal footprint

### Debug Utilities Policy

**Include small debugging utilities in production containers.**

Derek's policy: Include small debug utilities in standard builds. Removing tiny utilities for disk savings is inefficient. Containers should be debug-ready if cost is minimal (2-5% size increase).

**Recommended debug utilities:**

```dockerfile
# Python containers
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    netcat-openbsd \
    iputils-ping \
    && rm -rf /var/lib/apt/lists/*

# Alpine containers
RUN apk add --no-cache \
    curl \
    netcat-openbsd \
    iputils
```

**What to include:**
- `curl` - HTTP debugging, health check testing
- `netcat` (`nc`) - Network connectivity testing
- `ping` - Basic network diagnostics

**What NOT to include:**
- Build tools (gcc, make) - use multi-stage builds
- Package managers (pip, npm) - install at build time
- Shells (bash) - alpine sh sufficient
- Text editors (vim, nano) - use kubectl cp

**Typical cost:** Debug utilities ~5-15MB (2-5% increase) - acceptable for debuggability

---

## Deployment Targets

### Target 1: Docker Standalone

**Use for:** Local development, testing, CI/CD builds, simple deployments

**When to use:**
- Independent components (no orchestration)
- Local development
- CI/CD integration tests
- Single-server deployments
- Debugging

**Docker Compose example:**

```yaml
# docker-compose.yml
version: '3.8'

services:
  myapp:
    build: .
    ports:
      - "8000:8000"
    environment:
      - DATABASE_URL=postgresql://user:pass@db:5432/mydb
      - LOG_LEVEL=debug
    volumes:
      - ./.env:/app/.env  # Local config
      - ./logs:/app/logs            # Local logs
    depends_on:
      - db
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/health/live"]
      interval: 10s
      timeout: 3s
      retries: 3

  db:
    image: postgres:16-alpine
    environment:
      - POSTGRES_PASSWORD=devpassword
    volumes:
      - postgres_data:/var/lib/postgresql/data

volumes:
  postgres_data:
```

**Running standalone:**

```bash
# Development
docker compose up

# Production-like (detached)
docker compose up -d

# View logs
docker compose logs -f myapp

# Shell into container
docker compose exec myapp sh

# Rebuild after code changes
docker compose up --build
```

**Health checks for Docker:**

```dockerfile
# Dockerfile
HEALTHCHECK --interval=10s --timeout=3s --retries=3 \
  CMD curl -f http://localhost:8000/health/live || exit 1
```

### Target 2: Kubernetes + HELM + ArgoCD

**Use for:** Production deployments, multi-environment, auto-scaling, high availability

**When to use:**
- Production workloads
- Multi-environment (dev, staging, prod)
- Auto-scaling
- High availability
- Complex service dependencies
- GitOps workflow

**Migration path:** Start with Docker standalone, migrate to Kubernetes when production-ready.

---

## Health Checks

### Docker Standalone Health Checks

**Use Docker HEALTHCHECK instruction:**

```dockerfile
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:8000/health/live || exit 1
```

**Check health status:**

```bash
docker ps  # Shows health status
docker inspect --format='{{.State.Health.Status}}' container_name
```

### Kubernetes Probes

**Every Kubernetes container MUST implement:**

```yaml
# HELM values.yaml
livenessProbe:
  httpGet:
    path: /health/live
    port: http
  initialDelaySeconds: 10
  periodSeconds: 10
  timeoutSeconds: 3
  failureThreshold: 3

readinessProbe:
  httpGet:
    path: /health/ready
    port: http
  initialDelaySeconds: 5
  periodSeconds: 5
  timeoutSeconds: 3
  failureThreshold: 2

startupProbe:
  httpGet:
    path: /health/startup
    port: http
  initialDelaySeconds: 0
  periodSeconds: 5
  timeoutSeconds: 3
  failureThreshold: 30  # 150 seconds max startup time
```

### Health Check Endpoints

**Three endpoints required:**

1. **`/health/live`** - Liveness (process alive?)
   - Returns 200 if app can accept requests
   - K8s kills pod if failing (restarts)
   - Example: Connection pool not deadlocked

2. **`/health/ready`** - Readiness (can handle traffic?)
   - Returns 200 if ready to serve
   - Removes from endpoints if failing (no traffic)
   - Example: Migrations complete, cache warmed

3. **`/health/startup`** - Startup (initialized?)
   - Returns 200 once fully initialized
   - Prevents premature checks
   - Example: Dataset loaded, connections established

**Python example (FastAPI):**

```python
from fastapi import FastAPI, Response, status

app = FastAPI()

@app.get("/health/live")
async def liveness():
    """Liveness probe - is process alive?"""
    # Check critical resources (non-blocking)
    return {"status": "alive"}

@app.get("/health/ready")
async def readiness():
    """Readiness probe - can handle traffic?"""
    # Check dependencies (database, cache, etc.)
    if not await check_database():
        return Response(status_code=status.HTTP_503_SERVICE_UNAVAILABLE)
    return {"status": "ready"}

@app.get("/health/startup")
async def startup():
    """Startup probe - initialization complete?"""
    if not app_initialized:
        return Response(status_code=status.HTTP_503_SERVICE_UNAVAILABLE)
    return {"status": "started"}
```

---

## Kubernetes Deployment Patterns

### Directory Structure

**For Kubernetes projects:**

```
my-service/
├── Dockerfile
├── .dockerignore
├── helm/
│   ├── Chart.yaml
│   ├── values.yaml
│   ├── values-dev.yaml
│   ├── values-staging.yaml
│   ├── values-prod.yaml
│   └── templates/
│       ├── deployment.yaml
│       ├── service.yaml
│       ├── ingress.yaml
│       ├── configmap.yaml
│       └── secret.yaml
└── argocd/
    ├── application.yaml       # ArgoCD app definition
    └── applicationset.yaml    # Multi-environment app set
```

### HELM Chart Standards

**Chart.yaml:**

```yaml
apiVersion: v2
name: my-service
description: My service description
type: application
version: 1.0.0          # Chart version
appVersion: "2.5.3"     # Application version (from VERSION file)
```

**values.yaml (defaults):**

```yaml
replicaCount: 2

image:
  repository: jfrog.hypersec.io/my-service
  pullPolicy: IfNotPresent
  tag: ""  # Overridden by appVersion if empty

service:
  type: ClusterIP
  port: 8000

ingress:
  enabled: true
  className: nginx
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
  hosts:
    - host: my-service.hypersec.io
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: my-service-tls
      hosts:
        - my-service.hypersec.io

resources:
  limits:
    cpu: 1000m
    memory: 512Mi
  requests:
    cpu: 100m
    memory: 128Mi

autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 10
  targetCPUUtilizationPercentage: 80
  targetMemoryUtilizationPercentage: 80
```

**values-prod.yaml (overrides):**

```yaml
replicaCount: 3

resources:
  limits:
    cpu: 2000m
    memory: 1Gi
  requests:
    cpu: 500m
    memory: 512Mi

autoscaling:
  minReplicas: 3
  maxReplicas: 20
```

### ArgoCD Application

**argocd/application.yaml:**

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: my-service-prod
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/hypersec-io/my-service
    targetRevision: main
    path: helm
    helm:
      valueFiles:
        - values.yaml
        - values-prod.yaml
  destination:
    server: https://kubernetes.default.svc
    namespace: production
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

**argocd/applicationset.yaml (multi-environment):**

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: my-service
  namespace: argocd
spec:
  generators:
    - list:
        elements:
          - env: dev
            namespace: development
          - env: staging
            namespace: staging
          - env: prod
            namespace: production
  template:
    metadata:
      name: 'my-service-{{env}}'
    spec:
      project: default
      source:
        repoURL: https://github.com/hypersec-io/my-service
        targetRevision: main
        path: helm
        helm:
          valueFiles:
            - values.yaml
            - 'values-{{env}}.yaml'
      destination:
        server: https://kubernetes.default.svc
        namespace: '{{namespace}}'
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
```

---

## Secrets Management

### Docker Standalone

**Local development and testing:**

```yaml
# docker-compose.yml
services:
  myapp:
    build: .
    env_file:
      - .env  # Never commit this file
    environment:
      - DATABASE_PASSWORD=${DATABASE_PASSWORD}
    volumes:
      - ./.env:/app/.env:ro  # Read-only mount
```

**Local .env file (gitignored):**

```bash
# .env (never commit)
DATABASE_PASSWORD=local_dev_password
API_KEY=dev_api_key_123
```

**Docker secrets (production-like deployments):**

```yaml
# docker-compose.yml
services:
  myapp:
    secrets:
      - db_password
    environment:
      - DATABASE_PASSWORD_FILE=/run/secrets/db_password

secrets:
  db_password:
    file: ./secrets/db_password.txt  # Gitignored
```

### Kubernetes + HELM + ArgoCD

**Production: Use Kubernetes secrets, NOT environment variables in Dockerfile**

**HELM values.yaml:**

```yaml
# values.yaml
secrets:
  database:
    password: ""  # Injected by ArgoCD vault plugin or sealed secrets

env:
  - name: DATABASE_PASSWORD
    valueFrom:
      secretKeyRef:
        name: my-service-secrets
        key: db-password
```

**HELM templates/deployment.yaml:**

```yaml
# templates/deployment.yaml
env:
  {{- range .Values.env }}
  - name: {{ .name }}
    {{- if .valueFrom }}
    valueFrom:
      {{- toYaml .valueFrom | nindent 6 }}
    {{- else }}
    value: {{ .value | quote }}
    {{- end }}
  {{- end }}
```

**Sensitive config files (volume mounts):**

```yaml
# templates/deployment.yaml
volumeMounts:
  - name: secrets
    mountPath: /app/secrets
    readOnly: true

volumes:
  - name: secrets
    secret:
      secretName: {{ include "myapp.fullname" . }}-secrets
      items:
        - key: config.yaml
          path: config.yaml
```

**ArgoCD integration (sealed secrets or vault):**

```yaml
# argocd-application.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
spec:
  source:
    helm:
      valuesObject:
        secrets:
          database:
            password: <sealed-secret-or-vault-reference>
```

---

## CI/CD Integration

### GitHub Actions + JFrog + ArgoCD

**Workflow:** Developer pushes code → GitHub Actions builds → JFrog → ArgoCD deploys to Kubernetes

**.github/workflows/container-publish.yml:**

```yaml
name: Build and Publish Container

on:
  push:
    tags:
      - 'v*'

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Login to JFrog
        uses: docker/login-action@v3
        with:
          registry: jfrog.hypersec.io
          username: ${{ secrets.JFROG_USERNAME }}
          password: ${{ secrets.JFROG_PASSWORD }}

      - name: Extract version
        id: version
        run: echo "VERSION=${GITHUB_REF#refs/tags/v}" >> $GITHUB_OUTPUT

      - name: Build and push
        uses: docker/build-push-action@v5
        with:
          context: .
          push: true
          tags: |
            jfrog.hypersec.io/my-service:${{ steps.version.outputs.VERSION }}
            jfrog.hypersec.io/my-service:latest
```

---

## Monitoring and Observability

### Prometheus Metrics

**Expose Prometheus metrics:**

```python
from prometheus_client import make_asgi_app
from fastapi import FastAPI

app = FastAPI()

# Mount Prometheus metrics
metrics_app = make_asgi_app()
app.mount("/metrics", metrics_app)
```

**HELM service monitor:**

```yaml
# templates/servicemonitor.yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: {{ include "my-service.fullname" . }}
spec:
  selector:
    matchLabels:
      {{- include "my-service.selectorLabels" . | nindent 6 }}
  endpoints:
    - port: http
      path: /metrics
      interval: 30s
```

### Logging

**Structured JSON logging to stdout:**

```python
import logging
import json

class JSONFormatter(logging.Formatter):
    def format(self, record):
        log_data = {
            "timestamp": self.formatTime(record),
            "level": record.levelname,
            "message": record.getMessage(),
            "logger": record.name,
        }
        return json.dumps(log_data)

handler = logging.StreamHandler()
handler.setFormatter(JSONFormatter())
logging.root.addHandler(handler)
```

**Kubernetes captures stdout/stderr automatically** - use `kubectl logs` or centralized logging (ELK, Loki)

---

## Common Patterns

### Init Containers

**For database migrations:**

```yaml
# deployment.yaml
initContainers:
  - name: migrations
    image: jfrog.hypersec.io/my-service:{{ .Values.image.tag }}
    command: ["python", "-m", "myapp", "migrate"]
    env:
      - name: DATABASE_URL
        valueFrom:
          secretKeyRef:
            name: my-service-secrets
            key: database-url
```

### Sidecar Containers

**Log shipping, proxies, etc.:**

```yaml
# deployment.yaml
containers:
  - name: app
    image: jfrog.hypersec.io/my-service:{{ .Values.image.tag }}
    # ... main container config

  - name: log-shipper
    image: fluent/fluent-bit:latest
    volumeMounts:
      - name: varlog
        mountPath: /var/log
```

### ConfigMaps

**Application configuration:**

```yaml
# templates/configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ include "my-service.fullname" . }}
data:
  config.yaml: |
    server:
      host: 0.0.0.0
      port: 8000
    logging:
      level: INFO
```

---

## Troubleshooting

### Debugging Running Containers

**Exec into container:**

```bash
kubectl exec -it my-service-5d4c7b8f9-abc12 -- sh

# Test health endpoints
curl localhost:8000/health/live

# Check network connectivity
nc -zv database 5432
ping 8.8.8.8
```

### View Logs

```bash
# Recent logs
kubectl logs my-service-5d4c7b8f9-abc12

# Follow logs
kubectl logs -f my-service-5d4c7b8f9-abc12

# Previous container (after crash)
kubectl logs my-service-5d4c7b8f9-abc12 --previous
```

### Port Forwarding

```bash
# Forward local port to pod
kubectl port-forward my-service-5d4c7b8f9-abc12 8000:8000

# Access at localhost:8000
curl localhost:8000/health/live
```

---

## See Also

- [CODING-STANDARDS.md](CODING-STANDARDS.md) - General coding standards
- [CODING-STANDARDS-PYTHON.md](CODING-STANDARDS-PYTHON.md) - Python-specific standards
- [GIT.md](GIT.md) - Git and versioning
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [HELM Documentation](https://helm.sh/docs/)
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
