Build App Helm Chart
====================

Overview
--------

The `app-build` Helm chart is designed to create an OpenShift BuildConfig resource, which automates the build and deployment of container images. The chart supports both Docker and Source-to-Image (S2I) build strategies, enabling flexible image building workflows for different use cases.

Prerequisites
-------------

-   OpenShift 4.x
-   OpenShift BuildConfig resource enabled

Installing the Chart
--------------------

Refer to [this doc](../README.md#usage) for the instructions on adding EXAMPLE_ORG helm charts.


To install the chart with the release name `my-release`, run:

```bash
helm install my-release example-org/app-build
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

The `values.yaml` file defines various configurable parameters for the build configuration. These parameters can be modified either directly in the `values.yaml` file or overridden using the `--set` flag during installation.

### Customizing Parameters

You can pass custom values during chart installation as follows:

```bash
helm install my-release example-org/app-build --set target.image.tag=2.0.0
```

Alternatively, use a custom `values.yaml` file:

```bash
helm install my-release example-org/app-build -f my-values.yaml
```

### Key Parameters

| Parameter | Description | Default |
| --- | --- | --- |
| `source.image.repository` | The Docker image repository for the source image | `registry.access.redhat.com/ubi9/nginx-120` |
| `source.image.tag` | Tag for the source image | `"1-146"` |
| `target.image.registry` | Registry where the built image will be pushed | `quay.io/example-org/registry-dev` |
| `target.image.path` | Path for the target image | `todo-ui` |
| `target.image.tag` | Tag for the target image | `"1.0.0"` |
| `target.image.pushSecret` | Secret used to authenticate the image push to the registry | `"quay-io"` |
| `strategy` | Build strategy to use (`docker` or `s2i`) | `docker` |
| `dockerfilePath` | Path to the Dockerfile if using Docker build strategy | `"Dockerfile"` |

### Build Strategies

The `strategy` parameter allows you to specify the build strategy used by the OpenShift BuildConfig. The chart supports the following strategies:

1.  **Docker Build Strategy**: Uses a Dockerfile to build the image.

    ```yaml
    strategy: docker
    dockerfilePath: Dockerfile
    ```

2.  **Source-to-Image (S2I) Strategy**: Uses a pre-configured base image to build the application from source.

    ```yaml
    strategy: s2i
    source:
      image:
        repository: registry.access.redhat.com/ubi9/nginx-120
        tag: "1-146"
    ```

The appropriate build strategy is specified in the `values.yaml` file under the `strategy` field.

### Example Values File

Below is an example configuration in the `values.yaml` file:

```yaml
source:
  image:
    repository: registry.access.redhat.com/ubi9/nginx-120
    tag: "1-146"

target:
  image:
    registry: quay.io/example-org/registry-dev
    path: todo-ui
    tag: "1.0.0"
    pushSecret: "quay-io"

strategy: docker
dockerfilePath: Dockerfile`
```

This configuration uses a Docker build strategy with an UBI9-based Nginx image as the source and pushes the built image to `quay.io/example-org/registry-dev` with the `todo-ui:1.0.0` tag.

### Customizing BuildConfig with `values.yaml`

The `values.yaml` file contains parameters to customize the OpenShift BuildConfig resource. These include the source and target image details, the build strategy, and other configurations like the secret used to push the built image.

You can also override these values through the command line during installation:

```bash
helm install my-release example-org/app-build --set target.image.path=my-app --set target.image.tag=2.0.0
```

### Build Output

The build output section defines where the built image will be pushed:

```yaml
spec:
  output:
    pushSecret:
      name: "{{ .Values.target.image.pushSecret }}"
    to:
      kind: DockerImage
      name: {{ .Values.target.image.registry }}/{{ .Values.target.image.path }}:{{ .Values.target.image.tag | default "latest" }}`
```

This ensures that the built image is pushed to the specified Docker registry using the provided push secret.

Templates
---------

This Helm chart generates an OpenShift `BuildConfig` resource based on the parameters defined in `values.yaml`. Here's an example of the generated BuildConfig for a Docker build:

```yaml
kind: BuildConfig
apiVersion: build.openshift.io/v1
metadata:
  name: my-release
  labels:
    app.kubernetes.io/name: app-build
spec:
  output:
    pushSecret:
      name: quay-io
    to:
      kind: DockerImage
      name: quay.io/example-org/registry-dev/todo-ui:1.0.0
  resources: {}
  successfulBuildsHistoryLimit: 5
  failedBuildsHistoryLimit: 5
  strategy:
    type: Docker
    dockerStrategy:
      dockerfilePath: Dockerfile
  source:
    binary: {}
  runPolicy: Serial`
```
If the S2I strategy is selected, the chart will generate a corresponding S2I BuildConfig:

```yaml
strategy:
  type: Binary
  sourceStrategy:
    from:
      kind: DockerImage
      name: "registry.access.redhat.com/ubi9/nginx-120:1-146"
```