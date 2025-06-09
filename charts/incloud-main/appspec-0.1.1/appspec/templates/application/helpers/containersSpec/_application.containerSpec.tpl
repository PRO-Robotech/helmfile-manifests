

{{- define "appSpec.container-spec" -}}

{{- $containerValue        := index $ 0 -}}
{{- $containerName         := $containerValue.name -}}
{{- $global                := index $ 2 -}}
{{- $defaultContainerSpec  := $global.Values.defaults.defaultContainerSpec -}}


- name: {{ $containerName }}

  {{- if $containerValue.image.sha256 }}
  image: {{ $containerValue.image.repository }}@sha256:{{ $containerValue.image.sha256 }}
  {{- else }}
  image: {{ $containerValue.image.repository }}:{{ $containerValue.image.tag }}
  {{- end }}
  imagePullPolicy: {{ $containerValue.image.pullPolicy | default $defaultContainerSpec.defaultImagePullPolicy }}

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

  {{- $volumeMounts := deepCopy $defaultContainerSpec.defaultVolumeMounts | merge ( $containerValue.extraVolumeMounts | default dict ) }}
  volumeMounts:
    {{- range $volumeName, $volumeValue := $volumeMounts }}
    - name: {{ $volumeName | lower }}
      mountPath: {{ $volumeValue.volumeMount.path }}
      {{- with $volumeValue.volumeMount.spec }}
      {{- . | toYaml | nindent 6 }}
      {{- end }}
    {{- end }}

  {{- $securityContext := mergeOverwrite $defaultContainerSpec.defaultSecurityContext  ( $containerValue.extraSecurityContext | default dict ) }}
  securityContext:
    {{- toYaml $securityContext | nindent 4 }}

  {{- $resources :=  mergeOverwrite $defaultContainerSpec.defaultResources ( $containerValue.extraResources | default dict ) }}
  resources:
    {{- toYaml $resources | nindent 4 }}

  terminationMessagePath:   {{ $containerValue.extraTerminationMessagePath    | default $defaultContainerSpec.defaultTerminationMessagePath }}
  terminationMessagePolicy: {{ $containerValue.extraTerminationMessagePolicy  | default $defaultContainerSpec.defaultTerminationMessagePolicy }}

{{- end -}}
