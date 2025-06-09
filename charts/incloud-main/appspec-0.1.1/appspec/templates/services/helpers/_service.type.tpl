{{- define "appSpec.service.type" -}}
  {{- $appValue := $ -}}
  {{- if hasKey $appValue "service" -}}
    {{- $serviceType := $appValue.service.type | default "ClusterIP" -}}
type: {{ $serviceType -}}
  {{- end -}}
{{- end -}}

{{- define "appSpec.service.type.name" -}}
  {{- $appValue := $ -}}
  {{- if hasKey $appValue "service" -}}
    {{- $serviceType := $appValue.service.type | default "ClusterIP" -}}
    {{- $serviceType -}}
  {{- end -}}
{{- end -}}
