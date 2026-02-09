---
name: kubernetes-standards
description: Kubernetes and Helm standards for deployments, services, and health probes. Use when writing K8s manifests, Helm charts, or deploying to Kubernetes.
---

# Kubernetes Standards for HyperI Projects

**Runtime standards: HELM charts, deployments, services, ArgoCD, KEDA**

**Prerequisites:** All containers must follow [DOCKER.md](DOCKER.md) standards before K8s deployment. See the "Docker → Kubernetes Promotion" section for the K8s-ready checklist.

---

## Quick Reference

```bash
kubectl get pods                # List pods
kubectl logs -f <pod>           # Stream logs
kubectl describe pod <pod>      # Pod details
kubectl apply -f manifest.yaml  # Apply manifest
helm install <name> <chart>     # Install chart
helm upgrade <name> <chart>     # Upgrade release
```

---

## HELM Chart Structure

```text
mychart/
├── Chart.yaml                  # Chart metadata
├── values.yaml                 # Default values
├── values-dev.yaml             # Dev overrides
├── values-prod.yaml            # Prod overrides
├── templates/
│   ├── _helpers.tpl            # Template helpers
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── configmap.yaml
│   ├── secret.yaml
│   ├── ingress.yaml
│   ├── hpa.yaml
│   └── NOTES.txt
└── charts/                     # Dependencies
```

---

## Chart.yaml

```yaml
apiVersion: v2
name: dfe-discovery
description: Discovery service for DFE platform
type: application
version: 0.3.0              # Chart version (semver)
appVersion: "1.16.0"        # Application version (quoted string)

# Prefer in-cluster operators over Helm chart dependencies
# See "Prohibited: Bitnami Charts" section below
```

### Prohibited: Bitnami Charts

**Never use Bitnami Helm charts** for any infrastructure component.

```yaml
# ❌ Prohibited - Bitnami charts
dependencies:
  - name: postgresql
    repository: "https://charts.bitnami.com/bitnami"
  - name: redis
    repository: "https://charts.bitnami.com/bitnami"
  - name: kafka
    repository: "https://charts.bitnami.com/bitnami"
```

**Why Bitnami charts are prohibited:**

- **Non-standard configurations:** Unusual paths, permissions, and entrypoints
- **Debugging difficulty:** Non-standard tooling and log locations
- **Upgrade complexity:** Breaking changes between versions
- **Operator alternative:** CloudNativePG, Redis Operator, Strimzi are superior

**Preferred alternatives with install commands:**

