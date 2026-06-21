# GitOps Deployment Repository
This repository houses resources for deploying the `todo` app stack following the GitOps pattern.
## Prerequisites
### ArgoCD Setup
- ArgoCD Instance: ArgoCD is essential for GitOps deployments. This sample app requires the ApplicationSet controller for managing ApplicationSet resources and the Rollouts plugin to support Blue-Green deployments.
### Container Image Handling
- **Image Pull Secrets**: Applications deployed to Openshift require pull secrets to access container images from private repositories. These secrets can be created and provided as part of the Application Helm Chart, or tied to an Openshift service account for seamless image pulling during deployments.
```sh
oc create secret docker-registry quay --docker-server quay.io --docker-username $QUAY_USER --docker-password $QUAY_TOKEN -n dev
oc create secret docker-registry quay --docker-server quay.io --docker-username $QUAY_USER --docker-password $QUAY_TOKEN -n stage
oc create secret docker-registry quay --docker-server quay.io --docker-username $QUAY_USER --docker-password $QUAY_TOKEN -n prod
```
### Git Authentication
Since authentication is required for all actions against GitHub Enterprise, [Git credentials](https://argo-cd.readthedocs.io/en/latest/operator-manual/declarative-setup/#repository-credentials) needs to be added to Openshift with label `argocd.argoproj.io/secret-type: repo-creds` for ArgoCD to interract with GitHub:
```bash
cat <<EOH | oc apply -n argocd -f - 
apiVersion: v1
kind: Secret
metadata:
  name: example-org-repo-creds
  labels:
    argocd.argoproj.io/secret-type: repo-creds
stringData:
  type: git
  url: https://github.example-org.com/gitops
  # Use a personal access token in place of a password.
  password: $GITHUB_TOKEN
  username: $GITHUB_USERNAME
EOH
```
### Helm Repo Authentication
Similar to Git, ArgoCD needs authentication to access private Helm repositories
```bash
cat <<EOH | oc apply -n argocd -f - 
apiVersion: v1
kind: Secret
metadata:
  name: helm-repo-creds
  labels:
    argocd.argoproj.io/secret-type: repository
stringData:
  name: helm-repo-creds
  url: https://artifactory.example-org.com/artifactory/helm3-example-org
  type: helm
  username: $GITHUB_USERNAME
  password: $GITHUB_TOKEN
  ForceHttpBasicAuth: "true"
EOH
``` 
## Repository structure
- `apps`: This folder contains Argo applications for deployment to Openshift. It also includes a sub-directory `environments` housing all target clusters for app deployment. Each app has a common `values.yaml` file used across all clusters, along with a cluster-specific `values.yaml` file in the respective directory.
- `appssets`: Contains the ApplicationSet resource. A sample ApplicationSet is used to deploy multiple apps across multiple environments.
- `scripts`: Utility scripts reside here. Use the [create-new-app.sh](./scripts/create-new-app.sh) script to initialize the structure for a new application.
```
./scripts/create-new-app.sh todo-example
```
## Deployment Workflow
All deployments for various environments reference a single Git branch. Follow these steps for any new changes:
- Create a new branch and PR for dev deployment. After PR review, merge it into the main branch to initiate a new deployment to the dev environment.
- Repeat the same steps for stage and prod environments.
Deployments in `dev` and `stage` are standalone, while `prod` deployments, excluding todo-db due to its nature as a database service, are deployed using Blue-Green configurations.
### Key Points
- **Single Git Branch**: All environments reference the main branch for consistency.
- **PR Review Process**: Ensures quality and approval before merging.
- **Standalone Deployments**: Dev and stage environments have independent deployments.
- **Blue-Green Deployments**: Prod deployments (except todo-db) utilize Blue-Green strategies for minimal downtime.