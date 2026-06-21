# Tutorial 1: Building Reusable Helm Charts with a Library Chart

**Level:** Beginner  
**Goal:** Understand how to write Helm charts with a shared library chart at the core, and compose multi-layer chart dependencies.

---

## Table of Contents

1. [Why Do We Need a Tool for Kubernetes Manifests?](#1-why-do-we-need-a-tool-for-kubernetes-manifests)
2. [The Two Main Approaches: Helm vs Kustomize](#2-the-two-main-approaches-helm-vs-kustomize)
3. [Why Helm Charts Won for This Project](#3-why-helm-charts-won-for-this-project)
4. [The Problem: Duplicated Templates](#4-the-problem-duplicated-templates)
5. [Solution: Library Charts](#5-solution-library-charts)
6. [Our Library Chart: `library-chart`](#6-our-library-chart-library-chart)
7. [Helpers: The `_helpers.tpl` Foundation](#7-helpers-the-_helperstpl-foundation)
8. [Reusable Templates in `_*.tpl` Files](#8-reusable-templates-in-_tpl-files)
9. [Application Chart: `app-deployment`](#9-application-chart-app-deployment)
10. [Multi-Layer Dependencies](#10-multi-layer-dependencies)
11. [Using `file://` Dependencies for Local Development](#11-using-file-dependencies-for-local-development)
12. [Writing Your Own Umbrella Chart](#12-writing-your-own-umbrella-chart)
13. [Key Takeaways](#13-key-takeaways)

---

## 1. Why Do We Need a Tool for Kubernetes Manifests?

### The Raw Kubernetes Way

Imagine you have a simple web application. To run it on Kubernetes, you create YAML files — one for a Deployment, one for a Service, maybe a ConfigMap, and an Ingress. That's four files for one app:

```bash
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml
kubectl apply -f configmap.yaml
kubectl apply -f ingress.yaml
```

That works for **one app**. Now imagine your team has **20 apps**, each running in **3 environments** (dev, stage, prod). Suddenly you have:

```
20 apps × 4 resources × 3 environments = 240 YAML files
```

That is **240 files** to create, maintain, and keep in sync. One typo, one forgotten update, and your app breaks.

### The Problems That Arise

| Problem | What It Looks Like |
|---------|-------------------|
| **Copy-paste errors** | Someone copies a Deployment YAML for a new app but forgets to change the container port. The app deploys but doesn't work. |
| **Inconsistent labels** | One team uses `app: my-app`, another uses `name: my-app`. The monitoring system can't find pods. |
| **Environment drift** | The dev Deployment has 1 replica, prod has 3. Someone updates the dev file but forgets prod. |
| **Updating is painful** | Your security team requires a new label on every pod. You open 60 YAML files to add it. |
| **No parameterization** | You need different replica counts per environment. You maintain three separate copies of the same file with one number changed. |

**Why this happens:** Kubernetes YAML files are static. There's no built-in way to say "the replica count should be 1 in dev but 3 in prod." You end up duplicating entire files for tiny differences.

> **Metaphor:** Think of a restaurant chain. Nobody builds a new kitchen from scratch every time a customer orders. You have a standard recipe, ingredients that vary per location, and a process everyone follows. Raw Kubernetes is like writing down the recipe from scratch every single time — repetitive, error-prone, and wasteful.

### The Evolution of Solutions

Kubernetes users quickly realized they needed a way to **template**, **parameterize**, and **reuse** their YAML files. Two major tools emerged:

| Era | Approach | Example |
|-----|----------|---------|
| **2015–2016** | Shell scripts + sed/awk | `cat deployment.yaml | sed "s/{{VERSION}}/$TAG/g"` — search-and-replace, fragile |
| **2016** | Helm (v1) | First dedicated templating engine for Kubernetes |
| **2017** | Kustomize (kubectl built-in) | Declarative YAML overlays, no templating |
| **2019+** | Helm v3 + Kustomize | Both mature, different philosophies |

---

## 2. The Two Main Approaches: Helm vs Kustomize

To understand why this project uses Helm, you first need to understand how the two main tools compare.

### What Is Helm?

Helm is a **package manager and templating engine** for Kubernetes — like `apt-get` for Ubuntu or `brew` for macOS, but for deploying applications to a cluster.

**Core concepts:**

| Concept | What It Is |
|---------|-----------|
| **Chart** | A packaged set of Kubernetes templates + default values |
| **Release** | A running instance of a chart in a cluster — you can upgrade or uninstall it |
| **Values** | Parameters you pass to customize a chart (`values.yaml`) |
| **Template** | A YAML file with `{{ }}` placeholders that get replaced at install time |

The important thing to know is that Helm uses **Go templates** — the `{{ }}` syntax you see inside YAML files. This means your templates can contain `if` statements, `range` loops, and function calls, just like a programming language. For example, you can say "if blue-green is enabled, create a Rollout instead of a Deployment."

```
You write:
    Chart.yaml       ← metadata about the chart (like an envelope label)
    values.yaml      ← default configuration values (image tag, replicas, etc.)
    templates/       ← YAML files with {{ }} placeholders (like a form letter)
          └── deployment.yaml  ← "kind: Deployment" with {{ .Values.replicaCount }}
          └── service.yaml     ← "kind: Service" with {{ .Values.service.port }}

Helm combines them:
    helm install my-release ./my-chart
    ↓
Helm fills in the templates with your values (like running mail-merge)
    ↓
Final Kubernetes YAML is applied to the cluster (like sending the personalized letters)
```

### What Is Kustomize?

Kustomize takes a different approach from Helm. Instead of filling in blanks, it uses **YAML patching and overlays**. You write plain YAML with no placeholders, then apply patches that override specific fields per environment.

Here are the key pieces:

| Concept | What It Is |
|---------|-----------|
| **Base** | A plain Kubernetes YAML file — fully valid as-is, no placeholders |
| **Overlay** | A patch that modifies the base for a specific environment |
| **Kustomization** | A file listing which bases and overlays to combine |

Unlike Helm, Kustomize has no `{{ }}` directives, no `if` statements, no loops — just pure YAML.

> **Metaphor:** Kustomize is like a set of transparent overlays on a blueprint. The base is a complete architectural drawing. For the dev version, you lay a transparency on top that changes one wall. For prod, a different transparency changes another. You never redraw the original.

```
You write:
    base/
      kustomization.yaml   ← lists resources to include
      deployment.yaml       ← plain YAML, hardcoded values
    overlays/
      dev/
        kustomization.yaml  ← patches replicaCount to 1
        patch.yaml           ← changes image tag
      prod/
        kustomization.yaml  ← patches replicaCount to 5

Kustomize renders:
    kustomize build overlays/dev
    ↓
Original YAML + patches merged together
    ↓
Final Kubernetes YAML (no placeholders anywhere)
```

### Side-by-Side Comparison

| Aspect | Helm | Kustomize |
|--------|------|-----------|
| **What it is** | Templating engine + package manager | YAML patching tool |
| **Syntax** | Go templates `{{ .Values.replicaCount }}` | Plain YAML + strategic merge patches |
| **Parameterization** | Via `values.yaml` files or `--set` flags | Via overlays and patches |
| **Logic in templates** | ✅ `if/else`, `range` loops, function calls | ❌ No logic — pure declarative merging |
| **Package management** | ✅ Chart repositories, versioning, dependency resolution | ❌ No built-in package management |
| **Learning curve** | Moderate — you must learn Go template syntax | Low — it's just YAML |
| **Reusable library** | ✅ Library charts (`type: library`) with named templates | ❌ No library concept — you reference bases |
| **Versioning** | Charts have semantic versions; lock files (`Chart.lock`) | No built-in versioning |
| **Dry-run / template** | `helm template` — see rendered output without installing | `kustomize build` — see final YAML |
| **Lifecycle hooks** | ✅ Pre/post install/upgrade hooks | ❌ No hook system |
| **Best for** | Complex apps, packaged software, multi-team orgs | Simple overlays, env-specific patches, no-templating preference |

### A Concrete Example

**Requirement:** Deploy an Nginx server with 1 replica in dev, 3 in prod, with a configurable image tag.

**Helm approach — use a template with blanks:**

```yaml
# templates/deployment.yaml
apiVersion: apps/v1
kind: Deployment
spec:
  replicas: {{ .Values.replicaCount }}  ← fill in: how many restaurants?
  template:
    spec:
      containers:
        - image: "{{ .Values.image.registry }}/{{ .Values.image.path }}:{{ .Values.image.tag }}"
                                          ← fill in: which menu version?
```

Then each location gets a one-page info sheet with just the numbers:

```yaml
# dev-values.yaml              # prod-values.yaml
replicaCount: 1                replicaCount: 3
image:                         image:
  tag: "latest"                   tag: "1.2.0"
```

**Kustomize approach — use a base with patches on top:**

```yaml
# base/deployment.yaml  ← hardcoded: replicas: 1, image: nginx:latest
```

Then for the flagship restaurant, you write sticky notes that override specific parts:

```yaml
# overlays/prod/patch.yaml
apiVersion: apps/v1
kind: Deployment
spec:
  replicas: 3
  template:
    spec:
      containers:
        - name: nginx
          image: nginx:1.2.0
```

Both achieve the same result. The difference is **philosophy**: Helm uses a template with blanks; Kustomize uses a base copy with patches on top.

---

## 3. Why Helm Charts Won for This Project

This project chose Helm for three main reasons:

### Reason 1: Reusable Library Charts

The project has a dozen+ application teams and an infrastructure team. They all need the same basic Kubernetes resources (Deployments, Services, HPAs, ConfigMaps). 

With Helm, we created one **library chart** (`library-chart`) that contains all the standard templates. Every team's chart depends on it. When security requires a new label, we change **one file** in the library and every app gets it after their next upgrade.

With Kustomize, you'd need to maintain separate base directories or use remote bases — there's no equivalent of a `type: library` chart that can contain reusable named templates.

### Reason 2: Complex Logic and Conditions

Some of our charts need logic that Kustomize can't express:

```yaml
{{- if .Values.blueGreen.enabled }}
apiVersion: argoproj.io/v1alpha1
kind: Rollout       # ← Argo Rollout instead of Deployment
{{- else }}
apiVersion: apps/v1
kind: Deployment
{{- end }}
```

This `if/else` — choosing a completely different resource kind based on a value — is impossible in Kustomize (which can only patch existing fields, not switch resource types).

### Reason 3: Package Management and Versioning

Helm charts are versioned (every chart has a `version:` field), can be stored in repositories (like Artifactory), and support dependency resolution with lock files. This means:

- The infra team publishes `app-deployment:v0.5.1` to the chart repository
- App teams declare `version: ">=0.1.0"` in their `Chart.yaml`
- Helm resolves the right version, downloads it, and caches the exact version in `Chart.lock`
- Rollbacks are trivial: `helm rollback my-release 2`

Kustomize has no equivalent of versioned packages or rollback. You rely on git tags and git revert.

### When You Would Choose Kustomize Instead

Kustomize shines when:

- You want **no templating** — pure YAML is easier for some teams to audit
- You have **simple overlays** — just different replica counts or image tags per environment
- You're already using `kubectl` and don't want to install additional tooling
- Your deployments are **stateless** and don't need lifecycle hooks or dependency ordering

---

## 4. The Problem: Duplicated Templates

Now that you understand why we chose Helm, let's look at the specific problem this project solves.

Without a library chart, every application chart would need to copy-paste the same Deployment, Service, ConfigMap, and HPA templates. This leads to:

- **Inconsistencies** — different apps have slightly different label formats
- **Maintenance burden** — updating one template means touching every chart
- **Bug propagation** — a fix in one chart rarely gets backported to others

The solution is **library charts** — the topic of this tutorial.

Helm solves this with two mechanisms:

| Mechanism | Description |
|-----------|-------------|
| **Named templates** (`define`/`include`) | Templates stored in `_*.tpl` files, callable by name |
| **Sub-charts / dependencies** | One chart can depend on another, inheriting its templates |

---

## 5. Solution: Library Charts

A **library chart** is a Helm chart of `type: library` that contains only reusable template definitions — no deployable Kubernetes resources. It cannot be installed via `helm install`; it exists solely to be consumed by other charts.

> **Metaphor:** A library chart is a shared cookbook. You can't eat a cookbook (install it directly), but every kitchen follows its recipes (consumes its templates). The cookbook ensures all meals come out consistent.

### Structure of a Library Chart

```
library-chart/
├── Chart.yaml          # type: library
├── templates/
│   ├── _helpers.tpl                  # Label/name helper functions
│   ├── _deployment.tpl               # Deployment template definition
│   ├── _configmap.tpl                # ConfigMap template definition
│   ├── _hpa.tpl                      # HPA template definition
│   ├── _secret.tpl                   # Secret template definition
│   ├── _pvc.tpl                      # PVC template definition
│   ├── _serviceaccount.tpl           # ServiceAccount template definition
│   ├── _servicemesh.tpl              # Service Mesh orchestration
│   ├── _job.tpl                      # Job template definition
│   ├── service-mesh/
│   │   ├── _virtualservice.tpl       # Istio VirtualService
│   │   ├── _destinationrule.tpl      # Istio DestinationRule
│   │   └── _serviceentry.tpl         # Istio ServiceEntry
│   └── NOTES.txt
```

Key rules for `.tpl` files:
- File names start with `_` (underscore) — think of this as a "staff only" sign. Helm walks past these files when rendering the final output, but other templates can still call them by name.
- Use `{{- define "chart-name.templateName" -}} ... {{- end }}` to define the template — like writing a recipe and giving it a name ("Grandma's Chocolate Cake")
- Use `{{ include "chart-name.templateName" . }}` to call it from other templates — like saying "make Grandma's Chocolate Cake" instead of reciting the entire recipe

---

## 6. Our Library Chart: `library-chart`

Located at `helm-charts/library-chart/`, its `Chart.yaml` declares:

```yaml
apiVersion: v2
name: library-chart
description: Helm chart for reusable functions/templates
type: library
version: 0.4.1
```

Because `type: library`, this chart:
- Cannot be installed via `helm install`
- Has no `values.yaml` (all values come from the consumer chart)
- Is pulled in as a dependency of an application chart

---

## 7. Helpers: The `_helpers.tpl` Foundation

The `_helpers.tpl` file (`helm-charts/library-chart/templates/_helpers.tpl`) defines standard naming conventions and label formats used by every consumer chart. It ensures all Kubernetes resources share a consistent structure.

**Why this matters:** Without centralized helpers, each team might label pods differently — `app: my-app`, `name: my-app`, `application: my-app`. Monitoring queries like `oc get pods -l app=my-app` would only find some of them. The helpers guarantee every resource carries the same label conventions.

> **Metaphor:** Think of `_helpers.tpl` as an employee handbook. It doesn't do the work itself, but it sets the rules for how everyone writes their names, formats documents, and labels their output.

### `library-chart.name`

```yaml
{{- define "library-chart.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}
```

Returns the chart name (e.g., `todo-api`), or `nameOverride` if set. It also enforces the **63-character limit** — Kubernetes resource names can't be longer than 63 characters (a DNS naming rule). If the name exceeds this, Helm truncates it and removes trailing dashes.

### `library-chart.fullname`

```yaml
{{- define "library-chart.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}
```

Combines the **release name** (what you passed to `helm install`) with the **chart name** to create a unique, deployment-scoped identifier. If the release name already contains the chart name, it uses the release name alone to avoid duplication.

**Example:** `helm install prod-todo ./todo-api` → the release name is `prod-todo` and the chart name is `todo-api`. Since `prod-todo` doesn't contain `todo-api`, the result is `prod-todo-todo-api`.

### `library-chart.labels` and `library-chart.selectorLabels`

These helpers generate standardized Kubernetes labels — every resource gets the same format so monitoring, logging, and selectors work consistently across all charts.

The `labels` helper produces the full set:

```yaml
{{- define "library-chart.labels" -}}
helm.sh/chart: {{ include "library-chart.chart" . }}
{{ include "library-chart.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app: {{ .Release.Name }}
{{- end }}

{{- define "library-chart.selectorLabels" -}}
app.kubernetes.io/name: {{ include "library-chart.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
```

These produce consistent labels on every resource:

```yaml
helm.sh/chart: my-chart-1.0.0
app.kubernetes.io/name: my-chart
app.kubernetes.io/instance: my-release
app.kubernetes.io/version: "1.16.0"
app.kubernetes.io/managed-by: Helm
app: my-release
```

### `library-chart.serviceAccountName`

Returns the name of the ServiceAccount that the pod will use. If the chart is configured to create a new ServiceAccount, it generates the name. If a pre-existing account should be used, it returns the specified name.

### Other helpers

- **`library-chart.chart`** — Returns `"<chart-name>-<chart-version>"` for identifying which chart version created a resource.
- **`library-chart.statefulset.defaultValues`** — Auto-sets `statefulSet.enabled: false` if not provided, preventing template errors when the value is missing.

---

## 8. Reusable Templates in `_*.tpl` Files

Each `_*.tpl` file defines one or more named templates — reusable blocks that render complete Kubernetes resources. They all follow the same pattern:

1. Accept `.` (the root context — everything Helm knows about your chart)
2. Read `Values` from the consumer chart to decide what to create
3. Output valid Kubernetes YAML, using `{{ include }}` to reference sub-templates from `_helpers.tpl`

> **Metaphor:** Think of these templates as cookie cutters. The `_deployment.tpl` is a Deployment-shaped cutter; `_configmap.tpl` is a ConfigMap-shaped one. The dough (YAML structure) is the same base, while the icing (values) changes per batch. You get a consistent shape every time.

### Example: `_deployment.tpl`

This single template handles **three different resource types** depending on your values, plus service mesh sidecar injection:

File: `helm-charts/library-chart/templates/_deployment.tpl`

```yaml
{{- define "library-chart.createDeployment" -}}
...
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ .Release.Name }}
  labels:
    {{- include "library-chart.labels" . | nindent 4 }}
spec:
  replicas: {{ .Values.replicaCount }}
  ...
{{- end }}
```

This single template handles:
- Standard Deployments
- Blue/Green Rollouts (via Argo Rollouts when `blueGreen.enabled: true`)
- StatefulSets (when `statefulSet.enabled: true`)
- Service Mesh sidecar injection annotation

### Example: Service Mesh Templates

The `library-chart` provides a three-tier Istio integration:

| Template | Resource | Condition |
|----------|----------|-----------|
| `library-chart.enableServiceMesh` | Orchestrator — calls the below | `serviceMesh.enabled` |
| `library-chart.createVirtualService` | `VirtualService` | `routeHost` is set on the service |
| `library-chart.createDestinationRule` | `DestinationRule` | Service is external (`isExternal: true`) |
| `library-chart.createServiceEntry` | `ServiceEntry` | Service is external (`isExternal: true`) |

This is called from the consumer chart via:

```yaml
{{ include "library-chart.enableServiceMesh" (dict "root" . "serviceMesh" .Values.serviceMesh) }}
```

### Other Templates

| Template File | Template Name | Resource Created |
|--------------|---------------|-----------------|
| `_configmap.tpl` | `library-chart.createConfigmaps` | ConfigMap per item in `Values.configmaps` |
| `_hpa.tpl` | `library-chart.createHPA` | HorizontalPodAutoscaler |
| `_secret.tpl` | `library-chart.createSecret` | Secret |
| `_pvc.tpl` | `library-chart.createPVC` | PersistentVolumeClaim |
| `_serviceaccount.tpl` | `library-chart.createServiceAccount` | ServiceAccount |
| `_job.tpl` | `library-chart.createJob` | Job |

---

## 9. Application Chart: `app-deployment`

The `app-deployment` chart (`helm-charts/app-deployment/`) is an **application chart** — a deployable chart that wraps the library's templates with thin delegation files and adds its own extras. It:

1. **Declares `library-chart` as a dependency** in its `Chart.yaml`
2. **Uses thin template files** that pass through to the library — `deployment.yaml` is literally one line: `{{ include "library-chart.createDeployment" . }}`
3. **Adds its own templates** for resources the library doesn't cover (OpenShift Routes, ExternalSecrets, app config)

### Dependency Declaration

In `helm-charts/app-deployment/Chart.yaml`:

```yaml
apiVersion: v2
name: app-deployment
type: application
version: 0.5.1
dependencies:
  - name: library-chart
    version: 0.4.x
    repository: "file://../library-chart"
```

### Thin Template Files

The templates in `app-deployment/templates/` are minimal because they delegate to the library:

**`deployment.yaml`:**
```yaml
{{- include "library-chart.createDeployment" . }}
```

**`servicemesh.yaml`:**
```yaml
{{- if (.Values.serviceMesh).enabled -}}
{{ include "library-chart.enableServiceMesh" (dict "root" . "serviceMesh" .Values.serviceMesh) }}
{{- else -}}
{{ include "library-chart.disableServiceMesh" (dict "root" .) }}
{{- end }}
```

**`hpa.yaml`:**
```yaml
{{- if (.Values.autoscaling).enabled -}}
{{ include "library-chart.createHPA" . }}
{{- end }}
```

**`configmap.yaml`:**
```yaml
{{- if .Values.configmaps -}}
{{- include "library-chart.createConfigmaps" . }}
{{- end }}
```

**`service.yaml`:**
```yaml
apiVersion: v1
kind: Service
metadata:
  name: {{ .Release.Name }}
  labels:
    {{- include "library-chart.labels" . | nindent 4 }}
spec:
  ...
```

This pattern means:
- The `app-deployment` chart focuses on **what** resources to create
- The `library-chart` handles **how** those resources are structured
- Updates to resource structure happen in one place (the library)

**Real-world benefit:** When the security team requires a new label on all pods, you edit `_helpers.tpl` in the library. Every chart that depends on `app-deployment` gets the new label automatically — no changes needed to 20+ application Helm charts.

### Extra Templates Beyond the Library

The `app-deployment` chart adds functionality not covered by the library:

| Template | Purpose |
|----------|---------|
| `route.yaml` | OpenShift Route (optional, gated by `route.enabled`) |
| `externalsecret.yaml` | ExternalSecret for app secrets and config |
| `appconfig.yaml` | ConfigMap for app configuration YAML |
| `serviceaccount.yaml` | ServiceAccount creation |

---

## 10. Multi-Layer Dependencies

Helm charts can form dependency trees. In this project, every application chart depends on `library-chart` either directly or transitively:

```
app-deployment (v0.5.1)
  └── depends on ──> library-chart (v0.4.x)

app-servicemesh (v0.2.0)
  └── depends on ──> library-chart (v0.4.x)

sm-ingress (v0.1.3)
  └── depends on ──> library-chart (v0.3.x)

argo-applications (v0.1.1)
  └── depends on ──> library-chart (v0.3.x)
```

When an umbrella chart depends on `app-deployment`, Helm resolves the full tree automatically — you don't need to declare `library-chart` in your umbrella chart because `app-deployment` already declares it. This is called **transitive dependency resolution**:

```
umbrella-chart (your app)
  └── app-deployment (v0.5.1)
        └── library-chart (v0.4.x)
```

> **Metaphor:** Chart dependencies are like Russian nesting dolls. Open the largest doll (your umbrella chart), and inside is a smaller one (`app-deployment`). Inside that is the smallest (`library-chart`). Helm opens them all for you.

### Version Constraint Syntax

When declaring a dependency, you specify acceptable versions:

| Syntax | Meaning | Example Matches |
|--------|---------|-----------------|
| `0.1.x` | Any 0.1.z version | `0.1.0`, `0.1.3` — but NOT `0.2.0` |
| `>=0.1.0` | Any version >= 0.1.0 | `0.1.0`, `0.5.1`, `1.0.0` |
| `0.4.x` | Any 0.4.z version | `0.4.0`, `0.4.1` — but NOT `0.5.0` |
| `">=0.1.0"` | Quoted to avoid YAML interpretation | Use quotes when value starts with `>` (YAML otherwise interprets it as a key) |

---

## 11. Using `file://` Dependencies for Local Development

When developing locally, use `file://` paths instead of remote repositories. This lets you iterate on charts without publishing them.

### Path Resolution

The `file://` URL is resolved **relative to the dependent chart's directory**.

For a chart at `examples/appteam1/apps/todo-api/Chart.yaml` needing `helm-charts/app-deployment`:

```
todo-api/Chart.yaml
  └── repository: "file://../../../../helm-charts/app-deployment"
```

**Counting `../` levels** from `examples/appteam1/apps/todo-api/`:

| Step | Path |
|------|------|
| `..` | `examples/appteam1/apps/` |
| `../..` | `examples/appteam1/` |
| `../../..` | `examples/` |
| `../../../..` | (root of repo) |
| `../../../../helm-charts/app-deployment` | `helm-charts/app-deployment/` |

So the correct reference is `file://../../../../helm-charts/app-deployment`.

### Updating Dependencies

After changing a `Chart.yaml`, run:

```bash
helm dependency update examples/appteam1/apps/todo-api
```

This downloads charts into a local `charts/` directory. The `.tgz` files are typically gitignored.

---

## 12. Writing Your Own Umbrella Chart

An **umbrella chart** is an application chart whose only purpose is to depend on other charts and provide a unified values file. It has **no templates of its own** — just a `Chart.yaml` that declares dependencies and a `values.yaml` that passes values down to each sub-chart.

> **Metaphor:** An umbrella chart is a shopping list. The list doesn't cook anything — it just says "buy pasta, buy sauce, buy cheese." Each item is a dependency (another chart). When you run the list, Helm prepares everything together.

### Step 1: Create the structure

```bash
mkdir -p my-app/dev
```

### Step 2: Write `Chart.yaml`

```yaml
# my-app/dev/Chart.yaml
apiVersion: v2
name: my-app
description: A Helm chart for my-app
type: application
version: 0.1.0
dependencies:
  - name: app-deployment
    version: ">=0.1.0"
    repository: "file://../../../helm-charts/app-deployment"
```

### Step 3: Write `values.yaml`

Values in the umbrella chart are **namespaced under the dependency name** — like addressing mail to a specific department in a company:

```yaml
# my-app/dev/values.yaml
app-deployment:              ← This section feeds into the app-deployment sub-chart
  replicaCount: 2
  image:
    registry: quay.io/example-org
    path: my-app
    tag: "1.0.0"
  serviceMesh:
    enabled: true
```

**Why namespacing?** If your umbrella chart depends on two charts (e.g., `app-deployment` and `database`), each gets its own section. Helm knows that `app-deployment.replicaCount` goes to the app-deployment chart and `database.replicaCount` goes to the database chart.

### Step 4: Install

```bash
helm dependency update my-app/dev   # downloads the dependencies
helm install my-release my-app/dev  # deploys everything
```

That's it. The umbrella chart pulls in all dependencies, merges the values, and Helm creates every resource defined across the entire dependency tree.

---

## 13. Key Takeaways

1. **Library charts** (`type: library`) provide reusable template definitions that cannot be installed standalone
2. **Named templates** in `_*.tpl` files use `define`/`include` to share logic
3. **Application charts** declare library charts as dependencies and call their templates
4. **Thin template files** like `deployment.yaml` contain just `{{ include ... }}` — one line instead of 100+
5. **Multi-layer dependencies** resolve transitively (umbrella → app-deployment → library-chart)
6. **`file://` paths** enable local development without a chart repository
7. **Version constraints** like `>=0.1.0` accept a range; pin with `0.x.y` for strict versions
8. **Values are namespaced** — in an umbrella chart, set `app-deployment:` key to pass values to the sub-chart

---

## Hands-On Exercise

Try tracing the full chain for `examples/appteam1/apps/todo-api/`:

```bash
cat examples/appteam1/apps/todo-api/Chart.yaml
helm dependency update examples/appteam1/apps/todo-api
ls examples/appteam1/apps/todo-api/charts/
helm lint examples/appteam1/apps/todo-api
helm template todo-api examples/appteam1/apps/todo-api
```

---

You've just learned how Helm charts work — from a central library of reusable templates, through application charts that delegate to it, to umbrella charts that compose everything together. You can now build charts that any team can pick up and use without copying a single template.

In the next tutorial, you'll use these charts to install something much bigger than a single app: a full OpenShift Service Mesh. The mesh is the infrastructure layer that sits underneath every application, providing security, observability, and traffic management — all configured once by the infra team, consumed automatically by every app team.

**Next:** [Tutorial 2 — Installing OpenShift Service Mesh as a Day-2 Component](tutorial-2-openshift-service-mesh.md)
