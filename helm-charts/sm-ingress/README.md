sm-ingress Helm Chart
=====================

Overview
--------

The **sm-ingress** Helm Chart is a standalone chart used to configure and manage ingress gateways, authorization policies, and routing for services in a service mesh environment, such as Istio. It enables the creation of Deployments, Gateways, AuthorizationPolicies, HorizontalPodAutoscalers (HPA), ExternalSecrets for TLS, NetworkPolicies, PodDisruptionBudgets (PDB), and OpenShift Routes for traffic management.

Prerequisites
-------------

-   OpenShift 4.x.
-   Istio Service Mesh or similar service mesh.
-   Helm 3.x.

Installing the Chart
--------------------

Refer to [this doc](../README.md#usage) for the instructions on adding EXAMPLE_ORG helm charts.


To install the chart with the release name `my-release`, run:

```bash
helm install my-release example-org/sm-ingress
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

| Parameter | Description | Default |
| --- | --- | --- |
| `ingresses` | A map of ingress configurations. Each key represents a specific ingress. | `{}` |
| `ingresses[].service.ports` | List of ports exposed by the service. | `{}` |
| `ingresses[].deployment.sidecarInject` | Controls whether to inject an Istio sidecar into the deployment (`true` or `false`). | `"true"` |
| `ingresses[].deployment.containerPorts` | Container ports for the Istio proxy or other containers in the ingress deployment. | `{}` |
| `ingresses[].route.host` | The host for the OpenShift Route. | `""` |
| `ingresses[].route.wildcardPolicy` | Wildcard policy for the route (`None` or `Subdomain`). | `None` |
| `ingresses[].route.tls.termination` | TLS termination type for the route (`edge`, `passthrough`, `reencrypt`). | `edge` |
| `ingresses[].route.targetPort` | The target port for the route. | `http2` |
| `ingresses[].gateway.servers` | List of servers for the Istio Gateway, including port, protocol, hosts, and TLS configuration. | `{}` |
| `ingresses[].gateway.tlsSecrets` | List of TLS secrets for the gateway, specifying the secret name and external secret store reference. | `{}` |
| `ingresses[].gateway.authorization.enabled` | Enables authorization policy for the gateway (`true` or `false`). | `false` |
| `ingresses[].gateway.authorization.action` | Action for the authorization policy (`ALLOW`, `DENY`, `CUSTOM`). | `ALLOW` |
| `ingresses[].gateway.authorization.providers` | Name of the external authorization provider (e.g., `ext-authz`). | `{}` |
| `ingresses[].gateway.authorization.rules` | Rules for the authorization policy, such as allowed or denied hosts and methods. | `{}` |

### Example Values

```yaml
ingresses:
  # example-org ingress specific values
  example-org-ingress:
    service:
      ports:
        - name: http2
          port: 80
          targetPort: 8080
        - name: https
          port: 443
          targetPort: 8443
    deployment:
      sidecarInject: "true"
      containerPorts:
        - name: http2
          containerPort: 8080
        - name: https
          containerPort: 8443
    route:
      host: "example-org-ingress.mesh.apps.dev.k8s.example-org.com"
      wildcardPolicy: Subdomain
      tls:
        termination: passthrough
      targetPort: https
    gateway:
      tlsSecrets:
        - name: example-org-ingress-tls
          configs:
            externalSecretStoreRef:
              tlsCertRemoteKey:  example-org-ingress-tls-cert
              tlsKeyRemoteKey:  example-org-ingress-tls-key
      servers:
        - port:
            number: 8443
            name: "https"
            protocol: "HTTPS"
          hosts:
            - "*"
          tls:
            credentialName:  example-org-ingress-tls
            mode: SIMPLE
      authorization:
        enabled: true
        action: custom
        providers:
          name: example-org-ext-authz-http
        rules:
          - to:
              - operation:
                  notHosts:
                    - example-org-ingress.istio-ingress.svc.cluster.local
                  notMethods:
                    - OPTIONS

  # tempo ingress specific values
  tempo-ingress:
    service:
      ports:
        - name: http2
          port: 80
          targetPort: 8080
        - name: https
          port: 443
          targetPort: 8443
    deployment:
      sidecarInject: "true"
      containerPorts:
        - name: http2
          containerPort: 8080
        - name: https
          containerPort: 8443
    route:
      wildcardPolicy: None
      tls:
        termination: edge
      targetPort: http2
    gateway:
      servers:
        - port:
            number: 8080
            name: "http"
            protocol: "HTTP"
          hosts:
            - "*"
```