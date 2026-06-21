# Tutorials — Helm Charts, Service Mesh & ArgoCD GitOps

A four-chapter hands-on guide to deploying and managing applications on OpenShift using a platform-engineering approach. These tutorials follow the journey of two teams — **infrastructure** and **application** — working together to build a consistent, secure, and automated deployment pipeline.

---

## Why These Tutorials Exist

Deploying applications on Kubernetes starts simple — a few `kubectl apply` commands and you're done. But as teams grow, three problems appear:

### Problem 1: Every App Team Reinvents the Wheel

Without shared standards, each team writes their own Deployment YAML from scratch. Labels are inconsistent. Security contexts differ. When the platform team needs to add a required label to every pod, they have to touch dozens of repos. **Helm library charts** solve this by centralizing templates into a shared library that every team consumes. Write the template *once*. Every team gets it *automatically*.

→ **Tutorial 1** teaches this pattern end-to-end.

### Problem 2: CI/CD Pipelines Don't Fit Kubernetes

Traditional CI/CD pushes changes to a cluster (`kubectl apply` from a pipeline). But Kubernetes is *declarative* — it's designed to reconcile towards a desired state, not receive push commands. **GitOps** flips the model: you declare the desired state in git, and a controller inside the cluster continuously enforces it. Rollbacks become `git revert`. Disaster recovery becomes "point at a new cluster." The pipeline only updates git — the cluster pulls what it needs.

→ **Tutorial 3** walks through setting up ArgoCD to manage *everything* via GitOps — infrastructure services and application deployments alike.

### Problem 3: Networking, Security, and Observability Are Everyone's Problem — and Nobody's

In a microservice world, every service needs TLS encryption, retry logic, metrics, and tracing. If each app team implements these themselves, you get a patchwork: some services encrypt traffic, some don't. Some export Prometheus metrics, some don't. Debugging a slow request means grepping logs across 4 different services. **A service mesh** moves these concerns out of application code and into a shared infrastructure layer. App teams focus on business logic. The mesh handles mTLS, retries, tracing, and authorization transparently.

→ **Tutorial 2** installs the mesh. **Tutorial 4** shows how app teams plug into it — with a single `serviceMesh.enabled: true` toggle.

### The Big Picture

```
┌──────────────────────────────────────────────────────────────┐
│                    APP TEAMS (Tutorial 4)                    │
│                                                              │
│   deploy apps with a simple values.yaml.                     │
│   mesh, security, observability come for free.               │
├──────────────────────────────────────────────────────────────┤
│                  SERVICE MESH (Tutorial 2)                   │
│                                                              │
│   mTLS, tracing, metrics, auth — configured once by infra.   │
│   app teams never touch it.                                  │
├──────────────────────────────────────────────────────────────┤
│                  GITOPS / ARGOCD (Tutorial 3)                │
│                                                              │
│   everything is driven by git.                               │
│   ArgoCD ensures the cluster matches the repo.               │
│   Works for infra services and application deployments.      │
├──────────────────────────────────────────────────────────────┤
│                  HELM CHARTS (Tutorial 1)                    │
│                                                              │
│   reusable templates (library-chart).                        │
│   standardized Deployments, Services, HPAs for every app.    │
└──────────────────────────────────────────────────────────────┘
```

---

## Tutorial Roadmap

```
Beginner                    Intermediate              Advanced
─────────                   ────────────              ────────

┌──────────────────┐       ┌──────────────────┐     ┌──────────┐
│  Tutorial 1      │──────▶│  Tutorial 2      │────▶│ Tutorial │
│  Helm Chart      │       │  Service Mesh    │     │ 3        │
│  Reusability     │       │  Installation    │     │ ArgoCD   │
└──────────────────┘       └──────────────────┘     │ AppSet   │
       │                                            └──────────┘
       │                                                   │
       ▼                                                   │
┌──────────────────┐                                       │
│  Tutorial 4      │◀──────────────────────────────────────┘
│  Capstone        │
│  Todo App Stack  │
└──────────────────┘
```

---

## The Tutorials

### [Tutorial 1: Building Reusable Helm Charts with a Library Chart](tutorial-1-helm-chart-reusability.md)

**Level:** Beginner · **Role:** Platform team

