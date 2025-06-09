
{{- define "appSpec.configMap.format.yaml" -}}

  {{- $appVolumeValue := $ -}}
  {{- $format         := lower $appVolumeValue.payload.format -}}

  {{- if eq $format "yaml" -}}
    {{- $appVolumeValue.name -}}: 
    {{- $appVolumeValue.payload.content | toYaml | nindent 2 -}}
  {{- end -}}

{{- end -}}

{{- define "appSpec.configMap.checksum.yaml" -}}

  {{- $appVolumeValue := $ -}}
  {{- $format         := lower $appVolumeValue.payload.format -}}

  {{- if eq $format "yaml" -}}
    checksum/configmap-{{ lower $appVolumeValue.name }}: "{{ $appVolumeValue.payload.content | toJson |sha256sum }}"
  {{- end -}}

{{- end -}}

