
{{- define "library-chart.createServiceEntry" -}}
{{- $meshService := . -}}
{{- if $meshService.isExternal }}
---
apiVersion: networking.istio.io/v1beta1
kind: ServiceEntry
metadata:
  name: {{ $meshService.resourceName }}
spec:
  hosts:
    - {{ $meshService.host }}
  location: MESH_EXTERNAL
  ports:
    {{- $protocol := $meshService.protocol | default "http" }}
    - name: {{ $protocol }}
      number: {{ $meshService.port }}
      protocol: {{ $protocol | upper }}
  resolution: DNS
{{- end }}
{{- end }}
