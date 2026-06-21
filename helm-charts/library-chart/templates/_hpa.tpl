{{- define "library-chart.createHPA" -}}
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: {{ .Release.Name }}
  labels:
    {{- include "library-chart.labels" . | nindent 4 }}
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: {{ .Release.Name }}
  minReplicas: {{ .Values.autoscaling.minReplicas }}
  maxReplicas: {{ .Values.autoscaling.maxReplicas }}
  metrics:
    {{- range .Values.autoscaling.metrics }}
    - type: {{ .type }}
      {{- if eq .type "Resource" }}
      resource:
        name: {{ .resource.name }}
        target:
          type: {{ .resource.target.type }}
          {{- if eq .resource.target.type "Utilization" }}
          averageUtilization: {{ .resource.target.averageUtilization }}
          {{- else if eq .resource.target.type "Value" }}
          averageValue: {{ .resource.target.averageValue }}
          {{- end }}
      {{- end }}
    {{- end }}
  {{- if .Values.autoscaling.behavior }}
  behavior:
    scaleUp:
      stabilizationWindowSeconds: {{ .Values.autoscaling.behavior.scaleUp.stabilizationWindowSeconds | default 60 }}
      policies:
        {{- range .Values.autoscaling.behavior.scaleUp.policies }}
        - type: {{ .type }}
          value: {{ .value }}
          periodSeconds: {{ .periodSeconds }}
        {{- end }}
    scaleDown:
      stabilizationWindowSeconds: {{ .Values.autoscaling.behavior.scaleDown.stabilizationWindowSeconds | default 300 }}
      policies:
        {{- range .Values.autoscaling.behavior.scaleDown.policies }}
        - type: {{ .type }}
          value: {{ .value }}
          periodSeconds: {{ .periodSeconds }}
        {{- end }}
  {{- end }}
{{- end }}
