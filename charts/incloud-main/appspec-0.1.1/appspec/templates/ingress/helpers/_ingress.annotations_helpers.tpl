{{- define "appSpec.ingress.annotations" -}}

  {{- $appValue := $ -}}

  {{- if hasKey $appValue "ingress" -}}
    {{- ($appValue.ingress.annotations | default dict) | toYaml  -}}
  {{- end -}}

{{- end -}}
