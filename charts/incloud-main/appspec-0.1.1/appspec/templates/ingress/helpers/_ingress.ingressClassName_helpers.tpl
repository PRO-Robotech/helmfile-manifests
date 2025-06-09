{{- define "appSpec.ingress.ingressClassName" -}}

  {{- $appValue := $ -}}

  {{- if hasKey $appValue "ingress" -}}
    {{- $ingressClassName := $appValue.service.ingressClassName | default "nil" -}}
    {{- if ne $ingressClassName "nil" -}}
ingressClassName: {{ $ingressClassName -}}
    {{- end -}}

  {{- end -}}
{{- end -}}
