# Tutorial 3: ArgoCD and GitOps — Automated Deployments for Infra and App Teams

**Level:** Advanced  
**Prerequisites:** [Tutorial 1 — Helm Chart Reusability](tutorial-1-helm-chart-reusability.md), [Tutorial 2 — Service Mesh Installation](tutorial-2-openshift-service-mesh.md)  
**Goal:** Understand GitOps from first principles, then automate deployments across multiple clusters using ArgoCD ApplicationSet with sync-wave ordering. The patterns you learn here work for both infrastructure services (like service mesh) and application deployments (like the todo stack).

Tutorial 1 gave you reusable Helm charts. Tutorial 2 gave you a working service mesh. Now you'll automate *everything* using GitOps — so whether it's infra operators or app deployments, the cluster is driven by what's in git, not by someone running commands from their laptop.

---

## Table of Contents

1. [What Is GitOps and Why Does It Matter?](#1-what-is-gitops-and-why-does-it-matter)
2. [How ArgoCD Implements GitOps](#2-how-argocd-implements-gitops)
3. [Why ApplicationSet + Sync Waves?](#3-why-applicationset--sync-waves)
4. [Architecture Overview](#4-architecture-overview)
5. [The `argo-applications` Helm Chart](#5-the-argo-applications-helm-chart)
6. [The ApplicationSet Generator](#6-the-applicationset-generator)
7. [Sync Wave Ordering Strategy](#7-sync-wave-ordering-strategy)
8. [Putting It Together: The Umbrella Chart](#8-putting-it-together-the-umbrella-chart)
9. [Deploying the Full Stack](#9-deploying-the-full-stack)
10. [Multi-Cluster Considerations](#10-multi-cluster-considerations)
11. [Key Takeaways](#11-key-takeaways)

---

## 1. What Is GitOps and Why Does It Matter?

### How Kubernetes Was Historically Managed

In the early years of Kubernetes, deployments typically followed a "push" model. A CI pipeline (Jenkins, GitLab CI) would build a container image, then run `kubectl apply` or `helm install` against a cluster. This worked for a single cluster and a single team, but it created several problems at scale:

**Operators couldn't see what was actually deployed.** The CI pipeline pushed to the cluster, but there was no record of what was running *right now* outside of the cluster itself. If someone ran `kubectl edit deployment` directly on the cluster (a "drift"), nobody knew unless something broke.

**Rolling back meant re-running a pipeline.** If a bad deployment went out, you couldn't just "undo." You had to find the last good commit, kick off the pipeline again, and hope it succeeded. This turns a 10-second operation into a 10-minute ordeal.

**Disaster recovery was manual.** If a cluster died, you'd run your Helm commands one by one, in the right order, from memory — or from a runbook that was probably out of date.

**Multi-cluster was painful.** Adding a second cluster meant duplicating pipeline stages, secrets, and configuration. Each new cluster was a new source of drift.

### The GitOps Idea

In 2017, a team at Weaveworks published a set of principles that became known as **GitOps**:

1. **Git is the single source of truth.** Every Kubernetes resource, Helm chart, and configuration value lives in a git repository. Nothing is deployed that isn't committed.
2. **The desired state is declarative.** That git repo describes what the cluster *should* look like. There's no "do this, then that" script — just the end state.
3. **A controller enforces the desired state.** An agent (like ArgoCD) continuously compares the git repo with the live cluster. If they differ, the agent reconciles — either by applying changes from git, or by alerting on drift.
4. **No direct cluster access for deployments.** CI pipelines still exist, but they only update git (not the cluster). The GitOps controller is the only thing that deploys.

> **Metaphor:** GitOps is like a thermostat. You don't manually turn the heater on and off all day. You set the desired temperature once (commit to git), and the thermostat (ArgoCD) continuously adjusts the room to match. If someone opens a window (manual `kubectl edit`), the thermostat notices and brings things back to where you set them.

### Push vs Pull Deployment

| | Traditional CI/CD (Push) | GitOps (Pull) |
|---|---|---|
| **Who deploys** | CI pipeline (`kubectl apply`) | GitOps controller (ArgoCD) |
| **Source of truth** | The pipeline script | The git repository |
| **What happens on drift** | Nobody notices | Controller reverts or alerts |
| **Rollback** | Re-run old pipeline | `git revert` + controller syncs |
| **Disaster recovery** | Manual runbook | Point controller at a new cluster; it recreates everything |
| **Cluster credentials** | Stored in CI secrets | Never leave the cluster |

---

## 2. How ArgoCD Implements GitOps

ArgoCD is a Kubernetes-native GitOps controller. It runs inside your cluster and watches git repositories for changes.

### Core Concepts

| Concept | What It Is |
|---------|-----------|
| **Application** | A single ArgoCD resource that says "sync this git path to this cluster namespace" |
| **ApplicationSet** | A generator that creates many Applications from a template — like a mail-merge for ArgoCD |
| **Project** | A logical grouping of Applications with RBAC and allow-lists |
| **Sync** | The process of making the live cluster match the git repo |
| **Sync Wave** | A numeric ordering hint (`argocd.argoproj.io/sync-wave`) that tells ArgoCD which Applications to sync first |

### How One ArgoCD Application Works

```
┌──────────┐       ┌─────────────────┐       ┌─────────────────┐
│ Git Repo │──────▶│    ArgoCD       │──────▶│ Kubernetes      │
│          │       │  (controller)   │       │  Cluster        │
│ values/  │       │                 │       │                 │
│ charts/  │       │ 1. Compares git │       │ 3. Live state   │
│ apps/    │       │    vs cluster   │       │    matches git  │
└──────────┘       │ 2. Applies diff │       └─────────────────┘
                   └─────────────────┘
```

Every 3 minutes (configurable), ArgoCD:
1. Clones the git repo at the specified revision
2. Renders the Kubernetes manifests (via plain YAML, Helm, or Kustomize)
3. Compares them against the live cluster state
4. If there's a difference, it applies the git version to the cluster
5. Reports the sync status (Synced, OutOfSync, Unknown)

### Why ArgoCD Fits Kubernetes So Well

ArgoCD understands Kubernetes resources natively. When you point it at a git directory containing a `Chart.yaml`, it knows to run `helm template` before comparing. It tracks each resource individually — if a single ConfigMap is out of sync, it detects and fixes just that ConfigMap, not the entire Application.

---

## 3. Why ApplicationSet + Sync Waves?

### The Problem

Whether you're deploying infrastructure components or applications, real-world Kubernetes deployments involve multiple pieces that depend on each other:

**Infra example — service mesh:**
```
Operators (syncWave 0)
    │
    ▼
SMCP (syncWave 2)      ← must wait for operators to be ready
    │
    ▼
Tracing / Kiali (syncWave 3)  ← must wait for SMCP to be ready
    │
    ▼
Ingress Gateways (syncWave 4) ← must wait for SMCP to be ready
```

**App example — a multi-service application:**
```
Database (syncWave 0)
    │
    ▼
API (syncWave 1)       ← must wait for database to be ready
    │
    ▼
UI (syncWave 2)        ← must wait for API to be ready
```

The same pattern appears everywhere: components with dependencies need ordered deployment. Without an ApplicationSet:
- You deploy each chart manually — error-prone across clusters
- You rely on external orchestration (CI/CD pipelines) to handle ordering
- Adding a new cluster or app means duplicating configuration

### The Solution

**ArgoCD ApplicationSet** + **sync waves** + **umbrella Helm chart** solves this for any team:

| Capability | How |
|------------|-----|
| Single source of truth | Git repo defines all clusters and apps |
| Ordered deployment | `argocd.argoproj.io/sync-wave` annotation controls sequencing |
| Multi-cluster | `clusters` generator creates per-cluster applications |
| Reusable configuration | Umbrella Helm chart parameterizes values per environment |

---

## 4. Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                      ApplicationSet                                 │
│                (matrix: clusters × git directories)                 │
│                                                                     │
│        Generates ArgoCD Applications for every combination          │
│                                                                     │
│   Infra team example:                App team example:              │
│   ┌──────────┐ ┌────────┐           ┌──────────┐ ┌──────────┐       │
│   │ operators│ │  smcp  │           │ todo-db  │ │ todo-api │       │
│   │ wave: 0  │ │wave: 2 │           │ wave: 0  │ │ wave: 1  │       │
│   └──────────┘ └────────┘           └──────────┘ └──────────┘       │
│   ┌──────────┐ ┌──────────┐         ┌──────────┐                    │
│   │ tracing  │ │ingresses │         │ todo-ui  │                    │
│   │wave: 3   │ │wave: 4   │         │ wave: 2  │                    │
│   └──────────┘ └──────────┘         └──────────┘                    │
└─────────────────────────────────────────────────────────────────────┘
```

Each ArgoCD Application points to a git directory containing a Helm chart for one component. The same ApplicationSet pattern serves both infra and app teams — only the values change.

---

## 5. The `argo-applications` Helm Chart

The `argo-applications` chart (`helm-charts/argo-applications/`) generates ArgoCD `Application` resources dynamically.

### Chart.yaml

```yaml
apiVersion: v2
name: argo-applications
type: application
version: 0.1.1
dependencies:
  - name: library-chart
    version: 0.3.x
    repository: "file://../library-chart"
```

### Template: `templates/application.yaml`

```yaml
{{- $root := . -}}
{{- range $appName, $appValues := .Values.apps }}
{{- if $appValues.enabled }}
---
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: {{ $root.Release.Name }}-{{ $appName }}-{{ tpl $root.Values.clusterName $root }}
  annotations:
    argocd.argoproj.io/sync-wave: "{{ $appValues.syncWave }}"
  labels:
    {{- include "library-chart.labels" $root | nindent 4 }}
  namespace: {{ $root.Values.namespace | default "argocd" }}
spec:
  project: {{ $root.Values.argoProject }}
  source:
    repoURL: {{ $root.Values.gitRepoUrl }}
    targetRevision: {{ $root.Values.gitTargetRevision }}
    path: {{ $root.Values.appsDir }}/{{ $appName }}
    helm:
      valueFiles:
        - values.yaml
      releaseName: "{{ $appName }}"
  destination:
    name: {{ tpl $root.Values.clusterName $root }}
    namespace: {{ $appValues.namespace }}
  syncPolicy:
    {{- toYaml $root.Values.syncPolicy | nindent 4 }}
  {{- if $appValues.ignoreDifferences }}
  ignoreDifferences:
    {{- toYaml $appValues.ignoreDifferences | nindent 4 }}
  {{- end }}
{{- end }}
{{- end }}
```

Key behaviors:
- **Iterates** over `.Values.apps` — each app becomes one ArgoCD Application
- **Sync wave** annotation controls deployment ordering
- **Cluster name** is injected as a Helm template parameter (`tpl`)
- Each app points to its own sub-directory (`path: {{ appsDir }}/{{ appName }}`)

### Values Format

The `argo-applications` chart accepts any number of apps with any names — you define what makes sense for your team:

**For an infra team deploying service mesh:**

```yaml
argo-applications:
  appsDir: apps/service-mesh/dev/apps
  apps:
    operators:
      namespace: openshift-operators
      syncWave: 0
    smcp:
      namespace: istio-system
      syncWave: 2
    ingresses:
      namespace: mesh
      syncWave: 4
```

**For an app team deploying a multi-service stack:**

```yaml
argo-applications:
  appsDir: apps/myapp/dev/apps
  apps:
    database:
      namespace: myapp-data
      syncWave: 0
    api:
      namespace: myapp-api
      syncWave: 1
    frontend:
      namespace: myapp-web
      syncWave: 2
```

The chart doesn't care what you name your apps or what they deploy — it just generates one ArgoCD Application per entry.

---

## 6. The ApplicationSet Generator

The `ApplicationSet` (`examples/infra/appset/day2-services.yaml`) uses a **matrix generator** that combines:

1. **Clusters generator** — Discovers clusters labeled for ArgoCD
2. **Git generator** — Discovers directories matching the pattern `apps/*/{{.name}}`

### The ApplicationSet YAML

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: day2-services-appset
  namespace: argocd
spec:
  goTemplate: true
  goTemplateOptions: ["missingkey=error"]
  generators:
    - matrix:
        generators:
          - clusters:
              selector:
                matchLabels:
                  argocd.argoproj.io/secret-type: cluster
          - git:
              repoURL: https://github.example-org.com/gitops/day2-services.git
              revision: multi-clusters
              directories:
                - path: apps/*/{{.name}}
  template:
    metadata:
      name: 'day2-{{ index .path.segments 1 }}-{{ .path.basenameNormalized }}'
    spec:
      project: default
      source:
        repoURL: https://github.example-org.com/gitops/day2-services.git
        targetRevision: multi-clusters
        path: 'apps/{{ index .path.segments 1 }}/{{ index .path.segments 2 }}'
        helm:
          valueFiles:
            - "values.yaml"
            - "../values.yaml"
          ignoreMissingValueFiles: true
          parameters:
            - name: "global.clusterName"
              value: "{{ .path.basenameNormalized }}"
          releaseName: "{{ index .path.segments 1 }}"
      destination:
        server: "{{ .server }}"
        namespace: '{{ index .path.segments 1 }}'
      syncPolicy:
        syncOptions:
          - CreateNamespace=true
        automated:
          prune: true
          selfHeal: true
```

### How the Matrix Generator Works

The generator produces a **Cartesian product** of clusters × directories:

```
Clusters: [ocp-dev1, ocp-prod1]
Directories: [apps/service-mesh/ocp-dev1, apps/iam-auth-controller/ocp-prod1]
                              ↓
Generated Applications:
  - day2-service-mesh-ocp-dev1  → deploys to ocp-dev1 cluster
  - day2-iam-auth-controller-ocp-prod1 → deploys to ocp-prod1 cluster
```

### Template Parameters Available

| Parameter | Source | Example Value |
|-----------|--------|---------------|
| `{{ .path.basenameNormalized }}` | Git generator | `ocp-dev1` |
| `{{ index .path.segments 1 }}` | Git generator path segments | `service-mesh` |
| `{{ index .path.segments 2 }}` | Git generator path segments | `ocp-dev1` |
| `{{ .server }}` | Clusters generator | `https://api.cluster.example.com:6443` |
| `{{ .name }}` | Clusters generator | `ocp-dev1` |

**Key insight:** The `global.clusterName` Helm parameter is injected so that every sub-chart can reference `{{ .Values.global.clusterName }}` to know which cluster it's deploying to.

---

## 7. Sync Wave Ordering Strategy

Sync waves control **what deploys when**. The specific numbering depends on your dependencies, but the principle is the same for both infra and app teams:

### Example: Infra Team (Service Mesh)

| SyncWave | Components | Depends On | Rationale |
|----------|-----------|------------|-----------|
| **0** | `operators` | — | OLM subscriptions must be installed first; CRDs won't exist otherwise |
| **1** | _(reserved)_ | operators | _Space for additional operator-dependent resources_ |
| **2** | `smcp` | operators | SMCP needs the OSSM operator to be running and CRDs registered |
| **3** | `tracing-system`, `kiali` | smcp | Tempo/Kiali need the mesh to be ready; they configure tracing/monitoring |
| **4** | `ingresses`, `sample-app` | smcp | Gateways and sample apps need the control plane to be running |

### Example: App Team (Multi-Service Application)

| SyncWave | Components | Depends On | Rationale |
|----------|-----------|------------|-----------|
| **0** | `database` | — | Services can't start without data stores |
| **1** | `api` | database | API needs the database to be running |
| **2** | `frontend`, `worker` | api | Frontend/workers need the API to be reachable |

The same pattern applies: lower waves deploy first, higher waves wait their turn. Whether it's infrastructure or an application, the mechanics are identical.

### What Sync Waves Do (and Don't Do)

Sync waves control **when ArgoCD begins syncing** an application. However, they do not block subsequent waves from starting if earlier waves have not completed.

> **Think of it like a relay race.** The baton (the sync wave number) determines who runs first, second, and third. But if the first runner trips and falls, the second runner still gets handed the baton. Sync waves order the start, not the finish.

| Capability | Supported? |
|------------|-----------|
| Application A starts syncing before Application B | ✅ Yes |
| Application A must complete before Application B starts | ❌ No — waves only order starts |
| Application B waits if Application A fails | ❌ No — use retry + health checks |
| Application A must reach "Healthy" before Application B proceeds | ⚠️ Best-effort — not guaranteed |

**Recommendation:** Use sync waves for ordering, but design each component to tolerate earlier components being temporarily unhealthy. For strict ordering, configure `syncPolicy.automated.selfHeal: true` and rely on retries.

### How the Sync Wave Annotation Is Applied

The `argo-applications` template adds the annotation:

```yaml
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "{{ $appValues.syncWave }}"
```

This results in ArgoCD processing applications in ascending wave order:
- All wave-0 applications start syncing first
- When all wave-0 applications reach their desired state, wave-2 begins
- And so on

---

## 8. Putting It Together: The Umbrella Chart

The **umbrella chart** ties the `argo-applications` chart together with component-specific values. Our repo has a concrete example for infra (service mesh), but the same structure works for app teams.

### For the Infra Team (Service Mesh)

The umbrella at `examples/infra/apps/service-mesh/dev/`:

```
examples/infra/apps/service-mesh/
└── dev/
    ├── Chart.yaml          ← umbrella chart (depends on argo-applications + library-chart)
    ├── values.yaml         ← defines all apps, sync waves, and their configurations
    └── apps/               ← sub-directories for each component's Helm chart
        ├── operators/
        │   ├── Chart.yaml  ← depends on k8s-operators chart
        │   └── values.yaml ← operator subscription details
        ├── smcp/
        │   ├── Chart.yaml  ← depends on sm-control-plane chart
        │   └── values.yaml ← SMCP configuration
        ├── tracing-system/
        │   └── ...         ← depends on tempo + app-servicemesh
        ├── kiali/
        │   └── ...         ← depends on kiali chart
        ├── ingresses/
        │   └── ...         ← depends on sm-ingress + app-servicemesh
        └── sample-app/
            └── ...         ← depends on app-servicemesh + sm-ingress
```

### For App Teams

An app team would use the exact same structure — just different app names and namespaces:

```
apps/my-stack/              ← you choose the name
└── dev/
    ├── Chart.yaml          ← depends on argo-applications + library-chart (same as infra)
    ├── values.yaml         ← defines database, api, frontend with their sync waves
    └── apps/               ← one sub-directory per service
        └── database/, api/, frontend/
```

### Umbrella Dependencies (Both Teams)

File: `examples/infra/apps/service-mesh/dev/Chart.yaml`

```yaml
apiVersion: v2
name: service-mesh
type: application
version: 0.1.0
dependencies:
  - name: argo-applications
    version: ">=0.1.0"
    repository: "file://../../../../../helm-charts/argo-applications"
  - name: library-chart
    version: ">=0.1.0"
    repository: "file://../../../../../helm-charts/library-chart"
```

### Umbrella Chart Values

File: `examples/infra/apps/service-mesh/dev/values.yaml`

```yaml
argo-applications:
  gitRepoUrl: https://github.example-org.com/gitops/day2-services.git
  gitTargetRevision: multi-clusters
  argoProject: default
  namespace: argocd
  appsDir: apps/service-mesh/dev/apps
  apps:
    operators:
      namespace: openshift-operators
      enabled: true
      syncWave: 0
    smcp:
      namespace: istio-system
      enabled: true
      syncWave: 2
    tracing-system:
      namespace: tracing-system
      enabled: true
      syncWave: 3
    kiali:
      namespace: istio-system
      enabled: true
      syncWave: 3
    ingresses:
      namespace: mesh
      enabled: true
      syncWave: 4
    sample-app:
      namespace: bookinfo
      enabled: true
      syncWave: 4
```

### Sub-Chart Example: SMCP

File: `examples/infra/apps/service-mesh/dev/apps/smcp/Chart.yaml`

```yaml
dependencies:
  - name: app-servicemesh          ← provides namespace labeling
    version: ">=0.1.0"
    repository: "file://../../../../../../helm-charts/app-servicemesh"
  - name: sm-control-plane
    version: ">=0.1.0"
    repository: "file://../../../../../../helm-charts/sm-control-plane"
  - name: library-chart
    version: ">=0.1.0"
    repository: "file://../../../../../../helm-charts/library-chart"
```

File: `examples/infra/apps/service-mesh/dev/apps/smcp/values.yaml`

```yaml
app-servicemesh:
  enabled: true
sm-control-plane:
  serviceMeshControlPlane:
    name: basic
  serviceMeshMemberRoll:
    name: default
  telemetry:
    name: mesh-default
```

---

## 9. Deploying the Full Stack

### Prerequisites

- OpenShift cluster with ArgoCD installed
- ArgoCD ApplicationSet controller enabled
- Cluster registered with ArgoCD (secret with `argocd.argoproj.io/secret-type: cluster` label)

### Step 1: Deploy the ApplicationSet

```bash
oc apply -f examples/infra/appset/day2-services.yaml
```

This creates the ApplicationSet in the `argocd` namespace.

### Step 2: Watch Applications Appear

```bash
oc get applications -n argocd -w
```

You should see applications appearing for each cluster × component combination:

```
day2-operators-ocp-dev1
day2-smcp-ocp-dev1
day2-tracing-system-ocp-dev1
day2-kiali-ocp-dev1
day2-ingresses-ocp-dev1
```

### Step 3: Monitor Sync Progress

```bash
# Watch sync status
oc get applications -n argocd \
  -o custom-columns=NAME:.metadata.name,SYNC:.status.sync.status,HEALTH:.status.health.status,WAVE:.metadata.annotations.argocd\.argoproj\.io/sync-wave

# Expected progression:
# 1. Wave 0 → operators sync and become Healthy
# 2. Wave 2 → smcp syncs
# 3. Wave 3 → tracing, kiali sync
# 4. Wave 4 → ingresses, sample-app sync
```

### Step 4: Deploy Without ApplicationSet (Direct Helm)

You can also deploy directly using the umbrella chart for testing:

```bash
# Update all sub-chart dependencies
helm dependency update examples/infra/apps/service-mesh/dev

# Template to see what would be created
helm template service-mesh examples/infra/apps/service-mesh/dev

# Or deploy directly (for dev/testing)
helm upgrade --install service-mesh examples/infra/apps/service-mesh/dev
```

---

## 10. Multi-Cluster Considerations

### Adding a New Cluster

1. Register the cluster with ArgoCD by creating a Secret:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: my-new-cluster
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: cluster
stringData:
  name: my-new-cluster
  server: https://api.my-new-cluster.example.com:6443
  config: |
    {
      "bearerToken": "<token>",
      "tlsClientConfig": {
        "insecure": false,
        "caData": "<base64-ca>"
      }
    }
```

2. Create a cluster-specific directory in the git repo:

```
apps/service-mesh/my-new-cluster/
├── Chart.yaml
├── values.yaml                 ← cluster-specific values
└── apps/                       ← (optional) per-component overrides
```

3. The ApplicationSet generator will automatically detect the new cluster and directory, creating Applications without any changes to the ApplicationSet itself.

### Cluster-Specific Values

Each cluster can have its own overrides. The ApplicationSet spec loads values from two levels:

```yaml
helm:
  valueFiles:
    - "values.yaml"          # Per-cluster values (e.g., apps/service-mesh/my-cluster/values.yaml)
    - "../values.yaml"       # Shared environment values (e.g., apps/service-mesh/values.yaml)
  ignoreMissingValueFiles: true
```

The `ignoreMissingValueFiles: true` allows clusters to omit the shared values file if it doesn't exist.

### Disabling Components Per Cluster

Use `enabled: false` in cluster-specific values:

```yaml
# apps/service-mesh/my-new-cluster/values.yaml (or ../values.yaml)
argo-applications:
  apps:
    sample-app:
      enabled: false   # Don't deploy sample-app to this cluster
```

The `argo-applications` template checks `{{- if $appValues.enabled }}` before generating each Application.

---

## 11. Key Takeaways

1. **ApplicationSet with matrix generator** = Multi-cluster × multi-component deployment from a single YAML file
2. **Sync waves** (`argocd.argoproj.io/sync-wave`) control deployment ordering but are best-effort — design components to tolerate dependencies not being fully ready
3. **The `argo-applications` chart** generates one ArgoCD Application per component per cluster, parameterized by `global.clusterName`
4. **Umbrella chart pattern** keeps the configuration DRY — the umbrella deploys the `argo-applications` chart with the correct values, and the ApplicationSet handles the rest
5. **File organization matters** — each cluster gets its own directory with environment-specific `values.yaml`, and each component gets its own sub-directory with a Helm chart that references charts from `helm-charts/`
6. **Adding a new cluster** requires only a cluster Secret + a new directory in git — no ApplicationSet changes needed

---

## Hands-On Exercise

```bash
# 1. Deploy the ApplicationSet
oc apply -f examples/infra/appset/day2-services.yaml

# 2. Verify Applications are created
oc get applications -n argocd | grep day2

# 3. Check sync wave ordering
oc get applications -n argocd -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.metadata.annotations.argocd\.argoproj\.io/sync-wave}{"\n"}{end}'

# 4. Check which cluster each app targets
oc get applications -n argocd -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.destination.name}{"\n"}{end}'

# 5. Sync a specific app manually
oc argocd app sync day2-operators-<cluster-name>
```

---

**What comes next:** Tutorial 4 is the capstone. You'll take everything from these three tutorials — Helm charts, service mesh, GitOps patterns — and use them to deploy a real application stack. It's hands-on from start to finish: deploy a database, API, and UI, plug them into the mesh, trigger a blue-green rollout, and deploy to multiple environments.

**Next:** [Tutorial 4 — Capstone: Deploying a Todo App Stack](tutorial-4-appteam-todo-app.md)
