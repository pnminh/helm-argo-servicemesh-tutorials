# Tutorial 4: Capstone — Deploying a Todo App Stack

**Level:** Beginner to Intermediate  
**Prerequisites:** [Tutorial 1](tutorial-1-helm-chart-reusability.md) (Helm charts), [Tutorial 2](tutorial-2-openshift-service-mesh.md) (Service mesh), [Tutorial 3](tutorial-3-argocd-appset-service-mesh.md) (ArgoCD/GitOps)  
**Goal:** Apply everything you've learned by deploying a three-tier todo application on OpenShift — first manually with Helm CLI to understand the mechanics, then automatically with ArgoCD + ApplicationSet to see how GitOps works in practice.

This is the capstone. Tutorial 1 taught you reusable Helm charts. Tutorial 2 gave you a service mesh. Tutorial 3 showed you how to automate it all with GitOps. Now you'll stand in the shoes of an app team and deploy a real stack on top of everything that's been built.

---

## Table of Contents

### Part 1 — Deploy with Helm CLI
1. [What We're Building](#1-what-were-building)
2. [How This Ties Together Tutorials 1–3](#2-how-this-ties-together-tutorials-13)
3. [Setup: Prepare Your Workspace](#3-setup-prepare-your-workspace)
4. [Exercise 1: Deploy the Database](#4-exercise-1-deploy-the-database)
5. [Exercise 2: Deploy the API](#5-exercise-2-deploy-the-api)
6. [Exercise 3: Deploy the UI](#6-exercise-3-deploy-the-ui)
7. [Exercise 4: Enable Service Mesh](#7-exercise-4-enable-service-mesh)
8. [Exercise 5: Simulate a Blue-Green Rollout](#8-exercise-5-simulate-a-blue-green-rollout)

### Part 2 — Switch to ArgoCD
9. [From Helm CLI to ArgoCD: Why Automate?](#9-from-helm-cli-to-argocd-why-automate)
10. [Exercise 6: Deploy Service Mesh via ArgoCD](#10-exercise-6-deploy-service-mesh-via-argocd)
11. [Exercise 7: Understand the AppTeam1 ApplicationSet](#11-exercise-7-understand-the-appteam1-applicationset)
12. [Exercise 8: Understand the `todo-stack` ApplicationSet](#12-exercise-8-understand-the-todo-stack-applicationset)
13. [Exercise 9: Verify Paths and Deploy via ArgoCD](#13-exercise-9-verify-paths-and-deploy-via-argocd)
14. [Exercise 10: Bootstrap a New App](#14-exercise-10-bootstrap-a-new-app)
15. [What You Just Built](#15-what-you-just-built)

---

## 1. What We're Building

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   todo-ui   │────▶│   todo-api  │────▶│   todo-db   │
│  (React)    │     │  (Quarkus)  │     │ (PostgreSQL)│
│  port 8080  │     │  port 8080  │     │  port 5432  │
└─────────────┘     └─────────────┘     └─────────────┘
       │                   │
       │                   │
       └───────────────────┘
               │
               ▼
       Service Mesh (Istio)
    - Sidecar injection
    - mTLS between services
    - Tracing via Tempo
    - Authorization via IAM Auth Controller
```

Three services, each deployed as a separate Helm umbrella chart that depends on the `app-deployment` and `library-chart` charts you studied in Tutorial 1. The `api` and `ui` will join the service mesh you set up in Tutorial 2. The whole thing is structured for ArgoCD deployment as covered in Tutorial 3.

---

## 2. How This Ties Together Tutorials 1–3

| Concept from... | How you'll apply it here |
|---|---|
| **Tutorial 1: Library charts** | Each app (`todo-db`, `todo-api`, `todo-ui`) is an umbrella chart that declares `app-deployment` as a dependency. You write a `values.yaml` — the library handles the Deployment template. |
| **Tutorial 1: `file://` deps** | All three apps use `file://../../../../helm-charts/app-deployment` to reference local charts. |
| **Tutorial 1: Multi-layer deps** | `todo-api` → `app-deployment` → `library-chart`. Declare one, Helm resolves the rest. |
| **Tutorial 2: Service mesh** | Toggle `serviceMesh.enabled: true` to inject sidecars and create VirtualServices. The mesh you installed in Tutorial 2 does the rest. |
| **Tutorial 2: External auth** | The mesh gateway's `AuthorizationPolicy` protects the UI route through the IAM Auth Controller. |
| **Tutorial 3: ArgoCD apps** | Each component is structured as a standalone Helm chart in a dedicated directory — ready to be picked up by an ArgoCD Application. |
| **Tutorial 3: Sync waves** | In Part 2, you'll create a `todo-stack` ApplicationSet that deploys DB → API → UI in order using sync waves. |

---

## 3. Setup: Prepare Your Workspace

Before starting, make sure the service mesh from Tutorial 2 is installed. Verify:

```bash
oc get csv -n openshift-operators | grep -E "servicemesh|kiali|tempo"
oc get smcp -n istio-system basic -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}'
oc new-project todo-dev
```

If you're running locally and haven't pushed charts to a remote repo, verify the `file://` paths in each app's `Chart.yaml`:

```bash
grep 'file://' examples/appteam1/apps/todo-api/Chart.yaml
grep 'file://' examples/appteam1/apps/todo-db/Chart.yaml
grep 'file://' examples/appteam1/apps/todo-ui/Chart.yaml
```

Expected output — each file references `file://../../../../helm-charts/...`:

```
    repository: "file://../../../../helm-charts/app-deployment"
    repository: "file://../../../../helm-charts/library-chart"
```

---

### Part 1 — Deploy with Helm CLI

In this part, you'll deploy each component manually using `helm install`. This gives you a hands-on feel for what happens under the hood. In Part 2, you'll hand these same charts to ArgoCD and watch it manage everything automatically.

---

## 4. Exercise 1: Deploy the Database

**Goal:** Deploy PostgreSQL as a plain Kubernetes Deployment — no service mesh, no external route.

```bash
# Read the values
cat examples/appteam1/apps/todo-db/values.yaml

# Deploy
helm dependency update examples/appteam1/apps/todo-db
helm upgrade --install todo-db examples/appteam1/apps/todo-db \
  --namespace todo-dev --create-namespace

# Verify
oc get pods -n todo-dev -l app=todo-db
oc get svc -n todo-dev todo-db
```

Pay attention to `route.enabled: false`, `livenessProbe.tcpSocket.port: 5432`, and the absence of `serviceMesh` — the database stays out of the mesh.

**Check your understanding:** What happens when `helm dependency update` runs? Which charts does it download and why? (Hint: revisit Tutorial 1's section on multi-layer dependencies.)

---

## 5. Exercise 2: Deploy the API

**Goal:** Deploy a Quarkus Java API that connects to the database via Kubernetes service DNS.

```bash
# Read the values
cat examples/appteam1/apps/todo-api/values.yaml

# Deploy
helm dependency update examples/appteam1/apps/todo-api
helm upgrade --install todo-api examples/appteam1/apps/todo-api --namespace todo-dev

# Verify
oc get pods -n todo-dev -l app=todo-api
oc logs -n todo-dev -l app=todo-api --tail=20
```

Notice `quarkus.datasource.jdbc.url` points to `jdbc:postgresql://todo-db:5432/todo-db` — the service DNS name of the database you just deployed.

**Check your understanding:** The `todo-api/values.yaml` doesn't declare `library-chart` — yet `helm dependency update` still fetches it. Why?

---

## 6. Exercise 3: Deploy the UI

**Goal:** Deploy a React frontend with blue-green deployment enabled.

```bash
# Read the values
cat examples/appteam1/apps/todo-ui/values.yaml

# Deploy
helm dependency update examples/appteam1/apps/todo-ui
helm upgrade --install todo-ui examples/appteam1/apps/todo-ui --namespace todo-dev

# Verify
oc get pods -n todo-dev -l app=todo-ui
oc get rollouts -n todo-dev
```

Notice you get a `Rollout` resource, not a `Deployment`. When `blueGreen.enabled: true`, the library chart's `_deployment.tpl` renders an Argo Rollout — you studied this template in Tutorial 1.

---

## 7. Exercise 4: Enable Service Mesh

**Goal:** Add the API and UI to the service mesh with a single values toggle.

```bash
# Label the namespace (matches the SMMR selector from Tutorial 2)
oc label namespace todo-dev istio-injection=enabled --overwrite

# Enable mesh on the API
mkdir -p examples/appteam1/apps/todo-api/environments/dev
cat > examples/appteam1/apps/todo-api/environments/dev/values.yaml << 'EOF'
app-deployment:
  serviceMesh:
    enabled: true
    service:
      port: 8080
EOF
helm upgrade --install todo-api examples/appteam1/apps/todo-api \
  -n todo-dev -f examples/appteam1/apps/todo-api/environments/dev/values.yaml

# Enable mesh on the UI with a public route
mkdir -p examples/appteam1/apps/todo-ui/environments/dev
cat > examples/appteam1/apps/todo-ui/environments/dev/values.yaml << 'EOF'
app-deployment:
  route:
    enabled: true
    host: todo-ui.apps.dev.k8s.example-org.com
    targetPort: 8080
  serviceMesh:
    enabled: true
    service:
      port: 8080
      routeHost: todo-ui.mesh.apps.dev.k8s.example-org.com
EOF
helm upgrade --install todo-ui examples/appteam1/apps/todo-ui \
  -n todo-dev -f examples/appteam1/apps/todo-ui/environments/dev/values.yaml

# Verify sidecars
oc get pods -n todo-dev -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[*].name}{"\n"}{end}'
```

Expected — each pod should now have two containers:
```
todo-api-xxx    todo-api istio-proxy
todo-ui-xxx     todo-ui istio-proxy
todo-db-xxx     todo-db              ← no sidecar
```

**Check your understanding:** Trace the request flow. A user hits `todo-ui.mesh.apps.dev.k8s.example-org.com` → the mesh gateway → the VirtualService → the UI sidecar → the app container. Which `_*.tpl` file in `library-chart` created the VirtualService?

---

## 8. Exercise 5: Simulate a Blue-Green Rollout

**Goal:** See the blue-green Rollout in action — deploy a new version, watch it come up alongside the old one, then promote it.

```bash
# Check current state
oc get rollouts -n todo-dev -o wide
oc get svc -n todo-dev | grep todo-ui

# Trigger a new version
helm upgrade --install todo-ui examples/appteam1/apps/todo-ui \
  -n todo-dev --set app-deployment.image.tag="main-newversion"

# Watch the rollout (green pods come up alongside blue)
oc get rollouts -n todo-dev -w

# Promote to active
oc argo rollouts promote todo-ui -n todo-dev
```

After promotion, the active service switches to the new version and old replicas scale down.

**Check your understanding:** With `autoPromotionEnabled: false`, manual promotion is required. Where in `_deployment.tpl` is this decision made?

---

### Part 2 — Switch to ArgoCD

---

## 9. From Helm CLI to ArgoCD: Why Automate?

So far, you've deployed everything manually with `helm install`. That works for learning and development — one person, one cluster, one terminal.

But what happens when you have three clusters? Or when you need to ensure that what's running right now matches what's in git? Or when you want a teammate to deploy the same stack without asking you for the exact `helm` command? That's where ArgoCD takes over.

The key insight: **ArgoCD uses the exact same Helm charts you just deployed.** It doesn't need new templates, new repos, or new processes. It reads your `Chart.yaml`, finds your `values.yaml`, runs `helm template` under the hood, and applies the result. The only difference is *who clicks the button* — instead of you running `helm install`, ArgoCD watches git and does it for you.

In this part, you'll:
1. Deploy the service mesh via the `day2-services` ApplicationSet — the same mesh from Tutorial 2, now GitOps-driven
2. Walk through the `appteam1-appset` ApplicationSet that auto-discovers apps per environment
3. Walk through the `todo-stack` ApplicationSet with sync-wave ordering
4. Verify paths and value files, then deploy everything via ArgoCD

---

## 10. Exercise 6: Deploy Service Mesh via ArgoCD

**Goal:** Deploy the same service mesh you set up manually in Tutorial 2 — but this time via the `day2-services` ApplicationSet, letting ArgoCD handle everything. You'll see how the infra team organizes cluster-specific deployments under `clusters/<name>/` and how the ApplicationSet discovers them automatically.

The ApplicationSet already exists at `examples/infra/appset/day2-services.yaml`. It uses a matrix generator that combines every cluster ArgoCD knows about with every `clusters/*` directory found in git.

### Step 1: Look at the directory structure

```bash
ls examples/infra/apps/service-mesh/clusters/
```

You should see `ocp-dev1/`. Inside it sits the umbrella chart with `Chart.yaml` and `values.yaml` — the same chart structure you've been using all along.

### Step 2: Read the ApplicationSet

```bash
cat examples/infra/appset/day2-services.yaml
```

### Step 3: How it works

The matrix generator combines two sources:
- **Clusters generator** — discovers every cluster registered with ArgoCD (provides `{{ .server }}` and `{{ .name }}`)
- **Git generator** — scans `examples/infra/apps/*/clusters/*` for any cluster directory under any service

For a cluster named `ocp-dev1`, and a git directory `examples/infra/apps/service-mesh/clusters/ocp-dev1`: the matrix generates one Application named `day2-service-mesh-ocp-dev1`. Add another cluster directory like `clusters/ocp-prod1/` and a second Application appears automatically.

The umbrella chart at that path depends on `argo-applications`, which generates 6 ArgoCD Applications with sync-wave ordering:

| Wave | Component | Namespace |
|------|-----------|-----------|
| 0 | `operators` | `openshift-operators` |
| 2 | `smcp` | `istio-system` |
| 3 | `tracing-system` | `tracing-system` |
| 3 | `kiali` | `istio-system` |
| 4 | `ingresses` | `mesh` |
| 4 | `sample-app` | `bookinfo` |

### Step 4: Apply and watch

```bash
oc apply -f examples/infra/appset/day2-services.yaml
oc get applications -n argocd | grep day2
```

Expected output:

```
day2-service-mesh-ocp-dev1    OutOfSync
```

### Step 5: Sync and watch the mesh come up

```bash
oc argocd app sync day2-service-mesh-ocp-dev1

# The umbrella deploys argo-applications, which creates 6 sub-apps
oc get applications -n argocd -o custom-columns=NAME:.metadata.name,SYNC:.status.sync.status,WAVE:.metadata.annotations.argocd\.argoproj\.io/sync-wave
```

Sub-apps deploy in wave order — operators first, then SMCP, then tracing and Kiali, then ingresses and sample-app.

**Check your understanding:** The umbrella chart at `clusters/ocp-dev1/` contains `argo-applications` which creates 6 more ArgoCD Applications inside the cluster. This is the two-level GitOps pattern: the outer ApplicationSet manages the umbrella, the umbrella manages the components. What would you need to do to deploy this same mesh to a second cluster named `ocp-prod1`?

---

## 11. Exercise 7: Understand the AppTeam1 ApplicationSet

**Goal:** Walk through the existing `appteam1-appset.yaml` and understand how it discovers apps, loads environment-specific values, and deploys per-environment.

The file already exists at `examples/appteam1/appset/appteam1-appset.yaml`. Let's read it:

```bash
cat examples/appteam1/appset/appteam1-appset.yaml
```

### How it works

The git directory generator scans `examples/appteam1/apps/*/environments/*`. The first `*` matches the app name (`todo-api`, `todo-db`, `todo-ui`), the second `*` matches the environment (`dev`, `stage`, `prod`). For every app × environment combination, it creates one ArgoCD Application.

| Field | Value | How it's generated |
|-------|-------|-------------------|
| **Name** | `todo-api-dev` | `{{ index .path.segments 3 }}` (app) + `-` + `.path.basenameNormalized` (env) |
| **Path** | `examples/appteam1/apps/todo-api` | `examples/appteam1/apps/{{ index .path.segments 3 }}` |
| **Values** | `values.yaml` + `environments/dev/values.yaml` | Base values merged with env-specific overrides |
| **Namespace** | `dev` | `.path.basenameNormalized` — all dev apps share one namespace |
| **ReleaseName** | `todo-api` | `{{ index .path.segments 3 }}` |

This generates 9 Applications (3 apps × 3 environments):

```
todo-api-dev        todo-api-stage         todo-api-prod
todo-db-dev         todo-db-stage          todo-db-prod
todo-ui-dev         todo-ui-stage          todo-ui-prod
```

### Step 1: Apply and verify

```bash
oc apply -f examples/appteam1/appset/appteam1-appset.yaml
oc get applications -n argocd | grep -E "todo-api.dev|todo-db.dev|todo-ui.dev"
```

Expected output — three dev Applications should appear:

```
todo-api-dev         OutOfSync
todo-db-dev          OutOfSync
todo-ui-dev          OutOfSync
```

They begin as `OutOfSync` because ArgoCD hasn't deployed them yet.

### Step 2: Sync one app and verify

```bash
# Sync the database for dev environment
oc argocd app sync todo-db-dev

# Watch it deploy
oc get pods -n dev -w
```

---

## 12. Exercise 8: Understand the `todo-stack` ApplicationSet

**Goal:** Understand the existing `todo-stack-apps.yaml` — an ApplicationSet that deploys all three components with sync-wave ordering, templated across dev/stage/prod environments.

This is where you apply the sync-wave pattern from Tutorial 3, §7. The file already exists at `examples/appteam1/appset/todo-stack-apps.yaml`.

### Step 1: Read the file

```bash
cat examples/appteam1/appset/todo-stack-apps.yaml
```

It uses a **matrix generator** combining a list of components (with sync waves) with a **git directory generator** that scans `todo-db/environments/*` to dynamically discover environments. Add a new `environments/qa` directory to any app, and the generator picks it up automatically — just like `appteam1-appset.yaml`. The matrix produces 3 × N Applications (3 components × however many environments exist).

### Step 2: How it works

| Application | Sync Wave | Path | Values loaded | Namespace |
|-------------|-----------|------|--------------|-----------|
| `todo-stack-todo-db-dev` | 0 | `examples/appteam1/apps/todo-db` | `values.yaml` + `environments/dev/values.yaml` | `todo-stack-dev` |
| `todo-stack-todo-db-stage` | 0 | same | `values.yaml` + `environments/stage/values.yaml` | `todo-stack-stage` |
| `todo-stack-todo-db-prod` | 0 | same | `values.yaml` + `environments/prod/values.yaml` | `todo-stack-prod` |
| *(same for todo-api at wave 1, todo-ui at wave 2)* | | | | |

The sync waves enforce order **within each environment**: database first (wave 0), API second (wave 1), UI third (wave 2).

### Step 3: Apply

```bash
oc apply -f examples/appteam1/appset/todo-stack-apps.yaml
oc get applications -n argocd | grep todo-stack
```

---

## 13. Exercise 9: Verify Paths and Deploy via ArgoCD

**Goal:** Before syncing, verify that every Application points to the correct paths and value files. Then sync and watch the stack come up in order.

### Step 1: Verify Application paths

```bash
# Check which git path each Application points to
oc get applications -n argocd -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.source.path}{"\n"}{end}' | grep -E "todo-(api|db|ui)-"
```

Expected — every Application should point to a path that actually exists in your repo:

```
todo-api-dev             examples/appteam1/apps/todo-api
todo-db-dev              examples/appteam1/apps/todo-db
todo-ui-dev              examples/appteam1/apps/todo-ui
todo-stack-todo-db-dev    examples/appteam1/apps/todo-db
todo-stack-todo-api-dev   examples/appteam1/apps/todo-api
todo-stack-todo-ui-dev    examples/appteam1/apps/todo-ui
```

### Step 2: Verify value files

```bash
# For each app, verify the values.yaml exists at that path
for app in todo-db todo-api todo-ui; do
  echo "=== $app ==="
  cat "examples/appteam1/apps/$app/values.yaml" | head -5
done
```

### Step 3: Sync the todo-stack and watch ordering

```bash
# Sync all todo-stack apps
oc argocd app sync todo-stack-todo-db-dev
oc argocd app sync todo-stack-todo-api-dev
oc argocd app sync todo-stack-todo-ui-dev

# Watch them deploy in order
oc get applications -n argocd -o custom-columns=NAME:.metadata.name,SYNC:.status.sync.status,WAVE:.metadata.annotations.argocd\.argoproj\.io/sync-wave | grep todo-stack

# Expected progression:
# 1. Wave 0 → todo-stack-todo-db-dev syncs first
# 2. Wave 1 → todo-stack-todo-api-dev syncs next
# 3. Wave 2 → todo-stack-todo-ui-dev syncs last
```

### Step 4: Verify in the cluster

```bash
oc get pods -n todo-stack-dev
oc get svc -n todo-stack-dev
```

**Check your understanding:** Why do the `todo-stack` apps all deploy to the same namespace (`todo-stack-dev`) while the `appteam1-appset` apps deploy per-environment (`dev`, `stage`, `prod`)? Which generator field controls the namespace?

---

## 14. Exercise 10: Bootstrap a New App

**Goal:** Use `create-new-app.sh` to scaffold a new application, then add it to both ApplicationSets.

```bash
# Scaffold
cd examples/appteam1
./scripts/create-new-app.sh my-new-service

# Fill in values
cat > apps/my-new-service/values.yaml << 'EOF'
app-deployment:
  image:
    registry: quay.io/example-org
    path: my-new-service
    pullPolicy: Always
    tag: "1.0.0"
  ports:
    - name: http
      containerPort: 3000
      protocol: TCP
  service:
    type: ClusterIP
    ports:
      - name: http
        protocol: TCP
        port: 3000
        targetPort: http
EOF

# Add environments
mkdir -p apps/my-new-service/environments/{dev,stage,prod}
echo "# Values file for my-new-service in dev" > apps/my-new-service/environments/dev/values.yaml

# The git generator scans */environments/* and auto-detects new apps
oc get applications -n argocd | grep my-new-service
```

Since the `appteam1-appset` ApplicationSet uses a git generator scanning `apps/*/environments/*`, the new directory is automatically detected once it has an `environments/` subdirectory. ArgoCD creates an Application for it without any changes to the ApplicationSet itself.

---

## 15. What You Just Built

### Part 1: Manual Helm deployment

| What | How | From tutorial |
|------|-----|---------------|
| Three umbrella charts (`todo-db`, `todo-api`, `todo-ui`) | `helm install` with `file://` deps | Tutorial 1 |
| `serviceMesh.enabled: true` toggle | Sidecar injection + VirtualService | Tutorial 2 |
| Blue-green rollout | Argo Rollout, manual promotion | Tutorial 1 |

### Part 2: ArgoCD automation

| What | How | From tutorial |
|------|-----|---------------|
| `day2-services` ApplicationSet | Matrix generator (clusters × git dirs) — deploys the full service mesh via GitOps | Tutorial 3 |
| `appteam1-appset` ApplicationSet | Git directory generator scanning `apps/*/environments/*` — auto-discovers apps and deploys per environment | Tutorial 3 |
| `todo-stack` ApplicationSet | Matrix generator (components list × git dirs) with sync-wave ordering (DB→API→UI) — deploys all three in one namespace per environment | Tutorial 3 |
| Path verification | Every Application points to a real directory with `Chart.yaml` + `values.yaml` | Tutorial 1 + 3 |
| New app auto-detection | `create-new-app.sh` creates a directory; the ApplicationSet picks it up automatically | Tutorial 3 |

---

You've now seen both sides of the coin: manual Helm CLI (good for learning and debugging) and automated ArgoCD (good for production). The charts are the same. The values are the same. The only difference is whether you or ArgoCD pushes them to the cluster.

**Previous:** [Tutorial 3 — ArgoCD and GitOps](tutorial-3-argocd-appset-service-mesh.md)
