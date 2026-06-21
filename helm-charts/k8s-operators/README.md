Kubernetes Operators Helm Chart
==============================

Overview
--------

This Helm chart automates the creation of OpenShift Operator Subscriptions, allowing you to easily install and manage Operators in your OpenShift cluster. The chart utilizes the OpenShift Operator Lifecycle Manager (OLM) to subscribe to specific Operator channels and control installation approval policies.

Prerequisites
-------------

-   OpenShift 4.x with Operator Lifecycle Manager (OLM) enabled
-   Helm 3.x

Installing the Chart
--------------------

Refer to [this doc](../README.md#usage) for the instructions on adding EXAMPLE_ORG helm charts.


To install the chart with the release name `my-release`, run:

```bash
helm install my-release example-org/k8s-operators
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

The chart is driven by the `values.yaml` file, where you can define the list of Operator Subscriptions that need to be created. Each subscription can be configured to install Operators from specific sources, channels, and with different approval policies.

### Key Parameters

| Parameter | Description | Default |
| --- | --- | --- |
| `subscriptions[].name` | Name of the Operator subscription | Required |
| `subscriptions[].namespace` | Namespace where the Operator will be installed | `openshift-operators` |
| `subscriptions[].source` | The Operator source (e.g., `redhat-operators`) | `redhat-operators` |
| `subscriptions[].sourceNamespace` | The namespace containing the Operator source | `openshift-marketplace` |
| `subscriptions[].channel` | The update channel for the Operator (e.g., `stable`) | `stable` |
| `subscriptions[].installPlanApproval` | Approval mode for the installation (`Automatic` or `Manual`) | `Automatic` |

### Customizing Subscriptions

You can configure multiple Operator subscriptions by specifying them in the `values.yaml` file under the `subscriptions` key. For example:

```yaml
subscriptions:
  - name: kiali-ossm
    namespace: openshift-operators
    source: redhat-operators
    sourceNamespace: openshift-marketplace
    channel: stable
    installPlanApproval: Automatic
  - name: servicemeshoperator
    namespace: openshift-operators
    source: redhat-operators
    sourceNamespace: openshift-marketplace
    channel: stable
    installPlanApproval: Automatic
```

Each Operator subscription has its own configuration fields:

-   **`name`**: The name of the Operator you want to install.
-   **`namespace`**: The namespace where the Operator should be installed.
-   **`source`**: The source of the Operator (e.g., `redhat-operators`).
-   **`sourceNamespace`**: The namespace where the source of the Operator is hosted (e.g., `openshift-marketplace`).
-   **`channel`**: The subscription channel (e.g., `stable`).
-   **`installPlanApproval`**: Determines whether the Operator installation is approved automatically or manually.

### Example Values File

Here's an example of a complete `values.yaml` file:

```yaml
subscriptions:
  - name: kiali-ossm
    namespace: openshift-operators
    source: redhat-operators
    sourceNamespace: openshift-marketplace
    channel: stable
    installPlanApproval: Automatic
  - name: servicemeshoperator
    namespace: openshift-operators
    source: redhat-operators
    sourceNamespace: openshift-marketplace
    channel: stable
    installPlanApproval: Automatic
  - name: tempo-product
    namespace: openshift-tempo-operator
    source: redhat-operators
    sourceNamespace: openshift-marketplace
    channel: stable
    installPlanApproval: Automatic
```

In this example:

-   **Kiali** and **Service Mesh Operator** are installed in the `openshift-operators` namespace.
-   **Tempo** is installed in the `openshift-tempo-operator` namespace.
-   All subscriptions are set to automatically approve install plans.

### Installing with Custom Values

You can customize the installation by passing your own `values.yaml` file or using the `--set` option:

```bash
helm install my-release -f my-values.yaml
```

Alternatively, you can override specific values directly from the command line:

```bash
helm install my-release --set subscriptions[0].name=my-operator
```