| Component | Instead of Bitnami | Use | Install |
| --------- | ------------------ | --- | ------- |
| PostgreSQL | `bitnami/postgresql` | CloudNativePG | `helm install cnpg cloudnative-pg/cloudnative-pg -n cnpg-system` |
| Kafka | `bitnami/kafka` | Strimzi | `helm install strimzi strimzi/strimzi-kafka-operator -n kafka` |
| Kafka | `bitnami/kafka` | AutoMQ | See [automq.com/docs](https://docs.automq.com/) |
| ClickHouse | `bitnami/clickhouse` | Altinity Operator | `helm install clickhouse-operator altinity/clickhouse-operator` |
| Redis | `bitnami/redis` | Spotahome Operator | `helm install redis-operator spotahome/redis-operator` |
| MongoDB | `bitnami/mongodb` | Community Operator | `helm install mongodb mongodb/community-operator` |
| Elasticsearch | `bitnami/elasticsearch` | ECK | `helm install elastic-operator elastic/eck-operator -n elastic-system` |
| ArgoCD | `bitnami/argo-cd` | Official Chart | `helm install argocd argo/argo-cd -n argocd` |
| MinIO | `bitnami/minio` | MinIO Operator | `helm install minio-operator minio/operator -n minio-operator` |

**Helm repositories:**

```bash
# Add required Helm repos
helm repo add cloudnative-pg https://cloudnative-pg.github.io/charts
helm repo add strimzi https://strimzi.io/charts/
helm repo add altinity https://docs.altinity.com/clickhouse-operator/
helm repo add spotahome https://spotahome.github.io/redis-operator
helm repo add mongodb https://mongodb.github.io/helm-charts
helm repo add elastic https://helm.elastic.co
helm repo add argo https://argoproj.github.io/argo-helm
helm repo add minio https://operator.min.io/
helm repo update
```

**HyperI standard stack:**

| Component | What We Use |
| --------- | ----------- |
| PostgreSQL | CloudNativePG Operator |
| Kafka/Streaming | AutoMQ (Kafka-compatible, S3-backed) |
| ClickHouse | Altinity ClickHouse Operator |
| Log Collection | Vector (vector.dev) |
| GitOps | ArgoCD (official Helm chart) |
| Package Management | Helm 3 |

**Example - CloudNativePG instead of Bitnami PostgreSQL:**

```yaml
# ✅ CloudNativePG Cluster (operator-managed)
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: myapp-db
spec:
  instances: 3
  storage:
    size: 10Gi
  postgresql:
    parameters:
      max_connections: "200"
```

---

## values.yaml Patterns

```yaml
# Image configuration
image:
  repository: registry.example.com/myapp
  tag: ""                       # Defaults to Chart.appVersion
  pullPolicy: IfNotPresent

imagePullSecrets:
  - name: registry-credentials

# Replicas and scaling
replicaCount: 2

autoscaling:
  enabled: false
  minReplicas: 2
  maxReplicas: 10
  targetCPUUtilizationPercentage: 80

# Resources (always specify!)
resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 500m
    memory: 512Mi

# Health probes
livenessProbe:
  httpGet:
    path: /health/live
    port: http
  initialDelaySeconds: 10
  periodSeconds: 10
  failureThreshold: 3

readinessProbe:
  httpGet:
    path: /health/ready
    port: http
  initialDelaySeconds: 5
  periodSeconds: 5
  failureThreshold: 2

startupProbe:
  httpGet:
    path: /health/startup
    port: http
  failureThreshold: 30
  periodSeconds: 5

# Service configuration
service:
  type: ClusterIP
  port: 80
  targetPort: 8080

# Gateway API HTTPRoute (preferred over Ingress)
# See "Ingress Policy: Gateway API over Ingress" section
httpRoute:
  enabled: true
  parentRefs:
    - name: main-gateway
      namespace: gateway-system
  hostnames:
    - app.example.com

# Legacy Ingress (only for existing workloads, migrate to Gateway API)
ingress:
  enabled: false  # Disabled by default - use httpRoute
  className: ""   # Do not default to nginx
  annotations: {}
  hosts: []
  tls: []

# Global values (shared across charts)
global:
  tenancy_name: dfe
  appSecretName: app-secrets
```

---

## Ingress Policy: Gateway API over Ingress

**Default policy for HTTP routing:**

### New Workloads

**Use Gateway API with Envoy-based controllers:**

```yaml
# ✅ Gateway API - the standard for new workloads
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: myapp-route
spec:
  parentRefs:
    - name: main-gateway
      namespace: gateway-system
  hostnames:
    - "app.example.com"
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /api
      backendRefs:
        - name: myapp
          port: 80
```

```yaml
# Gateway (typically cluster-wide, managed by platform team)
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: main-gateway
  namespace: gateway-system
spec:
  gatewayClassName: envoy  # or contour
  listeners:
    - name: https
      port: 443
      protocol: HTTPS
      tls:
        mode: Terminate
        certificateRefs:
          - name: wildcard-tls
```

**Recommended Envoy-based controllers:**

| Controller | Use Case |
| ---------- | -------- |
| Envoy Gateway | Standard choice, CNCF project |
| Contour | Mature, Envoy-based, good for multi-team |
| Istio Gateway | If already using Istio service mesh |

**Do NOT introduce new Ingress resources** unless there's an explicit exception.

### Existing Workloads

| Current State | Action |
| ------------- | ------ |
| Ingress (simple) | Migrate to Gateway API on your schedule |
| Ingress + NGINX annotations/snippets | Keep NGINX short-term, plan explicit refactor |

**NGINX annotations are technical debt.** Snippets like `nginx.ingress.kubernetes.io/configuration-snippet` are:

- Non-portable (NGINX-specific)
- Security risk (raw config injection)
- Hard to audit and maintain

```yaml
# ❌ Technical debt - NGINX-specific annotations
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  annotations:
    nginx.ingress.kubernetes.io/configuration-snippet: |
      more_set_headers "X-Custom-Header: value";
    nginx.ingress.kubernetes.io/proxy-body-size: "50m"
    nginx.ingress.kubernetes.io/use-regex: "true"
```

```yaml
# ✅ Gateway API - portable, type-safe
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: myapp
spec:
  rules:
    - matches:
        - path:
            type: RegularExpression
            value: "/api/v[0-9]+/.*"
      filters:
        - type: ResponseHeaderModifier
          responseHeaderModifier:
            add:
              - name: X-Custom-Header
                value: value
      backendRefs:
        - name: myapp
          port: 80
```

### Migration Path

1. **Audit current Ingress resources** - identify NGINX-specific annotations
2. **Deploy Envoy Gateway** alongside NGINX (parallel operation)
3. **Migrate simple Ingress first** - routes without custom annotations
4. **Refactor annotated routes** - replace snippets with Gateway API filters
5. **Decommission NGINX** once all routes migrated

---

## Template Helpers (_helpers.tpl)

```yaml
{{/*
Create chart name and version for labels.
*/}}
{{- define "mychart.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "mychart.labels" -}}
helm.sh/chart: {{ include "mychart.chart" . }}
{{ include "mychart.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "mychart.selectorLabels" -}}
app.kubernetes.io/name: {{ include "mychart.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Fully qualified app name
*/}}
{{- define "mychart.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
```

---

## Deployment Template

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "mychart.fullname" . }}
  labels:
    {{- include "mychart.labels" . | nindent 4 }}
