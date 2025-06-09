{{- define "appSpec.service.sessionAffinity" -}}

  {{- $appValue := $ -}}

  {{- if hasKey $appValue "service" -}}
    {{- $sessionAffinity := $appValue.service.sessionAffinity | default "None" -}}
sessionAffinity: {{ $sessionAffinity -}}
  {{- end -}}

{{- end -}}
