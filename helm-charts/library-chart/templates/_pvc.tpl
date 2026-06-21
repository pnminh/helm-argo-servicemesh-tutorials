{{- define "library-chart.createPvcs" -}}
{{- $root := . -}}
{{- range  $index, $pvc := .Values.pvcs }}
  {{- if .create }}
    {{- if $index }}
---
    {{- end }}
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: {{ .name }}
  annotations:
    "helm.sh/resource-policy": keep
spec:
  {{- if .storageClassName }}
  storageClassName: {{ .storageClassName }}
  {{- end }}
  accessModes:
    {{- range .accessModes }}
    - {{ . }}
    {{- end }}
  {{- $storage := "1Gi" }}
  {{- if .resources }}   
    {{- if .resources.requests }}   
      {{- if .resources.requests.storage }}   
        {{- $storage = .resources.requests.storage }}
      {{- end }}
    {{- end }}
  {{- end }}
  resources:
    requests:
      storage: {{ $storage }}
  {{- end }}
{{- end }}
{{- end }}