{{- define "library-chart.createJob" -}}
apiVersion: batch/v1
kind: Job
metadata:
  name: {{ .Release.Name }}
  labels:
    {{- include "library-chart.labels" . | nindent 4 }}
spec:
  backoffLimit: {{ .Values.backoffLimit }}
  template:
    metadata:
      {{- with .Values.podAnnotations }}
      annotations:
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
          {{- with .Values.command }}
          command :
            {{- toYaml . | nindent 12 }}
          {{- end }}
          {{- with .Values.env }}
          env :
            {{- toYaml . | nindent 12 }}
          {{- end }}
          envFrom:
          {{- with .Values.envFrom }}
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
      restartPolicy: {{ .Values.restartPolicy }}
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