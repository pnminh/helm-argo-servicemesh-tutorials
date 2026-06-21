Helm Charts Repository
======================

This repository contains Helm charts designed to simplify the deployment of applications and jobs to Kubernetes or OpenShift clusters. These charts can be used either as standalone deployments or integrated with ArgoCD for GitOps workflows.

Repository Structure
--------------------
-   **`app-build`**: A Helm chart designed for creating BuildConfig resources on OpenShift, facilitating Source-to-Image (S2I) builds for efficient application packaging and deployment.
-   **`app-deployment`**: A Helm chart for deploying applications, including resources for deployments, services, ConfigMaps, secrets, persistent volume claims, and more.
-   **`k8s-job`**: A Helm chart similar to `app-deployment` but designed to manage Kubernetes jobs instead of deployments.
-   **`library-chart`**: A Helm chart containing common templates used by both `app-deployment` and `k8s-job` charts. It includes reusable templates for ConfigMaps, PVCs, Secrets, ServiceAccounts, and others.

Prerequisites
-------------

Before using these Helm charts, ensure you have the following tools installed:

-   **`helm` CLI**: Required for managing Helm charts and deploying them to your cluster. [Install Helm](https://helm.sh/docs/intro/install/).
-   **`oc` CLI (OpenShift Command Line Tool)**: Required if you are deploying to an OpenShift cluster. This tool allows you to interact with OpenShift clusters and manage resources. [Install the OpenShift CLI](https://docs.openshift.com/container-platform/4.16/cli_reference/openshift_cli/getting-started-cli.html).

Usage
-----

### Standalone Deployments

The Helm charts in this repository are built and published to Artifactory. To use these charts, first add the repository to your local `Helm client`:
```
helm repo add  example-org https://artifactory.example-org.com/artifactory/helm3-example-org
```

You can then deploy each chart independently to a Kubernetes or OpenShift cluster:

```bash
helm install my-release example-org/app-deployment
```
After the deployment, check its status:

```bash
helm status my-release
```
To upgrade the release with new configuration values:

```bash
helm upgrade my-release example-org/app-deployment -f my-values.yaml
```

Customize the deployment using your custom values file (e.g., my-values.yaml) or by overriding specific settings directly with the `--set` flag:
```bash
helm upgrade my-release example-org/app-deployment --set key1=value1,key2=value2
```

To uninstall/delete the `my-release` deployment:

```bash
helm uninstall my-release
```

### GitOps with ArgoCD

For GitOps workflows, integrate these charts into your app GitOps repository and configure ArgoCD to monitor and sync changes from the repository. 

Common Templates
----------------

The `library-chart` contains reusable templates such as:

-   **`_configmap.tpl`**: Template for creating ConfigMaps.
-   **`_pvc.tpl`**: Template for creating Persistent Volume Claims.
-   **`_secret.tpl`**: Template for creating Secrets.
-   **`_serviceaccount.tpl`**: Template for creating ServiceAccounts.

These templates are designed to be shared across multiple Helm charts in this repository, providing a consistent and modular approach to resource management.

Troubleshooting
------------
Below are some common Helm errors and their troubleshooting steps:

1.  **Error**: `YAML parse error on docmosis-java/charts/app-deployment/templates/deployment.yaml: error converting YAML to JSON: yaml: line 87: did not find expected key`

    **Cause**: This error is often due to an indentation issue, typically with a misaligned list of items in the YAML file.

    **Solution**: Run the following command to debug the Helm chart and identify the source of the problem:

```sh
helm template --debug APP_NAME CHART_NAME
```
Contributing
------------

We welcome contributions to improve the Helm charts in this repository. To contribute:

1.  **Fork the Repository**: Create your own fork of the repository to make changes.
2.  **Create a Branch**: Make a new branch for your changes.
3.  **Make Changes**: Modify the Helm charts or add new features.
4.  **Test**: Ensure that your changes work as expected in a Kubernetes or OpenShift environment.
5.  **Submit a Pull Request**: Open a pull request to merge your changes into the main repository. Provide a detailed description of your changes and any relevant information.

