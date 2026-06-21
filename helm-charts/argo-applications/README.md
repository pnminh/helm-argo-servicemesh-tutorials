Argo Applications Helm Chart
============================

Overview
--------

The `argo-applications` Helm chart is designed to manage and deploy multiple Argo CD Applications in a Kubernetes cluster. It integrates with Argo CD to handle the synchronization and deployment of various services in a controlled manner, including defining sync waves for subsequent deployments.

Prerequisites
-------------

-   OpenShift 4.x
-   Helm 3.x
-   Argo CD installed and configured in the cluster

Installing the Chart
--------------------

Refer to [this doc](../README.md#usage) for the instructions on adding EXAMPLE_ORG helm charts.


To install the chart with the release name `my-release`, run:

```bash
helm install my-release example-org/argo-applications
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

The `values.yaml` file allows customization of various aspects of the Argo CD applications that are managed by the chart. You can modify this file or override specific values when installing or upgrading the chart.

### Key Configuration Parameters

Here are some key parameters that can be customized in the `values.yaml` file:

| Parameter | Description | Default |
| --- | --- | --- |
| `gitRepoUrl` | The URL of the Git repository containing the charts | `https://github.example-org.com/your-repo/your-charts.git` |
| `gitTargetRevision` | The target Git branch or revision | `main` |
| `global.clusterName` | The name of the cluster | `dev` |
| `argoProject` | The Argo CD project under which applications are grouped | `default` |
| `appsDir` | The directory within the repo containing the application charts | `apps/service-mesh/charts` |
| `syncPolicy` | Specifies how applications should be synchronized | Automated with prune and self-heal enabled |
| `apps` | Defines individual applications, their namespaces, and sync waves | See below |

### Sync Policy

The `syncPolicy` section configures how Argo CD should synchronize the applications. By default, the chart uses an automated sync policy:

```yaml
syncPolicy:
  automated:
    prune: true
    selfHeal: true
```
This ensures that the application will automatically sync, prune old resources, and self-heal when resources drift from the desired state.

### Applications Configuration

The `apps` section of `values.yaml` defines the applications to be managed by Argo CD. Each application can specify its namespace, whether it is enabled, and the sync wave, which dictates the order in which the applications are deployed.

Here's an example configuration for several applications:

```yaml
apps:
  operators:
    namespace: service-mesh
    enabled: true
    syncWave: 0
  istio-system:
    namespace: istio-system
    enabled: true
    syncWave: 1
  istio-ingress:
    namespace: istio-ingress
    enabled: true
    syncWave: 2
  tracing-system:
    namespace: tracing-system
    enabled: true
    syncWave: 3
```
-   **`syncWave`**: Determines the order in which applications are deployed. Applications with lower sync wave numbers are deployed first. For example, `operators` will be deployed first (syncWave 0), followed by `istio-system` (syncWave 1), and so on.

### Example Values

Below is an example `values.yaml` configuration:

```yaml
gitRepoUrl: https://github.example-org.com/your-repo/your-charts.git
global:
  clusterName: dev
gitTargetRevision: main
argoProject: default
clusterName: "{{ .Values.global.clusterName }}"
syncPolicy:
  automated:
    prune: true
    selfHeal: true
appsDir: apps/service-mesh/charts
apps:
  operators:
    namespace: service-mesh
    enabled: true
    syncWave: 0
  istio-system:
    namespace: istio-system
    enabled: true
    syncWave: 1
  istio-ingress:
    namespace: istio-ingress
    enabled: true
    syncWave: 2
  tracing-system:
    namespace: tracing-system
    enabled: true
    syncWave: 3
```
### Customizing with the `values.yaml` File

You can customize the configuration by modifying the `values.yaml` file or by passing overrides through the Helm CLI:

```bash
helm install my-release example-org/argo-applications --set global.clusterName=prod
```

Alternatively, use a custom `values.yaml` file:

```bash
helm install my-release example-org/argo-applications -f my-values.yaml
```

Templates
---------

This chart includes a template that defines multiple Argo CD `Application` resources based on the values provided. Each enabled application will generate an Argo CD application resource using the following structure:

-   **Application Name**: `<release-name>-<appName>-<clusterName>`
-   **Namespace**: Defined per application in `values.yaml`
-   **Sync Wave**: Defines the deployment order of applications
-   **Repository and Path**: Configured via `gitRepoUrl`, `appsDir`, and `appName`

Here is an excerpt of the generated template for the `operators` application:

```yaml
---
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: my-release-operators-dev
  annotations:
    argocd.argoproj.io/sync-wave: "0"
  labels:
    app.kubernetes.io/name: operators
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.example-org.com/your-repo/your-charts.git
    targetRevision: main
    path: apps/service-mesh/charts/operators
    helm:
      valueFiles:
        - values.yaml
      releaseName: "operators"
  destination:
    server: https://kubernetes.default.svc
    namespace: service-mesh
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```