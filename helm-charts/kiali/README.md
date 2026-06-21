Kiali Helm Chart
================

Overview
--------

This Helm chart is designed to deploy and configure Kiali, a service mesh observability tool, in an OpenShift environment. It integrates with Prometheus, Grafana, Istio, and other external services to provide insights into the service mesh, including metrics, traces, and status of various Istio components.

Prerequisites
-------------

-   OpenShift or Kubernetes cluster with Istio or OpenShift Service Mesh installed
-   Helm 3.x
-   Required external services (e.g., Prometheus, Grafana) for monitoring

Installing the Chart
--------------------

Refer to [this doc](../README.md#usage) for the instructions on adding EXAMPLE_ORG helm charts.


To install the chart with the release name `my-release`, run:

```bash
helm install my-release example-org/kiali
```


Uninstalling the Chart
----------------------

To uninstall/delete the `my-release` deployment:

```bash
helm uninstall my-release
```

This command removes all Kubernetes components associated with the release.

Configuration
-------------

The chart is highly configurable through the `values.yaml` file, where you can define various settings related to Kiali, external services, and Istio integration.

### Key Parameters

| Parameter | Description | Default |
| --- | --- | --- |
| `name` | Name of the Kiali deployment | `kiali-user-workload-monitoring` |
| `serviceAccount` | Name of the ServiceAccount for Kiali | `kiali-service-account` |
| `k8sRoleName` | Kubernetes Role name for monitoring permissions | `cluster-monitoring-view` |
| `version` | Version of Kiali (required for compatibility with CRDs) | `v1.73` |
| `externalServices.grafana.enabled` | Whether to enable Grafana integration | `false` |
| `externalServices.prometheus.auth.type` | Authentication type for Prometheus | `bearer` |
| `externalServices.prometheus.auth.useKialiToken` | Use Kiali token for Prometheus authentication | `true` |
| `externalServices.prometheus.url` | URL for Prometheus | `https://thanos-querier.openshift-monitoring.svc.cluster.local:9091` |
| `externalServices.tracing.enabled` | Whether to enable tracing integration | `true` |
| `externalServices.tracing.inClusterUrl` | URL for tracing (in-cluster) | `http://tempo-tempo-query-frontend.tracing-system.svc.cluster.local:16685` |
| `externalServices.istio.componentStatus.enabled` | Enable Istio component status monitoring | `true` |
| `externalServices.istio.configMapName` | ConfigMap name for Istio | `istio-basic` |
| `externalServices.istio.istiodDeploymentName` | Deployment name for Istio | `istiod-basic` |
| `externalServices.istio.urlServiceVersion` | URL for Istio version service | `http://istiod-basic.istio-system:15014/version` |

### Customizing Parameters

You can modify the default values by passing custom configurations using the `--set` flag or by creating a custom `values.yaml` file.

Example of setting custom values via the command line:

```bash
helm install my-release example-org/kiali --set version=v1.74 --set externalServices.grafana.enabled=true
```

Alternatively, use a custom `values.yaml` file:

```bash
helm install my-release example-org/kiali -f my-values.yaml
```

### Example Values File

Below is an example `values.yaml` configuration:

```yaml
name: kiali-user-workload-monitoring
serviceAccount: kiali-service-account
k8sRoleName: cluster-monitoring-view
version: v1.73
externalServices:
  grafana:
    enabled: false
  prometheus:
    auth:
      type: bearer
      useKialiToken: true
    queryScope:
      meshId: basic-istio-system
    thanosProxy:
      enabled: true
    url: https://thanos-querier.openshift-monitoring.svc.cluster.local:9091
  tracing:
    queryTimeout: 300
    enabled: true
    inClusterUrl: http://tempo-tempo-query-frontend.tracing-system.svc.cluster.local:16685
    useGrpc: true
  istio:
    componentStatus:
      enabled: true
      components:
        - appLabel: istiod
          isCore: true
        - appLabel: example-org-ingress
          isCore: true
          isProxy: true
          namespace: istio-ingress
    configMapName: istio-basic
    envoyAdminLocalPort: 15000
    ingressGatewayNamespace: istio-ingress
    istioApiEnabled: true
    istiodDeploymentName: istiod-basic
    istioSidecarInjectorConfigMapName: istio-sidecar-injector-basic
    istiodPodMonitoringPort: 15014
    urlServiceVersion: http://istiod-basic.istio-system:15014/version
```