{{- define "appSpec.service.annotations" -}}

  {{- $appValue := $ -}}

  {{- if hasKey $appValue "service" -}}
    {{- ($appValue.service.annotations | default dict) | toYaml  -}}
  {{- end -}}

{{- end -}}
