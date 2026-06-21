{{- define "library-chart.createDeployment" -}}
{{- include "library-chart.statefulset.defaultValues" . }}
{{- if .Values.blueGreen.enabled }}
apiVersion: argoproj.io/v1alpha1
kind: Rollout
{{- else if .Values.statefulSet.enabled }}
apiVersion: apps/v1
kind: StatefulSet
{{- else }}
apiVersion: apps/v1
kind: Deployment
{{- end }}
metadata:
  name: {{ .Release.Name }}
  labels:
    {{- include "library-chart.labels" . | nindent 4 }}
spec:
  {{- if not .Values.autoscaling.enabled }}
  replicas: {{ .Values.replicaCount }}
  {{- end }}
  {{- if .Values.blueGreen.enabled }}
  strategy:
    blueGreen:
      activeService: {{ .Release.Name }}  # Name of the active service
      previewService: {{ .Release.Name }}-preview # Name of the preview service
      autoPromotionEnabled: {{ .Values.blueGreen.autoPromotionEnabled | default "false"  }}
  {{- end}}
  {{- if .Values.statefulSet.enabled }}
  serviceName: {{ .Values.statefulSet.serviceName | default .Release.Name }}
  ordinals:
    start: 0  
  {{- end }}
  selector:
    matchLabels:
      {{- include "library-chart.selectorLabels" . | nindent 6 }}
  template:
    metadata:
      annotations:
        {{- if (.Values.serviceMesh).enabled }}
        sidecar.istio.io/inject: 'true'
        {{- end }}
      {{- with .Values.podAnnotations }}
        {{- toYaml . | nindent 8 }}
      {{- end }}
      labels:
        {{- include "library-chart.labels" . | nindent 8 }}
        {{- with .Values.podLabels }}
        {{- toYaml . | nindent 8 }}
        {{- end }}
    spec:
      {{- with .Values.imagePullSecrets }}
      imagePullSecrets:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      serviceAccountName: {{ include "library-chart.serviceAccountName" . }}
      securityContext:
        {{- toYaml .Values.podSecurityContext | nindent 8 }}
      containers:
        - name: {{ .Chart.Name }}
          securityContext:
            {{- toYaml .Values.securityContext | nindent 12 }}
          image: "{{ .Values.image.registry }}/{{ .Values.image.path }}:{{ .Values.image.tag | default .Chart.AppVersion }}"
          imagePullPolicy: {{ .Values.image.pullPolicy }}
          env:
            - name: POD_NAME
              valueFrom:
                fieldRef:
                  fieldPath: metadata.name
            - name: POD_NAMESPACE
              valueFrom:
                fieldRef:
                  fieldPath: metadata.namespace
            - name: POD_IP
              valueFrom:
                fieldRef:
                  fieldPath: status.podIP
            - name: SERVICE_ACCOUNT_NAME
              valueFrom:
                fieldRef:
                  fieldPath: spec.serviceAccountName
            - name: NODE_NAME
              valueFrom:
                fieldRef:
                  fieldPath: spec.nodeName
            {{- if .Values.statefulSet.enabled }}                  
            - name: CF_INSTANCE_INDEX
              valueFrom:
                fieldRef:
                  apiVersion: v1
                  fieldPath: 'metadata.labels[''apps.kubernetes.io/pod-index'']'
            - name: CF_INSTANCE_NAME
              valueFrom:
                fieldRef:
                  apiVersion: v1
                  fieldPath: 'metadata.labels[''statefulset.kubernetes.io/pod-name'']'
            {{- end }}
            {{- if .Values.appConfig }}
            - name: APP_CONFIG_PATH
              value: "/config/app-config.yaml"
            {{- end }}
          {{- with .Values.env }}
            {{- toYaml . | nindent 12 }}
          {{- end }}
          envFrom:
          {{- if .Values.appSecrets }}
            - secretRef:
                name: app-secrets-{{ .Release.Name }}
          {{- end }}
          {{- with .Values.envFrom }}
            {{- toYaml . | nindent 12 }}
          {{- end }}
          {{- with .Values.command }}
          command:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          {{- with .Values.ports }}
          ports:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          {{- if .Values.livenessProbe }}
          livenessProbe:
            {{- toYaml .Values.livenessProbe | nindent 12 }}
          {{- end }}
          {{- if .Values.readinessProbe }}
          readinessProbe:
            {{- toYaml .Values.readinessProbe | nindent 12 }}
          {{- end }}
          resources:
            {{- toYaml .Values.resources | nindent 12 }}
          volumeMounts:
          {{- if .Values.appConfig }}
            - name: app-config
              mountPath: "/config"
              readOnly: true
          {{- end }}
            {{- with .Values.volumeMounts }}
              {{- toYaml . | nindent 12 }}
            {{- end }}
          {{- range .Values.configmaps }}
            {{- if .mount.enabled }}
            - name: {{ .name }}
              mountPath: {{ .mount.path }}
            {{- end }}
          {{- end }}
          {{- range .Values.pvcs }}
          {{- if .mount.enabled }}
            - name: {{ .name }}
              mountPath: {{ .mount.path }}
          {{- end }}
          {{- end }}
      volumes:
      {{- if .Values.appConfig }}
        - name: app-config
          secret:
            secretName: app-config-{{ .Release.Name }}
      {{- end }}
      {{- with .Values.volumes }}
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- range .Values.configmaps }}
        {{- if .mount.enabled }}
        - name: {{ .name }}
          configMap:
            name: {{ .name }}
            items:
            {{- range .items }}
              - key: {{ .key }}
                path: {{ .path | default .key }}
            {{- end }}
        {{- end }}
      {{- end }}
      {{- range .Values.pvcs }}
        {{- if .mount.enabled }}
        - name: {{ .name }}
          persistentVolumeClaim:
            claimName: {{ .name }}
        {{- end }}
      {{- end }}
      {{- with .Values.nodeSelector }}
      nodeSelector:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.affinity }}
      affinity:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.tolerations }}
      tolerations:
        {{- toYaml . | nindent 8 }}
      {{- end }}
{{- end }}