Learn how to build a shared library chart (`library-chart`) that every application team can consume. Cover named templates, helper functions for consistent labels, and how `app-deployment` delegates its entire Deployment template to the library — so a 100-line Deployment becomes one line: `{{ include "library-chart.createDeployment" . }}`.

Ends with your first umbrella chart and the `file://` dependency pattern for local development.

**Prerequisite:** Basic Helm knowledge (`helm install`, `values.yaml`, `helm template`)

---

### [Tutorial 2: Installing OpenShift Service Mesh as a Day-2 Component](tutorial-2-openshift-service-mesh.md)

**Level:** Intermediate · **Role:** Infra team

Start with *why* a service mesh exists — the networking problems microservices create and how sidecar proxies solve them. Then install the full stack: OSSM operators, ServiceMeshControlPlane, Tempo for distributed tracing, Kiali for visualization, and Istio ingress gateways with TLS and external authorization. Every component is deployed using the Helm charts from Tutorial 1.

**Prerequisite:** Tutorial 1, an OpenShift cluster with cluster-admin access

---

### [Tutorial 3: ArgoCD and GitOps — Automated Deployments for Infra and App Teams](tutorial-3-argocd-appset-service-mesh.md)

**Level:** Advanced · **Role:** Both teams

Learn GitOps from first principles — the push vs pull deployment models, why ArgoCD fits Kubernetes, and how an ApplicationSet with a matrix generator deploys components to multiple clusters. The patterns work the same whether you're deploying infrastructure services (operators, mesh) or application stacks (database → API → frontend). Master sync waves for ordered deployments and understand what they *don't* guarantee.

**Prerequisites:** Tutorials 1 & 2, ArgoCD + ApplicationSet controller installed

---

### [Tutorial 4: Capstone — Deploying a Todo App Stack](tutorial-4-appteam-todo-app.md)

**Level:** Beginner–Intermediate · **Role:** App team

Apply everything from Tutorials 1–3 in a hands-on capstone. Deploy a three-tier todo app (PostgreSQL + Quarkus + React) with 7 exercises: deploy the DB, API, and UI; enable service mesh with a single toggle; trigger a blue-green rollout; deploy to multiple environments; and scaffold a brand new app with `create-new-app.sh`. Every exercise ends with a "check your understanding" question that references concepts from earlier tutorials.

**Prerequisites:** Tutorials 1–3, a cluster with service mesh installed

---

## Who Should Read What

| You are... | Start with | Then |
|------------|-----------|------|
| An app developer who wants to deploy to OpenShift | Tutorial 4 (comes back to 1 for Helm concepts) | Tutorial 2 for mesh concepts |
| A platform/infra engineer setting up shared tooling | Tutorial 1 → 2 → 3 in order | Tutorial 4 to validate from the app team's perspective |
| Someone evaluating Helm vs Kustomize | Tutorial 1 §2 (side-by-side comparison) | — |
| Someone who already uses Helm but wants better reusability | Tutorial 1 §5–13 (library charts, multi-layer deps) | — |

---

## Repository Reference

| Path | What's inside |
|------|--------------|
| `helm-charts/library-chart/` | Core library chart — `_*.tpl` templates for Deployments, Services, HPAs, Secrets, PVCs, Service Mesh |
| `helm-charts/app-deployment/` | Application chart — thin template files that delegate to the library |
| `helm-charts/app-servicemesh/` | Service mesh enabling chart — labels namespaces, creates VirtualServices |
| `helm-charts/sm-ingress/` | Ingress gateway chart — Istio Gateways, AuthorizationPolicies, Routes, TLS |
| `helm-charts/sm-control-plane/` | SMCP chart — ServiceMeshControlPlane + MemberRoll + Telemetry |
| `helm-charts/k8s-operators/` | Operator subscriptions (OSSM, Tempo, Kiali via OLM) |
| `helm-charts/tempo/` | Tempo distributed tracing (TempoStack + ExternalSecret + VirtualService) |
| `helm-charts/kiali/` | Kiali visualization dashboard |
| `helm-charts/argo-applications/` | ArgoCD Application generator — one template, many Applications |
| `examples/infra/apps/service-mesh/` | Infra umbrella chart — deploys the entire mesh via `argo-applications` |
| `examples/infra/appset/` | ApplicationSet YAML — matrix generator for multi-cluster GitOps |
| `examples/appteam1/apps/` | App team umbrella charts — `todo-api`, `todo-db`, `todo-ui` |
