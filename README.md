# Argo CD GitOps

This repository is contains a local GitOps ArgoCD setup. It bootstraps Argo CD into a kind cluster, then uses Argo CD to manage its own configuration, deploy monitoring, and continuously reconcile workloads from Git.

## What this repo demonstrates

- Argo CD is installed once, then configured to manage its own lifecycle from Git.
- Prometheus, Alertmanager, and Grafana are deployed with `kube-prometheus-stack`.
- Prometheus is configured to scrape Argo CD metrics.
- Grafana receives an Argo CD dashboard from Git.
- Prometheus receives Argo CD alert rules from Git.
- The Argo CD repovserver uses a replacement Helm binary ( Helm `v3.15.4).
- A small demo workload is included so reviewers can see an application update flow.

## Repository layout

```text
.
├── apps/                         # Argo CD child Applications managed by the root app
│   ├── argocd.yaml                # Argo CD self-management application
│   ├── demo-app.yaml              # Small demo workload application
│   ├── monitoring.yaml            # kube-prometheus-stack application
│   └── monitoring-extras.yaml     # Argo CD ServiceMonitors, alerts, and dashboard
├── bootstrap/
│   ├── argocd-bootstrap-values.yaml
│   └── root-app.yaml              # Root parent app
├── docs/
│   └── troubleshooting.md         # troubleshooting notes
├── kind/
│   └── cluster.yaml               # Local kind cluster config
├── platform/
│   ├── argocd/values.yaml         # Argo CD chart configuration
│   ├── monitoring/values.yaml     # Prometheus/Grafana chart configuration
│   └── monitoring-extras/         # Git-managed monitors, rules, dashboard
├── scripts/
│   ├── bootstrap-wsl.sh           # Main bootstrap script
│   ├── cleanup.sh                 # Delete local lab cluster
│   ├── set-repo-url.sh            # Replaces placeholder repo URL
│   └── verify.sh                  # Verification commands
└── workloads/demo-app/            # Example app watched by Argo CD
```

## Prerequisites

Docker Desktop.

install:

- Docker Desktop
- `kubectl`
- `kind`
- `helm`
- `git`

Quick checks:

```bash
docker version
kind version
kubectl version --client
helm version
```

## Deployment steps

### 1. Configure repo with Git URL

From the repo root:

```bash
chmod +x scripts/*.sh
./scripts/set-repo-url.sh https://github.com/mirkaay/akuity.git
```

### 2. Bootstrap the local cluster

```bash
./scripts/bootstrap-wsl.sh
```

What this script does:

1. Creates a kind cluster named `akuity-argocd-lab`.
2. Installs a minimal Argo CD instance using Helm.
3. Applies the root parent app.
4. Waits for the Argo CD applications to appear.

### 3. Verify the deployment

```bash
./scripts/verify.sh
```

Important checks:

```bash
kubectl get applications -n argocd
kubectl get pods -n argocd
kubectl get pods -n monitoring
kubectl get servicemonitors -A | grep argocd
kubectl get prometheusrules -n monitoring
kubectl -n argocd exec deploy/argocd-repo-server -- /usr/local/bin/helm version --short
```

Expected Helm check:

```text
v3.15.4+...
```

### 4. Access the UIs locally

Argo CD UI:

```bash
kubectl -n argocd port-forward svc/argocd-server 8080:443
```

Open:

```text
https://localhost:8080
```

Get the initial admin password:

```bash
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d; echo
```

Grafana UI:

```bash
kubectl -n monitoring port-forward svc/kube-prometheus-stack-grafana 3000:80
```

Open:

```text
http://localhost:3000
```

Default login:

```text
admin / prom-operator
```

Prometheus UI:

```bash
kubectl -n monitoring port-forward svc/kube-prometheus-stack-prometheus 9090:9090
```

Open:

```text
http://localhost:9090
```

## How Argo CD manages itself

The bootstrap install creates a minimal Argo CD instance. After that, `bootstrap/root-app.yaml` creates child Applications from the `apps/` folder.

The `argocd-self-management` Application uses the upstream Argo CD Helm chart and the values file at `platform/argocd/values.yaml`. That values file enables metrics and replaces the Helm binary used by `argocd-repo-server`.

The repo-server matters because that is the Argo CD component responsible for rendering manifests from Git, Helm charts, and Kustomize sources before the application-controller compares them with the live cluster.

## How Prometheus monitors Argo CD

The `monitoring` Application deploys `kube-prometheus-stack`, which provides Prometheus, Alertmanager, Grafana, and the Prometheus Operator CRDs.

The `monitoring-extras` Application adds:

- `ServiceMonitor` resources for Argo CD metrics endpoints
- `PrometheusRule` alerts for Argo CD app health/sync state and repo-server availability
- A Grafana dashboard ConfigMap for Argo CD status


## Troubleshooting notes

See [`docs/troubleshooting.md`](docs/troubleshooting.md) for a full list. At a high level, I would check:

- Argo CD Application sync and health status
- repo-server logs for manifest generation or Helm rendering errors
- application-controller logs for reconciliation errors
- Kubernetes events and pod logs for runtime failures
- ServiceMonitor selection and Prometheus targets for monitoring failures
- PrometheusRule status and Grafana sidecar logs for dashboard/alert issues

## Cleanup

```bash
./scripts/cleanup.sh
```
