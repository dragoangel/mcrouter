{{/*
Expand the name of the chart.
*/}}
{{- define "mcrouter.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name. If the release name contains the
chart name it is used as-is. Truncated to 63 chars for the DNS naming spec.
*/}}
{{- define "mcrouter.fullname" -}}
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
Chart name and version, for the helm.sh/chart label.
*/}}
{{- define "mcrouter.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels. commonLabels (highest precedence) are merged in, deduping any
keys that overlap the standard labels.
*/}}
{{- define "mcrouter.labels" -}}
{{- $std := dict "helm.sh/chart" (include "mcrouter.chart" .) "app.kubernetes.io/managed-by" .Release.Service -}}
{{- with .Chart.AppVersion }}{{- $_ := set $std "app.kubernetes.io/version" . -}}{{- end -}}
{{- $selector := include "mcrouter.selectorLabels" . | fromYaml -}}
{{- merge (.Values.commonLabels | default dict) $selector $std | toYaml -}}
{{- end }}

{{/*
Selector labels.
*/}}
{{- define "mcrouter.selectorLabels" -}}
app.kubernetes.io/name: {{ include "mcrouter.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Name of the ServiceAccount to use.
*/}}
{{- define "mcrouter.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "mcrouter.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}
