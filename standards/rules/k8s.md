---
paths:
  - "**/Chart.yaml"
  - "**/values.yaml"
  - "**/templates/**/*.yaml"
---

## Chart.yaml

- `apiVersion: v2`, `type: application`
- `version` = chart semver; `appVersion` = app version as quoted string

## Prohibited: Bitnami Charts

- **Never use any Bitnami Helm chart** — use operators instead:

| Component | Use Instead | Install |
|-----------|------------|---------|
| PostgreSQL | CloudNativePG | `helm install cnpg cloudnative-pg/cloudnative-pg -n cnpg-system` |
| Kafka | Strimzi or AutoMQ | `helm install strimzi strimzi/strimzi-kafka-operator -n kafka` |
| ClickHouse | Altinity Operator | `helm install clickhouse-operator altinity/clickhouse-operator` |
| Redis | Spotahome Operator | `helm install redis-operator spotahome/redis-operator` |
| MongoDB | Community Operator | `helm install mongodb mongodb/community-operator` |
| Elasticsearch | ECK | `helm install elastic-operator elastic/eck-operator -n elastic-system` |
| ArgoCD | Official Chart | `helm install argocd argo/argo-cd -n argocd` |
| MinIO | MinIO Operator | `helm install minio-operator minio/operator -n minio-operator` |

## values.yaml Patterns

- `image.tag: ""` — default to `Chart.appVersion`
- `image.pullPolicy: IfNotPresent`
- Always specify `resources.requests` AND `resources.limits`
- Always define all three health probes: liveness, readiness, startup
- Health endpoints: `/health/live`, `/health/ready`, `/health/startup`
- `service.type: ClusterIP` as default
- Use `httpRoute` (Gateway API) by default; `ingress.enabled: false`
- Use `global` values for cross-chart shared config (e.g., `global.appSecretName`)

## Ingress Policy: Gateway API over Ingress

- **New workloads:** Use Gateway API (`HTTPRoute`) with Envoy-based controllers (Envoy Gateway, Contour, or Istio Gateway)
- **Never introduce new `Ingress` resources** without explicit exception
- NGINX annotations are technical debt — non-portable, security risk, hard to audit

```yaml
# ❌ NGINX-specific annotations
annotations:
  nginx.ingress.kubernetes.io/configuration-snippet: |
    more_set_headers "X-Custom-Header: value";
```
```yaml
# ✅ Gateway API HTTPRoute with filters
filters:
  - type: ResponseHeaderModifier
    responseHeaderModifier:
      add:
        - name: X-Custom-Header
          value: value
```

- Existing simple Ingress: migrate to Gateway API on your schedule
- Existing NGINX-annotated Ingress: keep short-term, plan explicit refactor

## Template Helpers (_helpers.tpl)

- Define `mychart.chart`, `mychart.labels`, `mychart.selectorLabels`, `mychart.fullname`
- Truncate names to 63 chars, trim trailing `-`
- Always include standard labels via helper: `helm.sh/chart`, `app.kubernetes.io/version`, `app.kubernetes.io/managed-by`

## Deployment Template Rules

- Use `checksum/config` annotation on pod template to trigger rollout on configmap change
- Set `securityContext: runAsNonRoot: true, runAsUser: 1000, fsGroup: 1000`
- Inject `POD_NAME` via downward API
- Use `envFrom` with `secretRef` for secrets (via External Secrets Operator)
- Use `.Values.image.tag | default .Chart.AppVersion` for image tag
- Conditionally set `replicas` only when `autoscaling.enabled` is false

## Health Endpoints

| Endpoint | Probe | Purpose |
|----------|-------|---------|
| `/health/live` | livenessProbe | Process alive |
| `/health/ready` | readinessProbe | Can handle traffic (check deps) |
| `/health/startup` | startupProbe | Init complete |

- Liveness: `initialDelaySeconds: 10`, `periodSeconds: 10`, `failureThreshold: 3`
- Readiness: `initialDelaySeconds: 5`, `periodSeconds: 5`, `failureThreshold: 2`
- Startup: `failureThreshold: 30`, `periodSeconds: 5`

## ArgoCD Application

- `syncPolicy.automated: prune: true, selfHeal: true`
- Use `syncOptions: [CreateNamespace=true]`
- Use multiple `valueFiles` for env-specific overrides (e.g., `values.yaml` + `values-prod.yaml`)

## KEDA Autoscaling

- Set `minReplicaCount`, `maxReplicaCount`, `pollingInterval`, `cooldownPeriod`
- Supported triggers: `cpu`, `kafka` (with `lagThreshold`), `prometheus` (with PromQL `query`)

## Secrets

- Never store secrets in ConfigMaps
- Use External Secrets Operator (`ExternalSecret` CRD) with `ClusterSecretStore`
- Set `refreshInterval` on ExternalSecret resources

## Network Policies

- Define both `Ingress` and `Egress` policy types
- Allow DNS egress (port 53/UDP) to all namespaces
- Restrict ingress to ingress controller namespace and same-namespace pods
- Restrict egress to specific backends (e.g., database port)

## Required Labels

- `app.kubernetes.io/name`, `app.kubernetes.io/instance`, `app.kubernetes.io/version`
- `app.kubernetes.io/component`, `app.kubernetes.io/part-of`, `app.kubernetes.io/managed-by`

## Resource Management

- Define `ResourceQuota` per namespace (cpu, memory, pod count)
- Define `LimitRange` with default requests/limits per container

## Never Do

- Use `latest` tag in production
- Run containers as root
- Skip any of the three health probes
- Hardcode environment-specific values in templates
- Use Bitnami charts for any infrastructure component
- Introduce new NGINX Ingress resources
- Omit resource requests or limits

## Always Do

- Specify resource requests AND limits on every container
- Include all three health probes
- Set `securityContext` with `runAsNonRoot: true`
- Set `imagePullPolicy` explicitly
- Define a `PodDisruptionBudget`
- Use semver for chart version
- Quote `appVersion` in Chart.yaml
