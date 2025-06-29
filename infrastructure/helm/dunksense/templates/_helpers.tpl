{{/*
Expand the name of the chart.
*/}}
{{- define "dunksense.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "dunksense.fullname" -}}
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
{{- define "dunksense.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "dunksense.labels" -}}
helm.sh/chart: {{ include "dunksense.chart" . }}
{{ include "dunksense.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: dunksense
{{- end }}

{{/*
Selector labels
*/}}
{{- define "dunksense.selectorLabels" -}}
app.kubernetes.io/name: {{ include "dunksense.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "dunksense.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "dunksense.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Generate certificates for TLS
*/}}
{{- define "dunksense.gen-certs" -}}
{{- $altNames := list ( printf "%s.%s" (include "dunksense.name" .) .Release.Namespace ) ( printf "%s.%s.svc" (include "dunksense.name" .) .Release.Namespace ) -}}
{{- $ca := genCA "dunksense-ca" 365 -}}
{{- $cert := genSignedCert ( include "dunksense.name" . ) nil $altNames 365 $ca -}}
tls.crt: {{ $cert.Cert | b64enc }}
tls.key: {{ $cert.Key | b64enc }}
{{- end }}

{{/*
Return the proper Docker Image Registry Secret Names
*/}}
{{- define "dunksense.imagePullSecrets" -}}
{{- include "common.images.pullSecrets" (dict "images" (list .Values.metricsService.image .Values.mlPipeline.image .Values.apiGateway.image) "global" .Values.global) -}}
{{- end }}

{{/*
Return PostgreSQL Hostname
*/}}
{{- define "dunksense.postgresql.host" -}}
{{- if .Values.postgresql.enabled }}
    {{- if eq .Values.postgresql.architecture "replication" }}
        {{- printf "%s-postgresql-primary" (include "common.names.fullname" .) -}}
    {{- else -}}
        {{- printf "%s-postgresql" (include "common.names.fullname" .) -}}
    {{- end -}}
{{- else -}}
    {{- printf "%s" .Values.externalDatabase.host -}}
{{- end -}}
{{- end -}}

{{/*
Return PostgreSQL Port
*/}}
{{- define "dunksense.postgresql.port" -}}
{{- if .Values.postgresql.enabled }}
    {{- printf "5432" -}}
{{- else -}}
    {{- printf "%d" (.Values.externalDatabase.port | int ) -}}
{{- end -}}
{{- end -}}

{{/*
Return PostgreSQL Database Name
*/}}
{{- define "dunksense.postgresql.database" -}}
{{- if .Values.postgresql.enabled }}
    {{- printf "%s" .Values.postgresql.auth.database -}}
{{- else -}}
    {{- printf "%s" .Values.externalDatabase.database -}}
{{- end -}}
{{- end -}}

{{/*
Return PostgreSQL Username
*/}}
{{- define "dunksense.postgresql.username" -}}
{{- if .Values.postgresql.enabled }}
    {{- printf "%s" .Values.postgresql.auth.username -}}
{{- else -}}
    {{- printf "%s" .Values.externalDatabase.username -}}
{{- end -}}
{{- end -}}

{{/*
Return PostgreSQL Secret Name
*/}}
{{- define "dunksense.postgresql.secretName" -}}
{{- if .Values.postgresql.enabled }}
    {{- printf "%s-postgresql" (include "common.names.fullname" .) -}}
{{- else -}}
    {{- printf "%s-externaldb" (include "common.names.fullname" .) -}}
{{- end -}}
{{- end -}}

{{/*
Return Redis Hostname
*/}}
{{- define "dunksense.redis.host" -}}
{{- if .Values.redis.enabled }}
    {{- printf "%s-redis-master" (include "common.names.fullname" .) -}}
{{- else -}}
    {{- printf "%s" .Values.externalRedis.host -}}
{{- end -}}
{{- end -}}

{{/*
Return Redis Port
*/}}
{{- define "dunksense.redis.port" -}}
{{- if .Values.redis.enabled }}
    {{- printf "6379" -}}
{{- else -}}
    {{- printf "%d" (.Values.externalRedis.port | int ) -}}
{{- end -}}
{{- end -}}

{{/*
Return Redis Secret Name
*/}}
{{- define "dunksense.redis.secretName" -}}
{{- if .Values.redis.enabled }}
    {{- printf "%s-redis" (include "common.names.fullname" .) -}}
{{- else -}}
    {{- printf "%s-externalredis" (include "common.names.fullname" .) -}}
{{- end -}}
{{- end -}} 