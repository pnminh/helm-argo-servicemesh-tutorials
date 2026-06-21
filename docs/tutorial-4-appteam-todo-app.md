# Tutorial 4: Capstone — Deploying a Todo App Stack

**Level:** Beginner to Intermediate  
**Prerequisites:** [Tutorial 1](tutorial-1-helm-chart-reusability.md) (Helm charts), [Tutorial 2](tutorial-2-openshift-service-mesh.md) (Service mesh), [Tutorial 3](tutorial-3-argocd-appset-service-mesh.md) (ArgoCD/GitOps)  
**Goal:** Apply everything you've learned by deploying a three-tier todo application on OpenShift — with Helm umbrella charts, service mesh integration, and blue-green deployment — using the exact patterns and charts from `helm-charts/`.

> **Where you are in the journey:** This is the capstone. Tutorial 1 taught you reusable Helm charts. Tutorial 2 gave you a service mesh infrastructure. Tutorial 3 showed you how to automate it all with GitOps. Now you'll stand in the shoes of an app team and deploy a real application stack on top of everything that's been built.

---

## Table of Contents

1. [What We're Building](#1-what-were-building)
2. [How This Ties Together Tutorials 1–3](#2-how-this-ties-together-tutorials-13)
3. [Setup: Prepare Your Workspace](#3-setup-prepare-your-workspace)
4. [Exercise 1: Deploy the Database](#4-exercise-1-deploy-the-database)
5. [Exercise 2: Deploy the API](#5-exercise-2-deploy-the-api)
6. [Exercise 3: Deploy the UI](#6-exercise-3-deploy-the-ui)
7. [Exercise 4: Enable Service Mesh](#7-exercise-4-enable-service-mesh)
8. [Exercise 5: Add Blue-Green Deployment](#8-exercise-5-add-blue-green-deployment)
9. [Exercise 6: Environment Overrides](#9-exercise-6-environment-overrides)
10. [Exercise 7: Bootstrap a New App](#10-exercise-7-bootstrap-a-new-app)
11. [What You Just Built](#11-what-you-just-built)

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
| **Tutorial 3: Environment strategy** | Common `values.yaml` + environment-specific overrides in `environments/<env>/`. |

---

## 3. Setup: Prepare Your Workspace

Before starting, make sure the service mesh from Tutorial 2 is installed. Verify:

```bash
# Operators should be installed
oc get csv -n openshift-operators | grep -E "servicemesh|kiali|tempo"

# SMCP should be ready
oc get smcp -n istio-system basic -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}'

# The namespace where you'll deploy
oc new-project todo-dev
```

If you're running locally and haven't pushed charts to a remote repo, update each app's `Chart.yaml` to use `file://` paths. The files in the repo already have this configured:

```bash
# Verify the paths resolve (should show no errors)
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

## 4. Exercise 1: Deploy the Database

**Goal:** Deploy PostgreSQL as a plain Kubernetes Deployment — no service mesh, no external route.

### Step 1: Read the values

```bash
cat examples/appteam1/apps/todo-db/values.yaml
```

Notice how the values are namespaced under `app-deployment:` — this is because `todo-db` depends on the `app-deployment` chart, and Helm passes these values into it. The Deployment template in `library-chart` reads `Values.replicaCount`, `Values.image`, `Values.ports`, etc. directly from what you provide here.

Pay attention to:
- `route.enabled: false` — a database shouldn't be exposed to the internet
- `livenessProbe.tcpSocket.port: 5432` — PostgreSQL protocol check, not HTTP
- No `serviceMesh` section — the database stays out of the mesh

### Step 2: Resolve dependencies and deploy

```bash
helm dependency update examples/appteam1/apps/todo-db
helm upgrade --install todo-db examples/appteam1/apps/todo-db \
  --namespace todo-dev \
  --create-namespace
```

### Step 3: Verify

```bash
oc get pods -n todo-dev -l app=todo-db
oc get svc -n todo-dev todo-db
```

**Check your understanding:** What happens when `helm dependency update` runs? Which charts does it download and why? (Hint: revisit Tutorial 1's section on multi-layer dependencies.)

---

## 5. Exercise 2: Deploy the API

**Goal:** Deploy a Quarkus Java API that connects to the database.

### Step 1: Read the values

```bash
cat examples/appteam1/apps/todo-api/values.yaml
```

Key things to notice:
- `quarkus.datasource.jdbc.url` points to `jdbc:postgresql://todo-db:5432/todo-db` — this is the Kubernetes service DNS name for the database you just deployed
- Health probes use HTTP endpoints (`/q/health/live`, `/q/health/ready`) — standard Quarkus conventions
- No `serviceMesh` configuration yet — that comes in Exercise 4

### Step 2: Deploy

```bash
helm dependency update examples/appteam1/apps/todo-api
helm upgrade --install todo-api examples/appteam1/apps/todo-api \
  --namespace todo-dev
```

### Step 3: Verify

```bash
oc get pods -n todo-dev -l app=todo-api
oc logs -n todo-dev -l app=todo-api --tail=20
```

**Check your understanding:** The `todo-api/values.yaml` doesn't declare `library-chart` — yet `helm dependency update` still fetches it. Why? (Hint: transitive dependency resolution from Tutorial 1.)

---

## 6. Exercise 3: Deploy the UI

**Goal:** Deploy a React frontend with blue-green deployment enabled.

### Step 1: Read the values

```bash
cat examples/appteam1/apps/todo-ui/values.yaml
```

This file is the shortest of the three — it only sets the image and `blueGreen.enabled: true`. Everything else (ports, service type, probes) comes from `app-deployment` defaults.

### Step 2: Deploy

```bash
helm dependency update examples/appteam1/apps/todo-ui
helm upgrade --install todo-ui examples/appteam1/apps/todo-ui \
  --namespace todo-dev
```

### Step 3: Verify

```bash
oc get pods -n todo-dev -l app=todo-ui
oc get rollouts -n todo-dev
```

Notice you get a `Rollout` resource, not a `Deployment`. This is the blue-green pattern from Tutorial 1 — when `blueGreen.enabled: true`, the library chart's `_deployment.tpl` renders an Argo Rollout instead of a standard Deployment.

**Check your understanding:** Look at the Rollout spec. How does it reference the active and preview services? What does `autoPromotionEnabled: false` mean?

---

## 7. Exercise 4: Enable Service Mesh

**Goal:** Add the API and UI to the service mesh with a single values toggle.

### Step 1: Label the namespace

```bash
oc label namespace todo-dev istio-injection=enabled --overwrite
```

This label matches the `ServiceMeshMemberRoll` selector from Tutorial 2. The SMMR automatically adds the namespace to the mesh.

### Step 2: Enable mesh on the API

Create or edit the environment override file:

```bash
mkdir -p examples/appteam1/apps/todo-api/environments/dev
cat > examples/appteam1/apps/todo-api/environments/dev/values.yaml << 'EOF'
app-deployment:
  serviceMesh:
    enabled: true
    service:
      port: 8080
EOF
```

Then upgrade:

```bash
helm upgrade --install todo-api examples/appteam1/apps/todo-api \
  --namespace todo-dev \
  -f examples/appteam1/apps/todo-api/environments/dev/values.yaml
```

### Step 3: Enable mesh on the UI with a public route

```bash
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
  --namespace todo-dev \
  -f examples/appteam1/apps/todo-ui/environments/dev/values.yaml
```

### Step 4: Verify sidecar injection

```bash
oc get pods -n todo-dev -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[*].name}{"\n"}{end}'
```

Expected — each pod should now have two containers:

```
todo-api-xxx    todo-api istio-proxy
todo-ui-xxx     todo-ui istio-proxy
todo-db-xxx     todo-db              ← no sidecar (we never enabled mesh)
```

### Step 5: Check the VirtualService

```bash
oc get virtualservice -n todo-dev
```

**Check your understanding:** Trace the request flow. A user hits `todo-ui.mesh.apps.dev.k8s.example-org.com` → the mesh gateway → the VirtualService → the UI sidecar → the app container. Which tutorial covered how the VirtualService was created? Which `_*.tpl` file in `library-chart` handles this?

---

## 8. Exercise 5: Add Blue-Green Deployment

**Goal:** Understand how the blue-green Rollout works in practice.

The UI already has `blueGreen.enabled: true`. Let's simulate a new version deployment.

### Step 1: Check the current state

```bash
oc get rollouts -n todo-dev -o wide
oc get svc -n todo-dev | grep todo-ui
```

You should see two services:
- `todo-ui` — the active (live) service
- `todo-ui-preview` — the preview service for the next version

### Step 2: Trigger a new revision

```bash
# Simulate a new image version
helm upgrade --install todo-ui examples/appteam1/apps/todo-ui \
  --namespace todo-dev \
  --set app-deployment.image.tag="main-newversion"
```

### Step 3: Watch the rollout

```bash
oc get rollouts -n todo-dev -w
```

You'll see the green pods come up alongside the blue pods. The preview service routes traffic to the new version while the active service still serves the old one.

### Step 4: Promote if ready (manual promotion)

```bash
oc argo rollouts promote todo-ui -n todo-dev
```

After promotion, the active service switches to the new version, and the old replicas scale down.

**Check your understanding:** Blue-green deployment with `autoPromotionEnabled: false` requires manual promotion. Where would you set `autoPromotionEnabled: true` if you wanted automatic promotion? Where in the `_deployment.tpl` template is this decision made?

---

## 9. Exercise 6: Environment Overrides

**Goal:** Deploy the same app to multiple environments with different configurations.

The environment pattern from Tutorial 3 applies here: a common `values.yaml` + environment-specific overrides.

### Deploy to stage

```bash
oc new-project todo-stage
oc label namespace todo-stage istio-injection=enabled

# Stage gets a different image tag and hostname
mkdir -p examples/appteam1/apps/todo-db/environments/stage
cat > examples/appteam1/apps/todo-db/environments/stage/values.yaml << 'EOF'
app-deployment:
  image:
    tag: "stage-abc123"
EOF

helm upgrade --install todo-db examples/appteam1/apps/todo-db \
  --namespace todo-stage \
  -f examples/appteam1/apps/todo-db/environments/stage/values.yaml
```

### Deploy to prod

```bash
oc new-project todo-prod
oc label namespace todo-prod istio-injection=enabled

mkdir -p examples/appteam1/apps/todo-db/environments/prod
cat > examples/appteam1/apps/todo-db/environments/prod/values.yaml << 'EOF'
app-deployment:
  image:
    tag: "1.0.0"
EOF

helm upgrade --install todo-db examples/appteam1/apps/todo-db \
  --namespace todo-prod \
  -f examples/appteam1/apps/todo-db/environments/prod/values.yaml
```

### Verify all environments

```bash
oc get pods -n todo-dev -l app=todo-db
oc get pods -n todo-stage -l app=todo-db
oc get pods -n todo-prod -l app=todo-db
```

**Check your understanding:** Look at the values merging order from Tutorial 1. When you run `-f environments/prod/values.yaml`, which layers of values are combined, and in what order?

---

## 10. Exercise 7: Bootstrap a New App

**Goal:** Use `create-new-app.sh` to scaffold a new application, then fill in the values.

### Step 1: Run the script

```bash
cd examples/appteam1
./scripts/create-new-app.sh my-new-service
ls -la apps/my-new-service/
```

You should see:
```
apps/my-new-service/
├── Chart.yaml
└── values.yaml
```

### Step 2: Fill in the values

```bash
cat > apps/my-new-service/values.yaml << 'EOF'
# Values file for my-new-service
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
  livenessProbe:
    httpGet:
      path: /health
      port: http
    initialDelaySeconds: 10
  readinessProbe:
    httpGet:
      path: /ready
      port: http
    initialDelaySeconds: 5
EOF
```

### Step 3: Add environments

```bash
mkdir -p apps/my-new-service/environments/{dev,stage,prod}
echo "# Values file for my-new-service in dev" > apps/my-new-service/environments/dev/values.yaml
echo "# Values file for my-new-service in stage" > apps/my-new-service/environments/stage/values.yaml
echo "# Values file for my-new-service in prod" > apps/my-new-service/environments/prod/values.yaml
```

### Step 4: Deploy

```bash
helm dependency update apps/my-new-service
helm upgrade --install my-new-service apps/my-new-service --namespace todo-dev
oc get pods -n todo-dev -l app=my-new-service
```

**Check your understanding:** The script generates an umbrella chart with a single dependency. If you wanted the new app to also join the service mesh, where would you set `serviceMesh.enabled: true`? Would you add it to the common `values.yaml` or to `environments/dev/values.yaml`?

---

## 11. What You Just Built

| What | Which concept | From tutorial |
|------|--------------|---------------|
| Three umbrella charts (`todo-db`, `todo-api`, `todo-ui`) | Multi-layer Helm dependencies | Tutorial 1 |
| Each chart depends on `app-deployment` → `library-chart` | Transitive resolution | Tutorial 1 |
| `serviceMesh.enabled: true` toggles sidecar injection | Service mesh integration | Tutorial 2 |
| VirtualService created automatically for the UI's `routeHost` | `_servicemesh.tpl` + `_virtualservice.tpl` | Tutorial 1 + 2 |
| Blue-green deployment via `blueGreen.enabled: true` | Argo Rollout instead of Deployment | Tutorial 1 |
| Environment-specific overrides in `environments/<env>/` | GitOps-compatible structure | Tutorial 3 |
| `create-new-app.sh` for scaffolding | Standardized app bootstrapping | Tutorial 1 |

---

**You've reached the end of the tutorial series.** Here's a recap of what you built across all four chapters:

| Chapter | What you built | Who benefits |
|---------|---------------|-------------|
| Tutorial 1 | A reusable Helm chart library (`library-chart`) and application charts (`app-deployment`) | Platform team — write templates once, reuse everywhere |
| Tutorial 2 | A full OpenShift Service Mesh (operators, SMCP, Tempo, Kiali, gateways) | Infra team — security, observability, and traffic management as a shared layer |
| Tutorial 3 | An ArgoCD ApplicationSet that deploys the mesh to multiple clusters with sync-wave ordering | Infra team — GitOps automation, single source of truth, disaster recovery |
| Tutorial 4 | A three-tier todo app stack (DB + API + UI) with service mesh and blue-green deployment | App teams — deploy apps without worrying about networking, security, or deployment strategies |

**The big picture:** The platform team writes reusable Helm charts. The infra team installs a service mesh and automates it with GitOps. App teams deploy their apps on top — with consistent security, observability, and deployment strategies — using a simple `values.yaml`. No app code changes needed.

**Previous:** [Tutorial 3 — ArgoCD ApplicationSet for Infra Team Service Mesh](tutorial-3-argocd-appset-service-mesh.md)
