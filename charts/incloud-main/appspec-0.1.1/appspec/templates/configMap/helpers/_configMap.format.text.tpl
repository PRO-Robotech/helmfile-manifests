

{{- define "appSpec.configMap.format.text" -}}

  {{- $appVolumeValue := $ -}}
  {{- $format         := lower $appVolumeValue.payload.format -}}

  {{- if eq $format "text" -}}
    {{- $appVolumeValue.name -}}: |-
    {{- $appVolumeValue.payload.content | nindent 2 -}}
  {{- end -}}

{{- end -}}

{{- define "appSpec.configMap.checksum.text" -}}

  {{- $appVolumeValue := $ -}}
  {{- $format         := lower $appVolumeValue.payload.format -}}

  {{- if eq $format "text" -}}
    checksum/configmap-{{ lower $appVolumeValue.name }}: "{{ $appVolumeValue.payload.content |sha256sum }}"
  {{- end -}}

{{- end -}}
