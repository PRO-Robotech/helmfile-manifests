{{- define "appSpec.configMap.format.json" -}}

  {{- $appVolumeValue := $ -}}
  {{- $format         := lower $appVolumeValue.payload.format -}}

  {{- if eq $format "json" -}}
    {{- $appVolumeValue.name -}}: |-
    {{- $appVolumeValue.payload.content | toJson | nindent 2 -}}
  {{- end -}}

{{- end -}}

{{- define "appSpec.configMap.checksum.json" -}}

  {{- $appVolumeValue := $ -}}
  {{- $format         := lower $appVolumeValue.payload.format -}}
  
  {{- if eq $format "json" -}}
    checksum/configmap-{{ lower $appVolumeValue.name }}: "{{ $appVolumeValue.payload.content | toJson |sha256sum }}"
  {{- end -}}

{{- end -}}
