{{/*
Expand the name of the chart.
*/}}
{{- define "library-chart.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "library-chart.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "library-chart.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "library-chart.labels" -}}
helm.sh/chart: {{ include "library-chart.chart" . }}
{{ include "library-chart.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app: {{ .Release.Name }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "library-chart.selectorLabels" -}}
app.kubernetes.io/name: {{ include "library-chart.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "library-chart.serviceAccountName" -}}
{{- if .Values.serviceAccount -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "library-chart.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}
{{- end }}

{{/*
This fuction sets up a default value for .Values.statefulset dictionary when the object is undefined in the values file.
Logic: Set enabled to false when .Values.statefulset.enabled is undefined, 
if .Values.statefulset is undefined then create an empty dictionary
*/}}
{{- define "library-chart.statefulset.defaultValues" -}}
{{- if not (and (hasKey .Values "statefulSet") (hasKey .Values.statefulSet "enabled")) -}}
  {{- $_ := set .Values "statefulSet" (merge (dict "enabled" false) (or .Values.statefulSet (dict))) -}}
{{- end -}}
{{- end }}

{{/*
 Label and Annotate as well as DeLabel and DeAnnotate Namespace 
*/}}
{{- define "library-chart.labelAndAnnotateNamespace" -}}
apiVersion: v1
kind: ServiceAccount
metadata:
  name: {{ .Release.Name }}-hook
  annotations:
    "helm.sh/hook": pre-install
    "helm.sh/hook-weight": "0"
    "helm.sh/hook-delete-policy": before-hook-creation,hook-succeeded,hook-failed
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: {{ .Release.Name }}-hook
  annotations:
    "helm.sh/hook": pre-install
    "helm.sh/hook-weight": "1"
    "helm.sh/hook-delete-policy": before-hook-creation,hook-succeeded,hook-failed
rules:
  - apiGroups:
      - ''
    resources:
      - namespaces
    verbs:
      - get
      - patch
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: {{ .Release.Name }}-hook
  annotations:
    "helm.sh/hook": pre-install
    "helm.sh/hook-weight": "1"
    "helm.sh/hook-delete-policy": before-hook-creation,hook-succeeded,hook-failed
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: {{ .Release.Name }}-hook
subjects:
  - kind: ServiceAccount
    name: {{ .Release.Name }}-hook
---
apiVersion: batch/v1
kind: Job
metadata:
  name: {{ .Release.Name }}-hook
  annotations:
    "helm.sh/hook": pre-install
    "helm.sh/hook-weight": "1"
    "helm.sh/hook-delete-policy": before-hook-creation,hook-succeeded,hook-failed
spec:
  template:
    spec:
      serviceAccountName: {{ .Release.Name }}-hook
      containers:
        - name: add-remove-resources
          image: quay.io/openshift/origin-cli  # Use an image that contains kubectl
          command:
            - /bin/sh
            - -c
            - |
              # Add labels
              {{- range $key, $value := .Values.namespaceLabels }}
              oc label namespace {{ $.Release.Namespace }} {{ $key }}={{ $value }} --overwrite
              {{- end }}

              # Add annotations
              {{- range $key, $value := .Values.namespaceAnnotations }}
              oc annotate namespace {{ $.Release.Namespace }} {{ $key }}={{ $value }} --overwrite
              {{- end }}

              # Remove labels
              {{- range $index, $label := .Values.namespaceLabelsToRemove }}
              oc label namespace {{ $.Release.Namespace }} {{ $label }}-
              {{- end }}

              # Remove annotations
              {{- range $index, $annotation := .Values.namespaceAnnotationsToRemove }}
              oc annotate namespace {{ $.Release.Namespace }} {{ $annotation }}-
              {{- end }}
      restartPolicy: Never
  backoffLimit: 4
{{- end }}