spec:
  {{- if not .Values.autoscaling.enabled }}
  replicas: {{ .Values.replicaCount }}
  {{- end }}
  selector:
    matchLabels:
      {{- include "mychart.selectorLabels" . | nindent 6 }}
  template:
    metadata:
      annotations:
        checksum/config: {{ include (print $.Template.BasePath "/configmap.yaml") . | sha256sum }}
      labels:
        {{- include "mychart.selectorLabels" . | nindent 8 }}
    spec:
      {{- with .Values.imagePullSecrets }}
      imagePullSecrets:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      serviceAccountName: {{ include "mychart.serviceAccountName" . }}
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        fsGroup: 1000
      containers:
        - name: {{ .Chart.Name }}
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag | default .Chart.AppVersion }}"
          imagePullPolicy: {{ .Values.image.pullPolicy }}
          ports:
            - name: http
              containerPort: {{ .Values.service.targetPort }}
              protocol: TCP
          env:
            - name: POD_NAME
              valueFrom:
                fieldRef:
                  fieldPath: metadata.name
            {{- range $key, $value := .Values.env }}
            - name: {{ $key }}
              value: {{ $value | quote }}
            {{- end }}
          envFrom:
            - secretRef:
                name: {{ .Values.global.appSecretName }}
          livenessProbe:
            {{- toYaml .Values.livenessProbe | nindent 12 }}
          readinessProbe:
            {{- toYaml .Values.readinessProbe | nindent 12 }}
          {{- if .Values.startupProbe }}
          startupProbe:
            {{- toYaml .Values.startupProbe | nindent 12 }}
          {{- end }}
          resources:
            {{- toYaml .Values.resources | nindent 12 }}
      {{- with .Values.nodeSelector }}
      nodeSelector:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.tolerations }}
      tolerations:
        {{- toYaml . | nindent 8 }}
      {{- end }}
```

---

## Health Endpoints

**Required for all services:**

| Endpoint | Purpose | K8s Probe |
|----------|---------|-----------|
| `/health/live` | Process alive? | livenessProbe |
| `/health/ready` | Can handle traffic? | readinessProbe |
| `/health/startup` | Initialization done? | startupProbe |

```python
# FastAPI example
@app.get("/health/live")
async def liveness():
    return {"status": "alive"}

@app.get("/health/ready")
async def readiness():
    if not await check_dependencies():
        return Response(status_code=503)
    return {"status": "ready"}

@app.get("/health/startup")
async def startup():
    if not app_initialized:
        return Response(status_code=503)
    return {"status": "started"}
