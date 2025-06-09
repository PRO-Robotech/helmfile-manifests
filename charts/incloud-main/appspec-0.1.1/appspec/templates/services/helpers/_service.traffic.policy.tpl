{{- define "appSpec.service.externalTrafficPolicy" -}}

  {{- $appValue := $ -}}

  {{- if hasKey $appValue "service" -}}
    {{- $externalTrafficPolicy := $appValue.service.externalTrafficPolicy | default "Cluster" -}}
externalTrafficPolicy: {{ $externalTrafficPolicy -}}
  {{- end -}}

{{- end -}}

{{- define "appSpec.service.internalTrafficPolicy" -}}

  {{- $appValue := $ -}}

  {{- if hasKey $appValue "service" -}}
    {{- $internalTrafficPolicy := $appValue.service.internalTrafficPolicy | default "Cluster" -}}
internalTrafficPolicy: {{ $internalTrafficPolicy -}}
  {{- end -}}

{{- end -}}
