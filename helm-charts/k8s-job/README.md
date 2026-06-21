Kubernetes Job Helm Chart
=========================

Overview
--------

The `k8s-job` Helm chart is designed to create Kubernetes Job resources, allowing you to manage and run containerized jobs in a Kubernetes cluster. The chart provides options for configuring job retries, resource allocation, and other Kubernetes Job features.

Prerequisites
-------------

-   OpenShift 4.x
-   Helm 3.x

Installing the Chart
--------------------

Refer to [this doc](../README.md#usage) for the instructions on adding EXAMPLE_ORG helm charts.


To install the chart with the release name `my-release`, run:

```bash
helm install my-release example-org/k8s-job
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

The `values.yaml` file defines the configuration options for the job, including the image to use, the retry limit, resource requests and limits, and pod security contexts. These values can be customized either directly in the `values.yaml` file or overridden using the `--set` flag.

### Key Parameters

| Parameter | Description | Default |
| --- | --- | --- |
| `backoffLimit` | Number of retries for failed job execution | `4` |
| `restartPolicy` | Job restart policy (`Never` or `OnFailure`) | `Never` |
| `nodeSelector` | Node selector for job scheduling | `{}` |
| `affinity` | Affinity rules for pod scheduling | `{}` |
| `image.registry` | Docker image registry | `quay.io/example-org/registry-dev` |
| `image.path` | Path for the image | `todo-ui` |
| `image.pullPolicy` | Image pull policy (`Always`, `IfNotPresent`, etc.) | `Always` |
| `image.tag` | Tag for the image | `"1.0.0"` |
| `podSecurityContext` | Security context for the pod | `{}` |
| `securityContext` | Security context for the container | `{}` |
| `resources` | Resource requests and limits for the container | `{}` |

### Customizing Parameters

You can pass custom values when installing the chart as follows:

```bash
helm install my-release example-org/k8s-job --set image.tag=2.0.0 --set restartPolicy=OnFailure
```
Alternatively, you can use a custom `values.yaml` file:

```bash
helm install my-release example-org/k8s-job -f my-values.yaml
```

### Example Values File

Here is an example configuration from `values.yaml`:

```yaml
backoffLimit: 4
restartPolicy: Never
nodeSelector: {}
affinity: {}
image:
  registry: quay.io/example-org/registry-dev
  path: todo-ui
  pullPolicy: Always
  tag: "1.0.0"
podSecurityContext: {}
securityContext: {}
resources: {}
```
This configuration will create a Kubernetes job that runs the `todo-ui:1.0.0` container from `quay.io`, with no nodeSelector or affinity rules applied, and without resource limits.

### Example Usage

To install a job that uses a different image tag and restart policy, you can specify the parameters in the command line:

```bash
helm install my-release example-org/k8s-job --set image.tag="2.0.1" --set restartPolicy="OnFailure"
```

This will create a Kubernetes Job with the following key properties:

-   The image used will be `quay.io/example-org/registry-dev/todo-ui:2.0.1`.
-   The job will be configured to restart on failure (`restartPolicy: OnFailure`).