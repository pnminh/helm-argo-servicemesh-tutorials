{{- define "library-chart.createSecret" -}}
apiVersion: v1
kind: Secret
metadata:
  name: {{ .Values.secret.name }}
  labels:
    {{- include "library-chart.labels" . | nindent 8 }}
type: {{ .Values.type | default "Opaque" }}
data:
  {{- range $key, $value := .Values.data }}
  {{ $key }}: {{ $value | b64enc }}
  {{- end }}
{{- end }}