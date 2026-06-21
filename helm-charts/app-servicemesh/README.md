App Service Mesh Helm Chart
=========================

Overview
-------- 

This Helm chart enables service mesh integration and allows you to add both internal and external services to the mesh.

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
helm install my-release example-org/app-servicemesh
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

#### Service Mesh

| Parameter | Description | Default | Required |  Example |
| --- | --- | --- | --- | --- |
| `serviceMesh.enabled` | Enable service mesh for this deployment | `true` | `No` | |
| `serviceMesh.services[].name` | Name of the service | `""` | `Yes` | `serviceA` |
| `serviceMesh.services[].routeHost` | The OCP route for the app if it needs to be exposed externally | `"` | `No` | `service-api.mesh.apps.dev.k8s.example-org.com` |
| `serviceMesh.services[].host` | The real hostname, can be Openshift service URL or external URL | `"Default to the service name` | `Yes` | `service-api.app-dev.example-org.com` |
| `serviceMesh.services[].port` | Port for the service in the mesh | `""` | `Yes` | 443 |
| `serviceMesh.services[].protocol` | Protocol for the service mesh (http, https, etc.) | `http` | `Yes` | `https` |
| `serviceMesh.services[].isExternal` | Whether the service is externally to Openshift cluster or not | `false` | `Yes` | `true` |

For a complete list of values, refer to the `values.yaml` file.

### Customizing with `values.yaml`

You can customize the mesh configs by modifying the `values.yaml` file. Here's an example of some configurations:

```yaml
enabled: true
services:
  - name: apirouter
    routeHost: apirouter.mesh.apps.dev.k8s.example-org.com 
    host: apirouter.apps-dev.example-org.com # or service-api.service-namespace if isExternal=false, using release name if not set
    port: 443
    isExternal: true # Set to true for external services
    protocol: https # default to http, also support https,tls
```


Templates
---------

The chart contains the following Kubernetes templates:

-   **servicemesh.yaml**: Defines the Service Mesh configuration for the application.
