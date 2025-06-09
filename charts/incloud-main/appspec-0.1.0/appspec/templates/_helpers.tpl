{{/*
Expand the name of the chart.
*/}}
{{- define "appSpec.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "appSpec.fullname" -}}
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
{{- define "appSpec.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "appSpec.labels" -}}

helm.sh/chart: {{ include "appSpec.chart" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "appSpec.applicationSelectorLabels" -}}
{{- $applicationName := index $ 0 }}
{{- $globalValue     := index $ 1 }}
app.kubernetes.io/name: {{ $applicationName }}
app.kubernetes.io/instance: {{ $globalValue.Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "appSpec.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "appSpec.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}



{{- define "appSpec.container-spec" -}}
{{- $containerValue := index $ 0 }}
{{- $containerName  := $containerValue.name }}
{{- $releaseName    := index $ 2 }}
- name: {{ $containerName }}

  {{- if $containerValue.image.sha256 }}
  image: {{ $containerValue.image.repository }}@sha256:{{ $containerValue.image.sha256 }}
  {{- else }}
  image: {{ $containerValue.image.repository }}:{{ $containerValue.image.tag }}
  {{- end }}
  imagePullPolicy: {{ $containerValue.image.pullPolicy | default $containerValue.defaultContainerSpec.defaultImagePullPolicy}}

  {{- with $containerValue.extraCommand }}
  command:
    {{- toYaml . | nindent 4 }}
  {{- end }}

  {{- with $containerValue.extraArgs }}
  args:
    {{- range $k, $v := . }}
    - --{{- $k }}={{ $v -}}
    {{- end}}
  {{- end }}

  {{- with $containerValue.extraPorts }}
  ports:
    {{- range $k, $v := . }}
    - name: {{ $k }}
      containerPort: {{ $v.containerPort }}
      protocol: {{ $v.protocol }}
    {{- end}}
  {{- end }}

  {{- if or $containerValue.extraMetadataEnv $containerValue.extraEnv}}
  env:
  {{- with $containerValue.extraEnv }}

    {{- range $k, $v := . }}
    - name: {{ $k }}
      value: {{ $v | quote }}
    {{- end}}
  {{- end }}

  {{- with $containerValue.extraMetadataEnv }}

    {{- range $k, $v := . }}
    - name: {{ $k }}
      valueFrom:
        {{- $v.valueFrom  | toYaml | nindent 8 }}
    {{- end}}
  {{- end }}
  {{- end }}

  {{- with $containerValue.extraEnvFrom }}
  envFrom:
    {{- range $k, $v := .configMapRefs }}
    - configMapRef: 
        name: {{ $k }}
    {{- end }}

    {{- range $k, $v := .secretRefs }}
    - secretRef: 
        name: {{ $k }}
    {{- end }}
  {{- end }}

  {{- with $containerValue.extraLivenessProbe }}
  livenessProbe:
    {{- toYaml . | nindent 4 }}
  {{- end }}

  {{- with $containerValue.extraReadinessProbe }}
  readinessProbe:
    {{- toYaml . | nindent 4 }}
  {{- end }}

  {{- with $containerValue.extraLifecycle }}
  lifecycle:
    {{- toYaml . | nindent 4 }}
  {{- end }}

  {{- $containerVolumeMounts := mergeOverwrite $containerValue.defaultContainerSpec.defaultVolumeMounts ( $containerValue.extraVolumeMounts | default dict ) }}
  volumeMounts:
    {{- range $volumeName, $volumeValue := $containerVolumeMounts }}
    - name: {{ $volumeName | lower }}
      mountPath: {{ $volumeValue.volumeMount.path }}
      {{- with $volumeValue.volumeMount.spec }}
      {{- . | toYaml | nindent 6 }}
      {{- end }}
    {{- end }}

  {{- $securityContext := mergeOverwrite $containerValue.defaultContainerSpec.defaultSecurityContext  ( $containerValue.extraSecurityContext | default dict ) }}
  securityContext:
    {{- toYaml $securityContext | nindent 4 }}

  {{- $resources :=  mergeOverwrite $containerValue.defaultContainerSpec.defaultResources ( $containerValue.extraResources | default dict ) }}
  resources:
    {{- toYaml $resources | nindent 4 }}

  terminationMessagePath:   {{ $containerValue.extraTerminationMessagePath    | default $containerValue.defaultContainerSpec.defaultTerminationMessagePath }}
  terminationMessagePolicy: {{ $containerValue.extraTerminationMessagePolicy  | default $containerValue.defaultContainerSpec.defaultTerminationMessagePolicy }}

{{- end }}



{{- define "appSpec.deployment.containers-volumes" -}}

{{- $volumeValue  := index $ 0 }}
{{- $volumeName   := index $ 1 }}
{{- $releaseName  := index $ 2 }}

{{- if eq $volumeValue.volume.mode "hostPath" }}
- name: {{ $volumeName | lower }}
  hostPath: 
    {{- $volumeValue.volume.spec | toYaml | nindent 4 }}
{{- end }}

{{- if eq $volumeValue.volume.mode "emptyDir" }}
- name: {{ $volumeName | lower }}
  emptyDir: 
    {{- $volumeValue.volume.spec | toYaml | nindent 4 }}
{{- end }}

{{- if eq $volumeValue.volume.mode "persistentVolumeClaim" }}
- name: {{ $volumeName | lower }}
  persistentVolumeClaim: 
    {{- $volumeValue.volume.spec | toYaml | nindent 4 }}
{{- end }}

{{- if eq $volumeValue.volume.mode "configMap" }}
- name: {{ $volumeName | lower }}
  configMap: 
    {{- if $volumeValue.volume.notReleased | default false }} # внешний от релиза ресурс
    name: {{ $volumeValue.volume.name }}
    {{- else }}
    name: {{ index $ 2 }}-{{ $volumeValue.volume.name }}
    {{- end}}

    {{- with  $volumeValue.volume.spec  }}
      {{- . | toYaml | nindent 4 }}
    {{- end }}
{{- end }}

{{- if eq $volumeValue.volume.mode "secret" }}
- name: {{ $volumeName | lower }}
  secret:
    secretName: {{ index $ 2 }}-{{ $volumeValue.volume.name }}
{{- end }}

{{- end }}



{{- define "appSpec.deployment.volume-annotation" -}}
  {{- $volumeValue  := index $ 0 }}
  {{- $volumeName   := index $ 1 }}
  {{- $payload256   := "" }}
{{- with $volumeValue.volume.payload }}
  {{- if (eq (lower .format) "json")  }}
checksum/configmap-{{ lower $volumeName }}: "{{ .content | toJson |sha256sum }}"
  {{- end }}
  {{- if (eq (lower .format) "yaml")  }}
checksum/configmap-{{ lower $volumeName }}: "{{ .content | toJson | sha256sum }}"
  {{- end }}
  {{- if (eq (lower .format) "text")  }}
checksum/configmap-{{ lower $volumeName }}: "{{ .content | sha256sum }}"
  {{- end }}
{{- end }}
{{- end }}
