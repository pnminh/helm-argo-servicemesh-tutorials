Service Mesh Control Plane (SMCP) Helm Chart
============================================

Overview
--------

The **SMCP Helm Chart** is designed to deploy and manage the **ServiceMeshControlPlane** (SMCP) and associated resources such as the **ServiceMeshMemberRoll** (SMMR). It allows you to configure various components of a service mesh, including add-ons (Grafana, Kiali, Prometheus), telemetry, tracing, gateways, and mesh configuration settings. This chart is suitable for managing service mesh capabilities in OpenShift or Kubernetes environments.

Prerequisites
-------------

-   OpenShift 4.x with the Service Mesh Operator installed.
-   Helm 3.x.
-   Required external services (e.g., Prometheus, Grafana) if enabled.


Installing the Chart
--------------------

Refer to [this doc](../README.md#usage) for the instructions on adding EXAMPLE_ORG helm charts.


To install the chart with the release name `my-release`, run:

```bash
helm install my-release example-org/sm-control-plane
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

The `values.yaml` file is where you define the configuration options for the Service Mesh Control Plane and the Service Mesh Member Roll. You can customize various aspects of the deployment according to your needs.

### Key Parameters

#### Service Mesh Control Plane Configuration

| Parameter | Description | Default |
| --- | --- | --- |
| `serviceMeshControlPlane.name` | Name of the ServiceMeshControlPlane resource | `basic` |
| `serviceMeshControlPlane.version` | Version of the Service Mesh Control Plane | `v2.5` |
| `serviceMeshControlPlane.mode` | Mode of the Service Mesh Control Plane (e.g., `ClusterWide`) | `ClusterWide` |
| `serviceMeshControlPlane.addons.grafana.enabled` | Enable or disable Grafana integration | `false` |
| `serviceMeshControlPlane.addons.kiali.name` | Name of the Kiali instance | `kiali-user-workload-monitoring` |
| `serviceMeshControlPlane.addons.prometheus.enabled` | Enable or disable Prometheus integration | `false` |
| `serviceMeshControlPlane.meshConfig.extensionProviders` | List of extension providers for the service mesh | See below for default configuration |
| `serviceMeshControlPlane.gateways.ingress.enabled` | Enable or disable ingress gateway | `false` |
| `serviceMeshControlPlane.gateways.egress.enabled` | Enable or disable egress gateway | `false` |
| `serviceMeshControlPlane.policy.type` | Type of policy engine (e.g., `Istiod`) | `Istiod` |
| `serviceMeshControlPlane.telemetry.type` | Telemetry configuration type (e.g., `Istiod`) | `Istiod` |
| `serviceMeshControlPlane.tracing.sampling` | Sampling rate for tracing | `10000` |
| `serviceMeshControlPlane.tracing.type` | Type of tracing service (e.g., `None`) | `None` |

**Example of `extensionProviders` in `values.yaml`:**

```yaml
serviceMeshControlPlane:
  meshConfig:
    extensionProviders:
      - name: prometheus
        prometheus: {}
      - name: tempo
        zipkin:
          port: 9411
          service: tempo-tempo-distributor.tracing-system.svc.cluster.local
      - name: "example-org-ext-authz-http"
        envoyExtAuthzHttp:
          service: "iam-auth-controller.iam-auth-controller.svc.cluster.local"
          port: 7010
          pathPrefix: /auth
          includeRequestHeadersInCheck: ["authorization", "cookie","origin","accept"]
          headersToUpstreamOnAllow: ["cookie","remote_user","user_object"]
          headersToDownstreamOnAllow: ["set-cookie"]
          headersToDownstreamOnDeny: ["content-type", "set-cookie", "location"]
          includeAdditionalHeadersInCheck:
            X-Forwarded-Proto: '%REQ(:SCHEME)%'
            X-Forwarded-Method: '%REQ(:METHOD)%'
            X-Forwarded-Host: '%REQ(X-FORWARDED-FOR)%'
            X-Forwarded-Uri: '%REQ(X-ENVOY-ORIGINAL-PATH?:PATH)%'
            authorization: '%REQ(:AUTHORITY)%'`
```
#### Service Mesh Member Roll Configuration

| Parameter | Description | Default |
| --- | --- | --- |
| `serviceMeshMemberRoll.name` | Name of the ServiceMeshMemberRoll | `default` |
| `serviceMeshMemberRoll.memberSelectors.matchLabels` | Labels to select namespaces as members of the service mesh | `{ istio-injection: enabled }` |

#### Telemetry Configuration
The `values.yaml` file allows you to customize various aspects of the Telemetry configuration, including metrics and tracing providers.

| Parameter | Description | Default |
| --- | --- | --- |

| `telemetry.name` | Name of the Telemetry resource | `mesh-default` |

| `telemetry.metrics.providers` | List of providers for metrics | `[]` |

| `telemetry.tracing.providers` | List of providers for tracing | `[]` |

| `telemetry.tracing.randomSamplingPercentage` | Sampling percentage for tracing | `100` |

### Example Values File

Here's an example configuration in the `values.yaml` file:

```yaml
serviceMeshControlPlane:
  name: basic
  addons:
    grafana:
      enabled: false
    kiali:
      name: kiali-user-workload-monitoring
    prometheus:
      enabled: false
  meshConfig:
    extensionProviders:
      - name: prometheus
        prometheus: {}
      - name: tempo
        zipkin:
          port: 9411
          service: tempo-tempo-distributor.tracing-system.svc.cluster.local
      - name: "example-org-ext-authz-http"
        envoyExtAuthzHttp:
          service: "iam-auth-controller.iam-auth-controller.svc.cluster.local"
          port: 7010
          pathPrefix: /auth
          includeRequestHeadersInCheck: ["authorization", "cookie","origin","accept"]
          headersToUpstreamOnAllow: ["cookie","remote_user","user_object"]
          headersToDownstreamOnAllow: ["set-cookie"]
          headersToDownstreamOnDeny: ["content-type", "set-cookie", "location"]
          includeAdditionalHeadersInCheck:
            X-Forwarded-Proto: '%REQ(:SCHEME)%'
            X-Forwarded-Method: '%REQ(:METHOD)%'
            X-Forwarded-Host: '%REQ(X-FORWARDED-FOR)%'
            X-Forwarded-Uri: '%REQ(X-ENVOY-ORIGINAL-PATH?:PATH)%'
            authorization: '%REQ(:AUTHORITY)%'
  gateways:
    ingress:
      enabled: false
    egress:
      enabled: false
  policy:
    type: Istiod
  telemetry:
    type: Istiod
  tracing:
    sampling: 10000
    type: None
  version: v2.5
  mode: ClusterWide

serviceMeshMemberRoll:
  name: default
  memberSelectors:
    matchLabels:
      istio-injection: enabled

telemetry:
  name: mesh-default
  metrics:
    providers:
      - name: prometheus
  tracing:
    providers:
      - name: tempo
    randomSamplingPercentage: 100`
```
### Installing with Custom Values

You can customize the installation by providing your own `values.yaml` file or using the `--set` flag:

```bash
helm install my-release example-org/sm-control-plane -f my-values.yaml
```

Alternatively, you can override specific values from the command line:

```bash
helm install my-release example-org/sm-control-plane --set serviceMeshControlPlane.addons.grafana.enabled=true
```