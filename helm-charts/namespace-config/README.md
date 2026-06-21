Namespace Config Helm Chart Documentation
=========================================

Overview
--------

The **Namespace Config Helm Chart** facilitates the creation and management of **NamespaceConfig** resources for Kubernetes/OpenShift environments. It enables administrators to configure namespaces dynamically, applying labels, annotations, and custom templates for resource provisioning.

* * * * *

Prerequisites
-------------

-   OpenShift 4.x.
-   Helm 3.x.
-   `NamespaceConfigOperator` is installed.

* * * * *

Installing the Chart
--------------------

Refer to [this doc](../README.md#usage) for the instructions on adding EXAMPLE_ORG helm charts.

### Installing the Chart

To install the chart with the release name `namespace-config`, run:

```bash
helm install namespace-config example-org/namespace-config
```

### Customizing Installation

You can customize the deployment using a `values.yaml` file or by using the `--set` command-line flag.

* * * * *

Uninstalling the Chart
----------------------

To uninstall the chart and its resources:

```bash
helm uninstall namespace-config
```

* * * * *

Configuration
-------------

The `values.yaml` file defines the configuration for `NamespaceConfig` resources, enabling dynamic resource creation in selected namespaces.

### Key Parameters

| Parameter | Description | Example |
| --- | --- | --- |
| `namespace.[resource-name]` | The `NamespaceConfig` resource name | `service-mesh` |
| `namespace.[resource-name].labelSelector` | Labels to match namespaces for configuration | `{ istio-injection: enabled }` |
| `namespace.[resource-name].annotationSelector` | Annotations to match namespaces for configuration | `{ built-by: argocd }` |
| `namespace.[resource-name].templates` | Templates for resources like PodMonitors and NetworkPolicies | See example below. |


### Example Values

```yaml
namespace:
  service-mesh:
    labelSelector:
      matchLabels:
        istio-injection: enabled
    templates:
      - |
        apiVersion: monitoring.coreos.com/v1
        kind: PodMonitor
        metadata:
          name: istio-proxies-monitor
          namespace: "{{ .Name }}"
        spec:
          selector:
            matchExpressions:
            - key: istio-prometheus-ignore
              operator: DoesNotExist
          podMetricsEndpoints:
          - path: /stats/prometheus
            interval: 30s
            relabelings:
            - action: keep
              sourceLabels: [__meta_kubernetes_pod_container_name]
              regex: "istio-proxy"
            - action: keep
              sourceLabels: [__meta_kubernetes_pod_annotationpresent_prometheus_io_scrape]
            - action: replace
              regex: (\d+);(([A-Fa-f0-9]{1,4}::?){1,7}[A-Fa-f0-9]{1,4})
              replacement: '[$2]:$1'
              sourceLabels: [__meta_kubernetes_pod_annotation_prometheus_io_port, __meta_kubernetes_pod_ip]
              targetLabel: __address__
            - action: replace
              regex: (\d+);((([0-9]+?)(\.|$)){4})
              replacement: $2:$1
              sourceLabels: [__meta_kubernetes_pod_annotation_prometheus_io_port, __meta_kubernetes_pod_ip]
              targetLabel: __address__
            - action: labeldrop
              regex: "__meta_kubernetes_pod_label_(.+)"
            - sourceLabels: [__meta_kubernetes_namespace]
              action: replace
              targetLabel: namespace
            - sourceLabels: [__meta_kubernetes_pod_name]
              action: replace
              targetLabel: pod_name
            - action: replace
              replacement: "basic-istio-system"
              targetLabel: mesh_id
      - |
        apiVersion: networking.k8s.io/v1
        kind: NetworkPolicy
        metadata:
          name: user-workload-access
          namespace: "{{ .Name }}"
        spec:
          ingress:
          - from:
            - namespaceSelector:
                matchLabels:
                  network.openshift.io/policy-group: monitoring # openshift-monitoring and openshift-user-workload-monitoring
          podSelector: {}
          policyTypes:
          - Ingress
```