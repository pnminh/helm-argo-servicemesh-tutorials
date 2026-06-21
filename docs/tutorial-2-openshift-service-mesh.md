# Tutorial 2: Installing OpenShift Service Mesh as a Day-2 Component

**Level:** Intermediate  
**Prerequisite:** [Tutorial 1 — Helm Chart Reusability](tutorial-1-helm-chart-reusability.md)  
**Goal:** Deploy a full OpenShift Service Mesh stack (operators, SMCP, telemetry, ingress gateways) using Helm charts from the `helm-charts/` folder.

Tutorial 1 gave you the toolbox: reusable Helm charts that let any team deploy apps consistently. Now you'll install the infrastructure layer that sits underneath those apps — the service mesh. This is where the infra team takes over, setting up security, observability, and traffic management so app teams don't have to think about it.

---

## Table of Contents

1. [Why Service Mesh? The Problem It Solves](#1-why-service-mesh-the-problem-it-solves)
2. [What a Service Mesh Actually Does](#2-what-a-service-mesh-actually-does)
3. [Architecture Overview](#3-architecture-overview)
4. [Service Mesh Component Charts](#4-service-mesh-component-charts)
5. [Step 1: Install Operators](#5-step-1-install-operators)
6. [Step 2: Deploy the Service Mesh Control Plane](#6-step-2-deploy-the-service-mesh-control-plane)
7. [Step 3: Enable Tracing with Tempo](#7-step-3-enable-tracing-with-tempo)
8. [Step 4: Configure Kiali](#8-step-4-configure-kiali)
9. [Step 5: Deploy Ingress Gateways](#9-step-5-deploy-ingress-gateways)
10. [Step 6: Configure External Authorization](#10-step-6-configure-external-authorization)
11. [Verifying the Installation](#11-verifying-the-installation)
12. [Key Takeaways](#12-key-takeaways)

---

## 1. Why Service Mesh? The Problem It Solves

### Before Service Mesh: The Microservice Networking Mess

Imagine you have five microservices — `api`, `auth`, `payments`, `notifications`, and `inventory`. Each talks to several others. On a basic Kubernetes cluster, here's what you have to manage:

**Communication is invisible.** When `api` calls `payments` and it fails, did the request even leave `api`? Did `payments` receive it but crash halfway through? Without tooling, you have no way to trace a request across service boundaries. You SSH into pods and grep log files.

**Security is manual.** To encrypt traffic between `api` and `payments`, you need to configure TLS in both applications. That means managing certificates, updating application code, and hoping every developer on every team does it the same way. In reality, some teams enable mTLS and others don't — so traffic is a mix of encrypted and plaintext, and nobody knows which is which.

**Traffic routing requires code changes.** Want to send 10% of users to a new version of `api` for canary testing? You write load-balancer rules or modify your application to check a header. Want to add a 3-second retry when `payments` is slow? You write retry logic into every caller. Every routing decision lives in application code, spread across multiple repos.

**Observability is an afterthought.** Adding metrics, tracing, and logging to each service is an app-by-app effort. Some services export Prometheus metrics. Some don't. Some log in JSON. Some don't. When a user reports a slow checkout flow, you spend 30 minutes correlating logs from 4 different services just to find where the delay is.

### The Root Cause

All of these problems come from one architectural reality: **in microservices, the network is the shared dependency between every service.** But Kubernetes itself only handles pod-to-pod connectivity (DNS, IP routing). It doesn't help with *how* traffic behaves, *whether* traffic is encrypted, or *what* happened during a request.

You end up reimplementing networking logic — retries, timeouts, circuit breakers, TLS, metrics, tracing — in every single service.

> **Metaphor:** Think of a busy hotel. Without a concierge, every guest has to find their own room, check if the restaurant is open, call a taxi, and arrange wake-up calls. With a concierge (the service mesh), guests just ask one person who handles everything transparently. The guests (your services) don't need to know how to call a taxi — they just focus on their own business.

---

## 2. What a Service Mesh Actually Does

A service mesh solves these problems by **moving networking logic out of your application code and into a dedicated infrastructure layer.** It does this using **sidecar proxies** — lightweight containers that run alongside every pod and intercept all network traffic.

### The Sidecar Proxy Model

```
┌─────────────────────────────────────────────────────┐
│                      Pod                             │
│                                                     │
│  ┌──────────┐         ┌──────────────────────────┐  │
│  │  Your App │ ──────▶│   Sidecar Proxy (Envoy)   │──┼──▶ Network
│  │ Container │         │  - mTLS                   │  │
│  │           │ ◀──────│  - Retries / Timeouts      │  │
│  │           │         │  - Metrics / Tracing       │  │
│  │           │         │  - Authorization           │  │
│  └──────────┘         └──────────────────────────┘  │
└─────────────────────────────────────────────────────┘
```

Your application code never changes. It sends requests to `http://payments:8080/charge` like normal. The sidecar proxy intercepts that request and adds everything else transparently.

### The Three Pillars

| Pillar | Before Service Mesh | After Service Mesh |
|--------|-------------------|-------------------|
| **Traffic Management** | Retries, timeouts, and canary routing coded into each app | Declared once as Istio rules; applies to all services |
| **Security** | TLS configured per-app, inconsistent across teams | mTLS enforced mesh-wide; every service-to-service call is encrypted automatically |
| **Observability** | Metrics and tracing added app-by-app if developers remember | Sidecar captures request metrics, trace spans, and access logs for every call — no app changes needed |

### A Concrete Before/After

**Before service mesh:** A request from `api` to `payments` uses plain HTTP. If `payments` times out, the error shows up in the `api` logs (if the developer logged it). No latency data, no trace, no retry.

**After service mesh:** The same request is intercepted by the sidecar, encrypted with mTLS, timed, traced, and metrics are recorded. If it times out, the sidecar retries (up to your configured limit). The trace shows exactly which service caused the delay. You didn't change a line of application code.

> **Why operators love this:** The infra team configures security, routing, and observability centrally. App teams focus on business logic. Nobody argues about which TLS library to use or where to send metrics.

---

## 3. Architecture Overview

The OpenShift Service Mesh (OSSM) deployment in this project follows a layered architecture:

```
┌──────────────────────────────────────────────────┐
│              Application Namespaces               │
│   (istio-injection=enabled, ServiceMeshMember)    │
├──────────────────────────────────────────────────┤
│              Ingress Gateways (mesh)              │
│   ┌──────────┐  ┌──────────┐  ┌────────────────┐ │
│   │  wwt-gw  │  │ tempo-gw │  │ bookinfo-gw    │ │
│   │ + Authz  │  │          │  │ + Authz        │ │
│   └──────────┘  └──────────┘  └────────────────┘ │
├──────────────────────────────────────────────────┤
│              Control Plane (istio-system)          │
│   ┌──────────┐  ┌───────┐  ┌───────────────────┐ │
│   │  istiod  │  │ Kiali │  │ Telemetry (Tempo)  │ │
│   └──────────┘  └───────┘  └───────────────────┘ │
├──────────────────────────────────────────────────┤
│              Operators (openshift-operators)       │
│   ┌──────────┐  ┌──────────────┐  ┌────────────┐ │
│   │ OSSM     │  │ Tempo        │  │ Kiali      │ │
│   └──────────┘  └──────────────┘  └────────────┘ │
└──────────────────────────────────────────────────┘
```

### Component Overview

| Component | Chart | Purpose |
|-----------|-------|---------|
| **Operators** | `k8s-operators` | Installs OSSM, Tempo, and Kiali operators via OLM subscriptions |
| **SMCP** | `sm-control-plane` | Deploys `ServiceMeshControlPlane` and `ServiceMeshMemberRoll` |
| **Tempo** | `tempo` | Distributed tracing backend (stores trace data) |
| **Kiali** | `kiali` | Service mesh visualization dashboard |
| **Ingress Gateways** | `sm-ingress` | Istio Gateways with TLS, routes, and authorization |
| **Mesh API Router** | `mesh-api-router` | Orchestrates VirtualServices for internal/external API routing |

---

## 4. Service Mesh Component Charts

### Operator Chart (`k8s-operators`)

File: `helm-charts/k8s-operators/Chart.yaml`

```yaml
name: k8s-operators
type: application
version: 0.1.0
```

This chart creates OLM `Subscription` resources. In `values.yaml`:

```yaml
# subscriptions:
#   - name: kiali-ossm
#     namespace: openshift-operators
#     source: redhat-operators
#     channel: stable
#   - name: servicemeshoperator
#     ...
#   - name: tempo-product
#     ...
```

### SMCP Chart (`sm-control-plane`)

File: `helm-charts/sm-control-plane/`

This chart creates three key resources:

1. **`ServiceMeshControlPlane`** — The Istio control plane configuration
2. **`ServiceMeshMemberRoll`** — Defines which namespaces join the mesh
3. **`Telemetry`** — Configures tracing and metrics providers

The SMCP configures an `extensionProviders` section that connects Tempo for tracing and the IAM Auth Controller for external authorization:

```yaml
meshConfig:
  extensionProviders:
    - name: prometheus
      prometheus: {}
    - name: tempo
      zipkin:
        port: 9411
        service: tempo-tempo-distributor.tracing-system.svc.cluster.local
    - name: "example-org-ext-authz-http"
      envoyExtAuthzHttp:
        service: "iam-auth-controller.iam-auth-controller.svc.cluster.local"
        port: 7010
```

### Tempo Chart (`tempo`)

File: `helm-charts/tempo/`

Tempo serves as the distributed tracing backend. It integrates with SMCP via the Zipkin protocol. The chart creates:

- A `TempoStack` CR (via the Tempo Operator)
- An `ExternalSecret` for Azure storage credentials
- A `VirtualService` for the query frontend

### Kiali Chart (`kiali`)

File: `helm-charts/kiali/`

Kiali provides visualization of the service mesh. It connects to Prometheus (user-workload monitoring) and Tempo:

```yaml
externalServices:
  prometheus:
    url: https://thanos-querier.openshift-monitoring.svc.cluster.local:9091
  tracing:
    inClusterUrl: http://tempo-tempo-query-frontend.tracing-system.svc.cluster.local:16685
```

### Ingress Gateway Chart (`sm-ingress`)

File: `helm-charts/sm-ingress/`

This chart creates Istio Gateways and supporting resources:

| Template | Resource | When |
|----------|----------|------|
| `gateway.yaml` | Istio `Gateway` | Always (iterates over `ingresses`) |
| `deployment.yaml` | Istio proxy `Deployment` | Always |
| `service.yaml` | `Service` for the gateway | Always |
| `routes.yaml` | OpenShift `Route` | When `routes` are defined on an ingress |
| `authorization-policy.yaml` | `AuthorizationPolicy` | When `gateway.authorization.enabled` |
| `ingress-secret.yaml` | `ExternalSecret` for TLS | When `gateway.tlsSecrets` are defined |
| `hpa.yaml` | `HorizontalPodAutoscaler` | When autoscaling is enabled |

---

## 5. Step 1: Install Operators

Operators are the foundation — everything else depends on them.

### Using the `k8s-operators` Chart

```bash
# From the repo root
helm dependency update helm-charts/k8s-operators
helm upgrade --install operators helm-charts/k8s-operators \
  --namespace openshift-operators \
  --create-namespace
```

### What Gets Installed

This creates OLM `Subscription` resources that install:

| Operator | Namespace | Channel |
|----------|-----------|---------|
| OpenShift Service Mesh (`servicemeshoperator`) | `openshift-operators` | `stable` |
| Kiali (`kiali-ossm`) | `openshift-operators` | `stable` |
| Tempo (`tempo-product`) | `openshift-operators` | `stable` |

### Verify Operator Installation

```bash
# Check that the operators are installed
oc get csv -n openshift-operators | grep -E "servicemesh|kiali|tempo"

# Wait for all operators to reach "Succeeded" phase
oc wait --for=condition=Ready pods --all -n openshift-operators --timeout=300s
```

**Expected output (after ~2-5 minutes):**
```
NAME                               DISPLAY                    VERSION   REPLACES   PHASE
servicemeshoperator.v2.5.0         OpenShift Service Mesh     2.5.0                Succeeded
kiali-ossm.v1.73.0                 Kiali                      1.73.0               Succeeded
tempo-operator.v0.1.0             Tempo Operator             0.1.0                Succeeded
```

---

## 6. Step 2: Deploy the Service Mesh Control Plane

Once operators are ready, deploy the SMCP.

### Using the `sm-control-plane` Chart

```bash
helm dependency update helm-charts/sm-control-plane
helm upgrade --install smcp helm-charts/sm-control-plane \
  --namespace istio-system \
  --create-namespace
```

### What Gets Created

1. **`ServiceMeshControlPlane`** named `basic`:

```yaml
apiVersion: maistra.io/v2
kind: ServiceMeshControlPlane
metadata:
  name: basic
  namespace: istio-system
spec:
  version: v2.5
  mode: ClusterWide
  meshConfig:
    extensionProviders:
      - name: tempo
        zipkin:
          port: 9411
          service: tempo-tempo-distributor.tracing-system.svc.cluster.local
      - name: "example-org-ext-authz-http"
        envoyExtAuthzHttp:
          service: "iam-auth-controller.iam-auth-controller.svc.cluster.local"
          port: 7010
  tracing:
    type: None  # Tempo handles this via the extension provider
```

2. **`ServiceMeshMemberRoll`** named `default`:

```yaml
apiVersion: maistra.io/v1
kind: ServiceMeshMemberRoll
metadata:
  name: default
  namespace: istio-system
spec:
  memberSelectors:
    - matchLabels:
        istio-injection: enabled
```

This selects all namespaces labeled `istio-injection: enabled` to join the mesh automatically.

3. **`Telemetry`** named `mesh-default`:

```yaml
apiVersion: telemetry.istio.io/v1
kind: Telemetry
metadata:
  name: mesh-default
  namespace: istio-system
spec:
  tracing:
    - providers:
        - name: tempo
      randomSamplingPercentage: 100.00
```

### Verify SMCP

```bash
# Check SMCP status
oc get smcp -n istio-system basic -o jsonpath='{.status.conditions[?(@.type=="Ready")].reason}'

# Check all Istio components are running
oc get pods -n istio-system
```

**Expected pods:**
```
istiod-basic-xxx                   Running
istio-ingressgateway-basic-xxx     Running  (if enabled)
istio-egressgateway-basic-xxx      Running  (if enabled)
```

---

## 7. Step 3: Enable Tracing with Tempo

### Using the `tempo` Chart

```bash
helm dependency update helm-charts/tempo
helm upgrade --install tempo helm-charts/tempo \
  --namespace tracing-system \
  --create-namespace \
  --set storage.secret.configs.externalSecretStoreRef.name=example-org-store
```

### What Gets Created

1. **`TempoStack`** CR — Defines the Tempo deployment with:
   - Distributor (receives spans via Zipkin protocol on port 9411)
   - Ingester (batches and stores traces)
   - Querier / Query Frontend (serves the Tempo UI and API)
   - Compactor (manages trace data lifecycle)
   - Azure blob storage backend

2. **`ExternalSecret`** for storage credentials:

```yaml
data:
  - remoteKey: tempo-store-account-key
    secretKey: account_key
  - remoteKey: tempo-store-account-name
    secretKey: account_name
  - remoteKey: tempo-store-container
    secretKey: container
```

3. **`VirtualService`** for the Tempo query frontend:

```yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: tempo-query-frontend
spec:
  gateways:
    - istio-ingress/tempo-gateway
  hosts:
    - "*"
  http:
    - route:
        - destination:
            host: tempo-tempo-query-frontend
            port:
              number: 16686
```

### Verify Tempo

```bash
oc get pods -n tracing-system
oc get tempo -n tracing-system
```

---

## 8. Step 4: Configure Kiali

### Using the `kiali` Chart

```bash
helm dependency update helm-charts/kiali
helm upgrade --install kiali helm-charts/kiali \
  --namespace istio-system
```

Kiali connects to the user-workload monitoring Prometheus (Thanos Querier) and Tempo to display traces alongside the service graph.

### Verify Kiali

```bash
oc get pods -n istio-system | grep kiali
oc get kiali -n istio-system
```

---

## 9. Step 5: Deploy Ingress Gateways

The `sm-ingress` chart creates Istio Gateways that handle external traffic entering the mesh.

### Using the `sm-ingress` Chart

```bash
helm dependency update helm-charts/sm-ingress
helm upgrade --install ingresses helm-charts/sm-ingress \
  --namespace mesh \
  --create-namespace \
  --values examples/infra/apps/service-mesh/dev/apps/ingresses/values.yaml
```

### What Gets Created

The values file defines multiple ingress configurations:

#### API Gateway (`api`)
- **Gateway** named `example-org-gateway` with two TLS server configurations:
  - Port 8443/HTTPS for `*.apps-dev.example-org.com`
  - Port 8443/HTTPS for `*.k8s.example-org.com`
- **OpenShift Routes** for external access (passthrough TLS)
- **AuthorizationPolicy** that delegates to the external auth provider (`example-org-ext-authz-http`)
- **ExternalSecrets** for TLS certificates from the cluster secret store

#### Tempo Gateway (`tempo-ingress`)
- **Gateway** named `tempo-gateway` on port 8080/HTTP
- **OpenShift Route** for the Tempo UI (edge TLS)

### Understanding the Gateway Template

File: `helm-charts/sm-ingress/templates/gateway.yaml`

```yaml
{{- $root := . -}}
{{- range $ingressName, $ingressValues := .Values.ingresses }}
---
apiVersion: networking.istio.io/v1beta1
kind: Gateway
metadata:
  name: {{ $ingressValues.gateway.name }}
  labels:
    istio: {{ $ingressName }}
    app: {{ $ingressName }}
    {{- include "library-chart.labels" $root | nindent 4 }}
spec:
  selector:
    istio: {{ $ingressName }}
  servers:
    {{- toYaml $ingressValues.gateway.servers | nindent 4 }}
{{- end }}
```

This iterates over each entry in `.Values.ingresses` and creates a Gateway. The Gateway's `servers` array is taken directly from values, allowing full flexibility.

---

## 10. Step 6: Configure External Authorization

The authorization flow works as follows:

```
Client Request
    │
    ▼
Istio Gateway
    │
    ▼
AuthorizationPolicy (CUSTOM action)
    │
    ▼
External Authz Provider (Envoy ext_authz)
    │
    ▼
IAM Auth Controller (port 7010)
    │
    ▼
Okta (OIDC) → Session Validation → Allow/Deny
```

### How It's Configured

The SMCP defines the extension provider:

```yaml
- name: "example-org-ext-authz-http"
  envoyExtAuthzHttp:
    service: "iam-auth-controller.iam-auth-controller.svc.cluster.local"
    port: 7010
    pathPrefix: /auth
    headersToUpstreamOnAllow: ["cookie", "remote_user", "user_object"]
    headersToDownstreamOnDeny: ["content-type", "set-cookie", "location"]
```

The Gateway's AuthorizationPolicy references this provider:

```yaml
authorization:
  enabled: true
  action: custom
  provider:
    name: example-org-ext-authz-http
  rules:
    - to:
        - operation:
            notHosts:
              - api.mesh.svc.cluster.local
            notMethods:
              - OPTIONS
```

This sends all requests (except health checks and OPTIONS preflight) to the IAM Auth Controller for authentication before they reach backend services.

---

## 11. Verifying the Installation

### End-to-End Verification

```bash
# 1. Check all namespaces
oc get ns | grep -E "istio-system|tracing-system|mesh"

# 2. Check SMCP status
oc get smcp -n istio-system basic -o wide

# 3. Check member roll
oc get smmr -n istio-system default -o wide

# 4. Check gateways
oc get gateway -n mesh

# 5. Check routes
oc get route -n mesh

# 6. Check authorization policy
oc get authorizationpolicy -n mesh

# 7. Test the mesh is accepting sidecars
oc label namespace my-app istio-injection=enabled
oc get pods -n my-app -o jsonpath='{.items[*].metadata.annotations}' | grep sidecar
```

### Common Issues and Fixes

| Symptom | Cause | Fix |
|---------|-------|-----|
| SMCP stays in "Installing" phase | Missing operator subscription | Check `oc get csv -n openshift-operators` |
| Pods not getting sidecar injected | Namespace not in mesh | Ensure `istio-injection: enabled` label and SMMR memberSelectors match |
| Tempo not receiving traces | Extension provider misconfigured | Check `smcp` meshConfig for the tempo provider |
| Gateway not accessible | Route or TLS issue | Check `oc get route -n mesh` and secret availability |

---

## 12. Key Takeaways

1. **Operator-first** — All service mesh components require their respective operators installed via OLM subscriptions before any CRDs become available.
2. **SMCP is the single source of truth** — It controls the Istio version, meshConfig, configured addons, and tracing providers in one resource.
3. **Extension providers** connect external services to the mesh — Tempo for tracing, external auth services for request authorization.
4. **MemberRoll with label selectors** — Namespaces opt into the mesh by carrying `istio-injection: enabled`. No manual namespace registration needed.
5. **Gateways are defined in values** — The `sm-ingress` chart iterates over `.Values.ingresses` to create multiple Gateways declaratively from a single values file.
6. **Authorization is per-Gateway** — Each Gateway can have its own `AuthorizationPolicy` with different providers and rules, enabling per-ingress security.
7. **Ingress gateways are standalone deployments** — They run their own Istio proxy container, separate from the control-plane ingress gateway. No traffic flows through `istio-system`.

---

## Hands-On Exercise

Deploy the full service mesh stack to a development cluster:

```bash
# 1. Install operators (wait 3-5 min)
helm upgrade --install operators helm-charts/k8s-operators -n openshift-operators

# 2. Deploy SMCP
helm upgrade --install smcp helm-charts/sm-control-plane -n istio-system --create-namespace

# 3. Deploy Tempo
helm upgrade --install tempo helm-charts/tempo -n tracing-system --create-namespace

# 4. Deploy Kiali
helm upgrade --install kiali helm-charts/kiali -n istio-system

# 5. Deploy Ingress Gateways
helm upgrade --install ingresses helm-charts/sm-ingress -n mesh \
  --create-namespace \
  -f examples/infra/apps/service-mesh/dev/apps/ingresses/values.yaml

# 6. Label a namespace to join the mesh
oc label namespace my-namespace istio-injection=enabled

# 7. Deploy an app and verify sidecar
oc get pods -n my-namespace -w
```

---

You now have a working service mesh. Operators, SMCP, Tempo, Kiali, and ingress gateways are all running. But running `helm install` commands by hand won't scale — especially if you have multiple clusters.

In the next tutorial, you'll take everything you just deployed and put it under GitOps. Instead of you pushing commands to the cluster, ArgoCD will pull the desired state from git and keep your mesh in sync automatically. One `git push` and ArgoCD handles the rest — across as many clusters as you have.

**Next:** [Tutorial 3 — ArgoCD and GitOps](tutorial-3-argocd-appset-service-mesh.md)
