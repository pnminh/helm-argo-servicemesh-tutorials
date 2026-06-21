{{- define "library-chart.createDestinationRule" -}}
{{- $meshService := . -}}
{{- if and $meshService.isExternal $meshService.routeHost }}
---
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: {{ $meshService.resourceName }}
spec:
  host: {{ $meshService.host }}
  exportTo:
    - istio-ingress
  trafficPolicy:
    portLevelSettings:
    - port:
        number: {{ $meshService.port }}
      {{- if eq $meshService.protocol "https" }}
      tls:
        mode: SIMPLE
      {{- end }}
{{- end }}
{{- end }}
