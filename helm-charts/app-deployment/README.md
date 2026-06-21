App Deployment Helm Chart
=========================

Overview
--------

This Helm chart is designed to deploy a Kubernetes application with a variety of customization options, such as support for blue-green deployments, auto-scaling, external secrets, service mesh, and more.

Prerequisites
-------------

-   OpenShift 4.x
-   Helm 3.x
-   (Optional) Service Mesh enabled in the cluster

Installing the Chart
--------------------

Refer to [this doc](../README.md#usage) for the instructions on adding EXAMPLE_ORG helm charts.


To install the chart with the release name `my-release`, run:

```bash
helm install my-release example-org/app-deployment
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

### Default Parameters

Here are some of the configurable parameters in the chart. These parameters can be overridden in the `values.yaml` file or passed through Helm's `--set` flag.

#### General Settings

| Parameter | Description | Default | Required |
| --- | --- | --- | --- |
| `replicaCount` | Number of replicas for the deployment | `1` | `Yes if autoScaling is not enabled` |
| `nameOverride` | Override the chart name | `""` | `No` |
| `fullnameOverride` | Override the full name of the chart | `""` | `No` |
| `securityContext` | Security Context Configuration for deployment  | `""` | `No` |
| `command` |  Overrides the default command defined in the container image | `[]` | `No` |
| `resources` |  Specify resource configs for `requests` and `limits` | `[]` | `No` |
| `volumes` |  Specify volumes resources | `[]` | `No` |
| `volumeMounts` |  Specify volumeMount resources | `[]` | `No` |
| `nodeSelector` |  Select node to run the deployment | `{}` | `No` |
| `tolerations` |  Specify tolerations | `[]` | `No` |
| `affinity` |  Specify affinity | `[]` | `No` |
#### Image Settings

| Parameter | Description | Default | Required |
| --- | --- | --- | --- |
| `image.registry` | Docker registry for the image | `quay.io/example-org/registry-dev` | `Yes` |
| `image.path` | Image path in the registry | `todo-ui` | `Yes` |
| `image.tag` | Image tag | `1.0.0` | `Yes` |
| `image.pullPolicy` | Image pull policy | `Always` | `Yes` |

#### Service Account Settings

| Parameter | Description | Default | Required |
| --- | --- | --- | --- |
| `serviceAccount.create` | Specifies whether a service account should be created | `true` | `No` |
| `serviceAccount.automount` | Option to automatically mount API credentials for the ServiceAccount | `true` | `No` |
| `serviceAccount.annotations` | Annotations to add to the service account tag | `none` | `No` |
| `serviceAccount.name` | The name of the service account to use. | `If not set and create is true, a name is generated using the fullname template` | `No` |

#### Pod Settings

| Parameter | Description | Default | Required |
| --- | --- | --- | --- |
| `podAnnotations` | Annotations to add to the pods | `""` | `No` |
| `podLabels` | Labels to add to the pods | `""` | `No` |
| `podSecurityContext` | Security Context Configuration for pods | `""` | `No` |
| `ports` | List of ports that the pods expose | `[{"name": "http", "port": 8080, "protocol": "TCP"}]` | `No` |

#### Service Settings

| Parameter | Description | Default | Required |
| --- | --- | --- | --- |
| `service.type` | Kubernetes service type | `ClusterIP` | `No` |
| `service.ports` | Ports to expose through the service | `[{"name": "http", "port": 8080, "protocol": "TCP"}]` | `No` |

#### Route Settings

| Parameter | Description | Default | Required |
| --- | --- | --- | --- |
| `route.enabled` | Whether to enable OpenShift Route for the app | `false` | `No` |
| `route.targetPort` | Target port for the Route | `8080` | `No` |

#### App Configs

| Parameter | Description | Default | Required |
| --- | --- | --- | --- |
| `appConfig` | Yaml formatted app configurations | `""` | `No` |

#### ConfigMaps

| Parameter | Description | Default | Required | Example |
| --- | --- | --- | --- | --- |
| `configmaps[].name` | Name of the configmap | `""` | `No` | `dbConf` |
| `configmaps[].create` | Option to create the configmap as part of the chart | `"false"` | `No` | ` ` |
| `configmaps[].mount.enabled` | Should the configmap be mounted to the pod  | `"false"` | `No` | ` ` |
| `configmaps[].mount.path` | The mount path on the pod  | `""` | `No` | `/etc/config` |
| `configmaps[].items[].key` | The key for a configmap  | `""` | `No` | `app-config1.properties` |
| `configmaps[].items[].value` | The value for a configmap  | `""` | `No` | `CONFIG1=config1` |
| `configmaps[].items[].path` | The name of the file inside the pod  | `Default to configmaps[].items[].key` | `No` | `another-app-config.properties` |

#### PersistentVolumeClaims

| Parameter | Description | Default | Required | Example |
| --- | --- | --- | --- | --- |
| `pvcs[].name` | Name of the pvc | `""` | `No` |  `pvc1` |
| `pvcs[].create` | Option to create the pvc as part of the chart | `"false"` | `No` |  ` ` |
| `pvcs[].mount.enabled` | Should the pvc be mounted to the pod  | `"false"` | `No` |  ` ` |
| `pvcs[].accessModes` | The pvc access mode  | `""` | `No` |  `[ReadWriteMany,ReadWriteOnce]` |
| `pvcs[].storageClassName` | The storage class to use  | `"If not specified, the default one will be used"` | `No` |  `/etc/config` |
| `pvcs[].resources.requests.storage` | The pvc storage  | `1Gi` | `No` | `10Gi` |

#### Blue-Green Deployment

| Parameter | Description | Default | Required | 
| --- | --- | --- | --- |
| `blueGreen.enabled` | Enable blue-green deployment strategy | `false` | `No` |
| `blueGreen.autoPromotionEnabled` | Enable auto-promotion of new versions | `false` | `No` |
| `blueGreen.previewRoute.enabled` | Enable a preview route | `true` | `No` |

#### Autoscaling

| Parameter | Description | Default | Required | 
| --- | --- | --- | --- | 
| `autoscaling.enabled` | Enable Horizontal Pod Autoscaler (HPA) | `false` | `No` |
| `autoscaling.minReplicas` | Minimum number of replicas | `1` | `No` |
| `autoscaling.maxReplicas` | Maximum number of replicas | `5` | `No` |
| `autoscaling.metrics` | Metrics used for scaling | `CPU and memory utilization`  | `No` |
| `autoscaling.behavior` | Scale Up and Scale down window configs | `scale up and down configs and policies`  | `No` |
#### External Secrets

| Parameter | Description | Default | Required | 
| --- | --- | --- | --- |
| `externalSecrets.defaultClusterSecretStore` | Default cluster secret store for the app | `"example-org-store"` | `Yes` |
| `externalSecrets.refreshInterval` | Secret refresh interval | `"60s"` | `No` |
#### Service Mesh

| Parameter | Description | Default | Required |  Example |
| --- | --- | --- | --- | --- |
| `serviceMesh.enabled` | Enable service mesh for this deployment | `true` | `No` | |
| `serviceMesh.service.port` | Port for the service in the mesh | `8080` | `Yes` | |
| `serviceMesh.service.routeHost` | The OCP route for the app if it needs to be exposed externally | `"` | `No` | `service-api.mesh.apps.dev.k8s.example-org.com` |
| `serviceMesh.service.protocol` | Protocol for the service mesh (http, https, etc.) | `http` | `Yes` | `https` |
| `serviceMesh.otherServices[].name` | Name of the service | `""` | `Yes` | `serviceA` |
| `serviceMesh.otherServices[].routeHost` | The OCP route for the app if it needs to be exposed externally | `"` | `No` | `service-api.mesh.apps.dev.k8s.example-org.com` |
| `serviceMesh.otherServices[].host` | The real hostname, can be Openshift service URL or external URL | `"Default to the service name` | `Yes` | `service-api.app-dev.example-org.com` |
| `serviceMesh.otherServices[].port` | Port for the service in the mesh | `""` | `Yes` | 443 |
| `serviceMesh.otherServices[].protocol` | Protocol for the service mesh (http, https, etc.) | `http` | `Yes` | `https` |
| `serviceMesh.otherServices[].isExternal` | Whether the service is externally to Openshift cluster or not | `false` | `Yes` | `true` |

For a complete list of values, refer to the `values.yaml` file.

#### StatefulSet
| Parameter | Description | Default | Required |  Example |
| --- | --- | --- | --- | --- |
| `statefulSet.enabled` | Enable statefulset deployment | `false` | `true` | |
| `statefulSet.serviceName` | Customized service name for the statefulset | Defaults to the name of the application | `todo-api` | |


### Customizing with `values.yaml`

You can customize the deployment by modifying the `values.yaml` file. Here's an example of some configurations:

```yaml
replicaCount: 2
image:
  registry: myrepo/myapp
  tag: "1.0.1"
  pullPolicy: IfNotPresent
service:
  type: ClusterIP
  ports:
    - name: http
      port: 8080
      targetPort: http
resources:
  limits:
    cpu: 200m
    memory: 256Mi
  requests:
    cpu: 100m
    memory: 128Mi`
```
### Using the Service Mesh

If you have a service mesh enabled in your cluster, you can configure the application to integrate with it by enabling the `serviceMesh` settings.

Templates
---------

The chart contains the following Kubernetes templates:

-   **NOTES.txt**: Provides instructions post-installation.
-   **appconfig.yaml**: Configures application-specific settings.
-   **configmap.yaml**: Defines ConfigMap resources for application configuration.
-   **deployment.yaml**: Defines the Deployment resource.
-   **externalsecret.yaml**: Configures external secrets integration.
-   **hpa.yaml**: Defines the Horizontal Pod Autoscaler (HPA).
-   **pvc.yaml**: Configures PersistentVolumeClaims (PVCs) if necessary.
-   **route.yaml**: Defines the OpenShift Route for the application.
-   **secret.yaml**: Configures secrets for sensitive data.
-   **service.yaml**: Defines the Service resource.
-   **serviceaccount.yaml**: Configures the Service Account for the application.
-   **servicemesh.yaml**: Defines the Service Mesh configuration for the application.

Each of these templates can be customized via the `values.yaml` file or Helm command line options.