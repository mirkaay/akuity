#!/usr/bin/env bash
set -euo pipefail

print_section() {
  echo
  echo "============================================================"
  echo "$1"
  echo "============================================================"
}

print_section "Cluster"
kubectl get nodes -o wide

print_section "Argo CD Applications"
kubectl -n argocd get applications.argoproj.io -o wide

print_section "Argo CD Pods"
kubectl -n argocd get pods -o wide

print_section "Monitoring Pods"
kubectl -n monitoring get pods -o wide || true

print_section "Demo Workload"
kubectl -n demo get all || true

print_section "ServiceMonitors for Argo CD"
kubectl get servicemonitors.monitoring.coreos.com -A | grep -i argocd || true

print_section "PrometheusRules"
kubectl -n monitoring get prometheusrules.monitoring.coreos.com | grep -i argocd || true

print_section "Grafana Dashboard ConfigMap"
kubectl -n monitoring get configmap argocd-gitops-dashboard || true

print_section "Repo-server Helm version"
if kubectl -n argocd get deploy argocd-repo-server >/dev/null 2>&1; then
  kubectl -n argocd exec deploy/argocd-repo-server -- /usr/local/bin/helm version --short || true
fi

print_section "Prometheus targets hint"
echo "Port-forward Prometheus and check Status > Targets:"
echo "  kubectl -n monitoring port-forward svc/kube-prometheus-stack-prometheus 9090:9090"
echo "  http://localhost:9090/targets"
