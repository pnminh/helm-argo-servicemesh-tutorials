{{- define "library-chart.createConfigmaps" -}}
{{- $root := . -}}
{{- range  $index, $configmap := .Values.configmaps }}
  {{- if .create }}
    {{- if $index }}
---
    {{- end }}
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ .name }}
  labels:
    {{- include "library-chart.labels" $root | nindent 4 }}
data:
  {{- range .items }}
  {{ .key }}: | 
    {{- .value | nindent 4 }}
  {{- end }}
  {{- end }}
{{- end }}
{{- end }}
