{{/*
Pod template shared by the StatefulSet and DaemonSet controllers. Include it
under a controller's `spec:` with:  {{ include "mcrouter.podTemplate" . | nindent 2 }}
Controller-specific bits (hostPort, anti-affinity) switch on .Values.deploymentType.
*/}}
{{- define "mcrouter.podTemplate" -}}
template:
  metadata:
    labels:
      {{- include "mcrouter.labels" . | nindent 6 }}
      {{- with .Values.podLabels }}
      {{- toYaml . | nindent 6 }}
      {{- end }}
    annotations:
      {{- toYaml .Values.podAnnotations | nindent 6 }}
  spec:
    serviceAccountName: {{ include "mcrouter.serviceAccountName" . }}
    automountServiceAccountToken: {{ .Values.serviceAccount.automountServiceAccountToken }}
    {{- with .Values.imagePullSecrets }}
    imagePullSecrets:
      {{- toYaml . | nindent 6 }}
    {{- end }}
    {{- with .Values.priorityClassName }}
    priorityClassName: {{ . }}
    {{- end }}
    nodeSelector:
      {{- toYaml .Values.nodeSelector | nindent 6 }}
    tolerations:
      {{- toYaml .Values.tolerations | nindent 6 }}
    {{- if eq .Values.deploymentType "StatefulSet" }}
    affinity:
      podAntiAffinity:
        {{- if eq .Values.statefulset.antiAffinity "hard" }}
        requiredDuringSchedulingIgnoredDuringExecution:
        - topologyKey: kubernetes.io/hostname
          labelSelector:
            matchLabels:
              {{- include "mcrouter.selectorLabels" . | nindent 14 }}
        {{- else if eq .Values.statefulset.antiAffinity "soft" }}
        preferredDuringSchedulingIgnoredDuringExecution:
        - weight: 5
          podAffinityTerm:
            topologyKey: kubernetes.io/hostname
            labelSelector:
              matchLabels:
                {{- include "mcrouter.selectorLabels" . | nindent 16 }}
        {{- end }}
    {{- end }}
    securityContext:
      {{- toYaml .Values.podSecurityContext | nindent 6 }}
    containers:
    - name: {{ include "mcrouter.name" . }}
      image: {{ with .Values.image.registry }}{{ . }}/{{ end }}{{ .Values.image.repository }}:{{ .Values.image.tag | default .Chart.AppVersion }}
      imagePullPolicy: {{ default "" .Values.image.pullPolicy | quote }}
      command: ["mcrouter"]
      args:
      - -p {{ .Values.port }}
      - --config-file=/etc/mcrouter/config.json
      {{- range .Values.extraArgs }}
      - {{ . | quote }}
      {{- end }}
      {{- with .Values.extraEnvVars }}
      env:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      securityContext:
        {{- toYaml .Values.containerSecurityContext | nindent 8 }}
      volumeMounts:
      - name: config
        mountPath: /etc/mcrouter
      - name: var-mcrouter
        mountPath: /var/mcrouter
      - name: var-spool-mcrouter
        mountPath: /var/spool/mcrouter
      {{- with .Values.extraVolumeMounts }}
      {{- toYaml . | nindent 6 }}
      {{- end }}
      ports:
      - name: mcrouter
        containerPort: {{ .Values.port }}
        {{- if eq .Values.deploymentType "DaemonSet" }}
        hostPort: {{ .Values.daemonset.hostPort }}
        {{- end }}
      {{- if .Values.livenessProbe.enabled }}
      livenessProbe:
        tcpSocket:
          port: mcrouter
        initialDelaySeconds: {{ .Values.livenessProbe.initialDelaySeconds }}
        periodSeconds: {{ .Values.livenessProbe.periodSeconds }}
        timeoutSeconds: {{ .Values.livenessProbe.timeoutSeconds }}
        failureThreshold: {{ .Values.livenessProbe.failureThreshold }}
        successThreshold: {{ .Values.livenessProbe.successThreshold }}
      {{- end }}
      {{- if .Values.readinessProbe.enabled }}
      readinessProbe:
        tcpSocket:
          port: mcrouter
        initialDelaySeconds: {{ .Values.readinessProbe.initialDelaySeconds }}
        periodSeconds: {{ .Values.readinessProbe.periodSeconds }}
        timeoutSeconds: {{ .Values.readinessProbe.timeoutSeconds }}
        failureThreshold: {{ .Values.readinessProbe.failureThreshold }}
        successThreshold: {{ .Values.readinessProbe.successThreshold }}
      {{- end }}
      resources:
        {{- toYaml .Values.resources | nindent 8 }}
    {{- if .Values.metrics.enabled }}
    - name: exporter
      image: {{ with .Values.metrics.image.registry }}{{ . }}/{{ end }}{{ .Values.metrics.image.repository }}:{{ .Values.metrics.image.tag }}
      securityContext:
        {{- toYaml .Values.containerSecurityContext | nindent 8 }}
      resources:
        {{- toYaml .Values.metrics.resources | nindent 8 }}
      ports:
      - name: monitoring
        containerPort: {{ .Values.metrics.container.port }}
      livenessProbe:
        tcpSocket:
          port: monitoring
        initialDelaySeconds: 30
        timeoutSeconds: 5
      readinessProbe:
        tcpSocket:
          port: monitoring
        initialDelaySeconds: 5
        timeoutSeconds: 5
    {{- end }}
    volumes:
    - name: config
      configMap:
        name: {{ include "mcrouter.fullname" . }}
    - name: var-mcrouter
      emptyDir:
        medium: {{ .Values.tmpfs.medium | quote }}
        sizeLimit: {{ .Values.tmpfs.runtimeSizeLimit }}
    - name: var-spool-mcrouter
      emptyDir:
        medium: {{ .Values.tmpfs.medium | quote }}
        sizeLimit: {{ .Values.tmpfs.spoolSizeLimit }}
    {{- with .Values.extraVolumes }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
{{- end -}}
