library-chart Helm Chart
========================

Overview
--------

The **library-chart** is a utility Helm chart that provides reusable templates for Kubernetes resources such as Deployments, ConfigMaps, HorizontalPodAutoscalers (HPA), Secrets, PVCs, and Service Mesh configurations. It is designed to be used as a dependency by other charts (e.g., `app-deployment`) and cannot be used standalone.

Usage
-----

To use **library-chart**, add it as a dependency in your chart's `Chart.yaml`:

```yaml
dependencies:
  - name: library-chart
    version: 0.3.0
    repository: "https://artifactory.example-org.com/artifactory/helm3-example-org"
```

You can call the utility templates in your chart templates, for example:

```yaml
{{ include "library-chart.createDeployment" . }}
```

### Example Usage

-   **Creating ConfigMaps**:

    ```yaml
    {{ include "library-chart.createConfigmaps" . }}
    ```

-   **Creating Deployments**:

    ```yaml
    {{ include "library-chart.createDeployment" . }}
    ```

-   **Creating HorizontalPodAutoscaler**:

    ```yaml
    {{ include "library-chart.createHPA" . }}
    ```

-   **Service Mesh (Istio) Integration**:

    ```yaml
    {{ include "library-chart.enableServiceMesh" . }}
    ```


Configuration
-------------

Below are the configurable fields for the templates provided by **library-chart**.

### Deployable Resource Configs (Deployments/Jobs/StatefulSet)

| Parameter | Description | Default |
| --- | --- | --- |
| `replicaCount` | Number of replicas for the deployment. | `1` |
| `image.registry` | Container image registry. | `docker.io` |
| `image.path` | Path of the image in the registry. | `my-app` |
| `image.tag` | Image tag to use. | Chart version (`AppVersion`) |
| `image.pullPolicy` | Image pull policy (`Always`, `IfNotPresent`, etc.). | `IfNotPresent` |
| `imagePullSecrets` | List of image pull secrets for pulling private images. | `[]` |
| `autoscaling.enabled` | Enable HorizontalPodAutoscaler (HPA) for the deployment. | `false` |
| `autoscaling.minReplicas` | Minimum number of replicas if autoscaling is enabled. | `1` |
| `autoscaling.maxReplicas` | Maximum number of replicas for HPA. | `10` |
| `autoscaling.metrics` | Metrics to be used for autoscaling (e.g., CPU utilization). | `[]` |
| `autoscaling.behavior` | Behavior for scaling up and scaling down (stabilization, policies). | `{}` |
| `serviceAccount.create` | Whether to create a new ServiceAccount. | `true` |
| `serviceAccount.name` | Name of the ServiceAccount. | Auto-generated name |
| `serviceAccount.annotations` | Annotations for the ServiceAccount. | `{}` |
| `podAnnotations` | Annotations for the Pod template. | `{}` |
| `podLabels` | Labels to add to the Pod template. | `{}` |
| `securityContext` | Pod-level security context configuration. | `{}` |
| `volumes` | Additional volumes to mount in the Pod. | `[]` |
| `volumeMounts` | Additional volume mounts for the containers. | `[]` |
| `livenessProbe` | Liveness probe configuration for the containers. | `{}` |
| `readinessProbe` | Readiness probe configuration for the containers. | `{}` |
| `resources` | Resource requests and limits for the containers. | `{}` |
| `nodeSelector` | Node selection constraint for scheduling Pods. | `{}` |
| `affinity` | Pod scheduling preferences based on affinity rules. | `{}` |
| `tolerations` | Tolerations for node taints. | `[]` |
| `configmaps` | List of ConfigMaps to create and mount in the Pods. | `[]` |
| `pvcs` | PersistentVolumeClaims to create and mount in the Pods. | `[]` |
| `blueGreen.enabled` | Enable Blue/Green deployment using Argo Rollouts. | `false` |
| `blueGreen.autoPromotionEnabled` | Automatically promote Blue/Green deployments when enabled. | `false` |


### Service Mesh Fields

These fields are used when enabling Istio service mesh integration through the `enableServiceMesh` template.

| Parameter | Description | Default |
| --- | --- | --- |
| `serviceMesh.enabled` | Enable Istio service mesh injection. | `false` |
| `serviceMesh.services` | List of services to be included in the service mesh. | `[]` |
| `serviceMesh.service.name` | Name of the service in the service mesh. | `""` |
| `serviceMesh.host` | Hostname for the VirtualService. | `""` |
| `serviceMesh.port` | Port to use for the service mesh integration. | `80` |
| `serviceMesh.isExternal` | Whether the service is external to the mesh (for ServiceEntry creation). | `false` |
| `serviceMesh.routeHost` | Host for routing traffic to the service (used in VirtualService). | `""` |
| `serviceMesh.otherServices` | Additional services to be included in the service mesh integration. | `[]` |

### Helper Functions

The **library-chart** provides several helper functions to standardize chart labels, names, and selectors.

| Helper Function | Description |
| --- | --- |
| `library-chart.name` | Returns the base name of the chart. |
| `library-chart.fullname` | Returns the fully qualified name of the chart, considering overrides. |
| `library-chart.labels` | Returns a set of common labels for resources like Deployments, Services, ConfigMaps, etc. |
| `library-chart.selectorLabels` | Returns labels used for selectors (e.g., for Deployments or StatefulSets). |
| `library-chart.serviceAccountName` | Returns the name of the ServiceAccount, considering overrides and default behaviors. |

#### Example Usage of Helper Functions

1.  **Name Helper**:

    -   Use the `library-chart.name` helper to retrieve the chart name in your templates.

    ```yaml
    name: {{ include "library-chart.name" . }}
    ```

2.  **Fullname Helper**:

    -   Use the `library-chart.fullname` helper to generate the fully qualified name of your resources.

    ```yaml
    fullname: {{ include "library-chart.fullname" . }}
    ```

3.  **Labels Helper**:

    -   Use the `library-chart.labels` helper to apply standard labels to your Kubernetes resources.

    ```yaml
    labels:
      {{ include "library-chart.labels" . | nindent 4 }}
    ```

### Example `values.yaml`

```yaml
replicaCount: 3

image:
  registry: docker.io
  path: my-app
  tag: "latest"
  pullPolicy: IfNotPresent

serviceAccount:
  create: true
  name: "my-app-service-account"

autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 5
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 80

serviceMesh:
  enabled: true
  services:
    - name: "my-mesh-service"
      host: "my-app.mesh.local"
      port: 8080
```