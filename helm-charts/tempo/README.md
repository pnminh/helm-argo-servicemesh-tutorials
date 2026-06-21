Tempo Helm Chart
===============

Overview
--------

The **Tempo Helm Chart** deploys and manages Grafana Tempo, a distributed tracing backend. This chart handles the configuration of storage secrets, components (query frontend, distributor, compactor, etc.), and Istio VirtualService for routing the requests to Tempo. It integrates with various storage backends like Azure and offers flexible resource management for each component.

Prerequisites
-------------

-   OpenShift 4.x
-   Helm 3.x.
-   Istio or service mesh enabled for VirtualService configuration (optional).
-   Storage backend configured (e.g., Azure, GCS, S3).

Installing the Chart
--------------------

Refer to [this doc](../README.md#usage) for the instructions on adding EXAMPLE_ORG helm charts.


To install the chart with the release name `my-release`, run:

```bash
helm install my-release example-org/tempo
```

Configuration
-------------

The `values.yaml` file allows customization of various aspects of the Tempo stack, including storage, resources for different components, and routing with Istio.

### Key Parameters

#### Storage Configuration

| Parameter | Description | Default |
| --- | --- | --- |
| `storage.secret.name` | Name of the secret used for storage credentials | `tempo-azure-secret` |
| `storage.secret.type` | Type of storage backend (e.g., `azure`, `gcs`, `s3`) | `azure` |
| `storage.secret.configs.externalSecretStoreRef.kind` | Type of secret store (e.g., `ClusterSecretStore`) | `ClusterSecretStore` |
| `storage.secret.configs.externalSecretStoreRef.name` | Name of the external secret store | `ocp-secrets-store` |
| `storage.secret.configs.data` | Secret data keys and values | See example below |
| `storage.storageClassName` | Storage class for the Tempo stack | `dev` |

#### Tempo Stack Components

| Parameter | Description | Default |
| --- | --- | --- |
| `queryFrontend.replicas` | Number of replicas for the query frontend | `1` |
| `queryFrontend.resources` | Resource requests and limits for the query frontend | See example below |
| `distributor.replicas` | Number of replicas for the distributor | `3` |
| `distributor.resources` | Resource requests and limits for the distributor | See example below |
| `compactor.replicas` | Number of replicas for the compactor | `2` |
| `compactor.resources` | Resource requests and limits for the compactor | See example below |
| `ingester.replicas` | Number of replicas for the ingester | `3` |
| `ingester.resources` | Resource requests and limits for the ingester | See example below |
| `querier.replicas` | Number of replicas for the querier | `3` |
| `querier.resources` | Resource requests and limits for the querier | See example below |
| `gateway.enabled` | Enable or disable the Tempo gateway | `false` |
| `gateway.replicas` | Number of replicas for the gateway (if enabled) | `3` |
| `gateway.resources` | Resource requests and limits for the gateway | See example below |

#### Retention and Global Configuration

| Parameter | Description | Default |
| --- | --- | --- |
| `retention.global.traces` | Retention period for traces in the Tempo stack | `72h0m0s` |
| `resources.total.limits.memory` | Total memory limit for the Tempo stack | `2Gi` |
| `resources.total.limits.cpu` | Total CPU limit for the Tempo stack | `2` |

#### VirtualService Configuration

| Parameter | Description | Default |
| --- | --- | --- |
| `virtualService.name` | Name of the Istio VirtualService for routing requests to Tempo | `tempo-query-frontend` |
| `virtualService.hosts` | List of hosts for the VirtualService | `["*"]` |
| `virtualService.gateways` | List of gateways for the VirtualService | `["istio-ingress/tempo-gateway"]` |
| `virtualService.http` | HTTP routing rules for the VirtualService | See example below |

### Example Values File

Below is an example `values.yaml` configuration:

```yaml
storage:
  secret:
    name: tempo-azure-secret
    type: azure
    configs:
      externalSecretStoreRef:
        kind: ClusterSecretStore
        name: ocp-secrets-store
      data:
        - remoteKey: tempo-store-account-key
          secretKey: account_key
        - remoteKey: tempo-store-account-name
          secretKey: account_name
        - remoteKey: tempo-store-container
          secretKey: container
  storageClassName: dev

queryFrontend:
  replicas: 1
  resources:
    limits:
      memory: "1Gi"
    requests:
      cpu: "500m"
      memory: "1Gi"

distributor:
  replicas: 3
  resources:
    limits:
      memory: "1Gi"
    requests:
      cpu: "500m"
      memory: "1Gi"

compactor:
  replicas: 2
  resources:
    limits:
      memory: "3Gi"
    requests:
      cpu: "500m"
      memory: "1Gi"

ingester:
  replicas: 3
  resources:
    limits:
      memory: "2Gi"
    requests:
      cpu: "500m"
      memory: "1Gi"

querier:
  replicas: 3
  resources:
    limits:
      memory: "3Gi"
    requests:
      cpu: "500m"
      memory: "1Gi"

gateway:
  enabled: false
  replicas: 3
  resources:
    limits:
      memory: "1Gi"
    requests:
      cpu: "500m"
      memory: "1Gi"

retention:
  global:
    traces: 72h0m0s

resources:
  total:
    limits:
      memory: "2Gi"
      cpu: "2"

virtualService:
  name: "tempo-query-frontend"
  hosts:
    - "*"
  gateways:
    - "istio-ingress/tempo-gateway"
  http:
    - match:
        - uri:
            prefix: "/"
      route:
        - destination:
            host: tempo-tempo-query-frontend
            port:
              number: 16686
```

### Installing with Custom Values

You can install the Tempo chart using a custom `values.yaml` file or override specific values from the command line:

```bash
helm install my-release example-org/tempo -f my-values.yaml
```

Or override values directly in the command line:

```bash
helm install my-release example-org/tempo --set queryFrontend.replicas=2 --set distributor.replicas=4`
```