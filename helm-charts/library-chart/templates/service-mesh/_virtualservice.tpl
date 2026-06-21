{{- define "library-chart.createVirtualService" -}}
{{- $meshService := . }}
{{- if $meshService.routeHost }}
---
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: {{ $meshService.resourceName }}
{{- $serviceHost := $meshService.host | default $meshService.serviceName }}
spec:
  gateways:
    - istio-ingress/example-org-gateway
  exportTo:
    - istio-ingress
  hosts:
    - {{ $meshService.routeHost | default $serviceHost  }}
  http:
    -   
  {{- if and $meshService.isExternal $meshService.routeHost }}
      match:
        - authority:
            exact: {{ $meshService.routeHost }}
      rewrite:
        authority: {{ $meshService.host }}
  {{- end }}
      route:
        - destination:
            host: {{ $serviceHost }}
            port:
              number: {{ $meshService.port }}
          {{- if $meshService.isExternal }}
          headers:
            request:
              add:
                Host: {{ $meshService.host }}
          {{- end }}
{{- end }}
{{- end }}