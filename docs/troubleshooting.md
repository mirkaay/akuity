# Troubleshooting Notes

These are the troubleshooting steps I would take in a prod environment.

## 1. Start with Argo CD Application state

```bash
kubectl -n argocd get applications.argoproj.io
kubectl -n argocd describe application <app_name>
```

Check:

- Is the app `Synced` or `OutOfSync`?
- Is the app `Healthy`, `Progressing`, `Degraded`, or `Missing`?
- Does the app show a manifest generation error?
- Does the app show a permission error?

## 2. If manifest generation fails


Check repo server logs:

```bash
kubectl -n argocd logs deploy/argocd-repo-server
kubectl -n argocd exec deploy/argocd-repo-server -- /usr/local/bin/helm version --short
```

Likely causes:

- Wrong repo URL
- Wrong path
- Missing values file
- Broken Helm chart
- Invalid YAML
- Git credentials issue
- Custom Helm binary download or mount issue


## 3. If monitoring does not pick argo targets

Check ServiceMonitors:

```bash
kubectl get servicemonitors.monitoring.coreos.com -A | grep argocd
kubectl -n monitoring describe servicemonitor argocd-server
kubectl -n monitoring describe servicemonitor argocd-repo-server
```

Check Prometheus targets:

```bash
kubectl -n monitoring port-forward svc/kube-prometheus-stack-prometheus 9090:9090
```


## 4. If dashboards are not appearing in Grafana

Check dashboard ConfigMap:

```bash
kubectl -n monitoring get configmap argocd-gitops-dashboard -o yaml
```

Check Grafana sidecar logs:

```bash
kubectl -n monitoring logs deploy/kube-prometheus-stack-grafana -c grafana-sc-dashboard
```

Likely causes:

- ConfigMap missing the expected dashboard label
- Grafana sidecar not enabled
- Dashboard JSON is invalid

## 5. If Prometheus alerts do not appear

Check rule object:

```bash
kubectl -n monitoring get prometheusrules.monitoring.coreos.com
kubectl -n monitoring describe prometheusrule argocd-gitops-alerts
```

Check Prometheus UI:

```text
http://localhost:9090/rules
http://localhost:9090/alerts
```

Likely causes:

- PrometheusRule CRD not installed yet
- Prometheus rule selector does not select the rule
- PromQL expression does not match any scraped series
- Argo CD metrics targets are down

## 6. If Application is stuck with OutOfSync

Check the diff:

```bash
argocd app diff <app-name>
```

or use the Argo CD UI.

Likely causes:

- Manual changes were made with `kubectl`
- Kubernetes defaulted or mutated fields
- A controller changed fields after Argo CD applied them
- Git contains a different desired state than expected
- Some resources require ignore difference customization

## 7. If an Application is synced but unhealthy

This is usually a Kubernetes runtime issue, not a Git issue.

Check:

```bash
kubectl get pods -n <namespace>
kubectl describe pod <pod-name> -n <namespace>
kubectl logs <pod-name> -n <namespace>
kubectl get events -n <namespace> --sort-by=.lastTimestamp
```

Likely causes:

- CrashLoopBackOff
- ImagePullBackOff
- Pending pods due to insufficient resources
- Readiness probe failures
- Missing ConfigMap or Secret
- RBAC or service account issue

## 8. If kind cluster creation fails on Windows/WSL2

Check:

```bash
docker version
docker info | grep -i -E "cgroup|server version|operating system|ostype|architecture"
kind version
cat kind/cluster.yaml
````
