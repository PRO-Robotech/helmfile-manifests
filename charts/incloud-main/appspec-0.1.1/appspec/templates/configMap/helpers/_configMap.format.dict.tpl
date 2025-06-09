{{- define "appSpec.configMap.format.dict" -}}

  {{- $appVolumeValue := $ -}}
  {{- $format         := lower $appVolumeValue.payload.format -}}

  {{- if eq $format "dict" -}}
    {{- range $key, $value := $appVolumeValue.payload.content -}}
      {{- $key -}}: {{- $value -}}
    {{- end -}}
  {{- end -}}

{{- end -}}
