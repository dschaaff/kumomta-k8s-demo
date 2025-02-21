{{/*
Expand the name of the chart.
*/}}
{{- define "kumomta.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "kumomta.fullname" -}}
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
{{- define "kumomta.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "kumomta.labels" -}}
helm.sh/chart: {{ include "kumomta.chart" . }}
{{ include "kumomta.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "kumomta.tsaLabels" -}}
helm.sh/chart: {{ include "kumomta.chart" . }}
{{ include "kumomta.tsaSelectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "kumomta.sinkLabels" -}}
helm.sh/chart: {{ include "kumomta.chart" . }}
{{ include "kumomta.sinkSelectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}
{{/*
Selector labels
*/}}
{{- define "kumomta.selectorLabels" -}}
app.kubernetes.io/name: {{ include "kumomta.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{- define "kumomta.tsaSelectorLabels" -}}
app.kubernetes.io/name: {{ include "kumomta.name" . }}-tsa
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{- define "kumomta.sinkSelectorLabels" -}}
app.kubernetes.io/name: {{ include "kumomta.name" . }}-sink
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
{{/*
Create the name of the service account to use
*/}}
{{- define "kumomta.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "kumomta.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}