```

---

## ArgoCD Application

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: myapp
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/org/repo.git
    targetRevision: HEAD
    path: charts/myapp
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

---

## KEDA Autoscaling

```yaml
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: myapp-scaler
spec:
  scaleTargetRef:
    name: myapp
  minReplicaCount: 2
  maxReplicaCount: 20
  pollingInterval: 30
  cooldownPeriod: 300
  triggers:
    # CPU-based scaling
    - type: cpu
      metricType: Utilization
      metadata:
        value: "80"

    # Kafka consumer lag
    - type: kafka
      metadata:
        bootstrapServers: kafka:9092
        consumerGroup: myapp-group
        topic: events
        lagThreshold: "100"

    # Prometheus metrics
    - type: prometheus
      metadata:
        serverAddress: http://prometheus:9090
        metricName: http_requests_total
        threshold: "100"
        query: sum(rate(http_requests_total{app="myapp"}[2m]))
```

---

## ConfigMaps and Secrets

### ConfigMap

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ include "mychart.fullname" . }}-config
data:
  config.yaml: |
    server:
      port: {{ .Values.service.targetPort }}
    logging:
      level: {{ .Values.logLevel | default "info" }}
  {{- range $key, $value := .Values.configFiles }}
  {{ $key }}: |
    {{- $value | nindent 4 }}
  {{- end }}
```

### External Secrets (with ESO)

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: {{ include "mychart.fullname" . }}-secrets
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: vault-backend
    kind: ClusterSecretStore
  target:
    name: {{ .Values.global.appSecretName }}
  data:
    - secretKey: DATABASE_PASSWORD
      remoteRef:
        key: myapp/database
        property: password
    - secretKey: API_KEY
      remoteRef:
        key: myapp/api
        property: key
```

---

## Network Policies

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: {{ include "mychart.fullname" . }}-netpol
spec:
  podSelector:
    matchLabels:
      {{- include "mychart.selectorLabels" . | nindent 6 }}
  policyTypes:
    - Ingress
    - Egress
  ingress:
    # Allow from ingress controller
    - from:
        - namespaceSelector:
            matchLabels:
              name: ingress-nginx
      ports:
        - port: http
    # Allow from same namespace
    - from:
        - podSelector: {}
  egress:
    # Allow DNS
    - to:
        - namespaceSelector: {}
      ports:
        - port: 53
          protocol: UDP
    # Allow to database
    - to:
        - podSelector:
            matchLabels:
              app: postgresql
      ports:
        - port: 5432
```

---

## Resource Management

### Resource Quotas

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: {{ .Release.Namespace }}-quota
spec:
  hard:
    requests.cpu: "10"
    requests.memory: 20Gi
    limits.cpu: "20"
    limits.memory: 40Gi
    pods: "50"
```

### Limit Ranges

```yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: default-limits
spec:
  limits:
    - default:
        cpu: 500m
        memory: 512Mi
      defaultRequest:
        cpu: 100m
        memory: 128Mi
      type: Container
```

---

## Best Practices

### Always Specify

- Resource requests AND limits
- Health probes (all three)
- Security context (non-root)
- Image pull policy
- Pod disruption budget

### Never Do

- Use `latest` tag in production
- Store secrets in ConfigMaps
- Run as root
- Skip health probes
- Hardcode environment-specific values

### Labels Required

```yaml
labels:
  app.kubernetes.io/name: myapp
  app.kubernetes.io/instance: myapp-prod
  app.kubernetes.io/version: "1.0.0"
  app.kubernetes.io/component: backend
  app.kubernetes.io/part-of: myplatform
  app.kubernetes.io/managed-by: helm
```

---

## Debugging

```bash
# Get pod logs
kubectl logs -f deployment/myapp --all-containers

# Execute into pod
kubectl exec -it pod/myapp-xxx -- /bin/sh

# Port forward for local access
kubectl port-forward svc/myapp 8080:80

# Describe for events
kubectl describe pod myapp-xxx

# Get all resources for app
kubectl get all -l app.kubernetes.io/name=myapp
```

---

## See Also

- [DOCKER.md](DOCKER.md) - Container image standards, Dockerfile best practices, Docker → K8s promotion checklist
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [HELM Best Practices](https://helm.sh/docs/chart_best_practices/)
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [KEDA Documentation](https://keda.sh/docs/)
