{{- define "appSpec.service.loadBalancerIP" -}}
  {{- $appValue := $ -}}
  {{- if hasKey $appValue "service" -}}
    {{- $loadBalancerIP := $appValue.service.loadBalancerIP | default "nil" -}}
    {{- if ne $loadBalancerIP "nil" -}}
loadBalancerIP: {{ $loadBalancerIP -}}
    {{- end -}}
  {{- end -}}
{{- end -}}

{{- define "appSpec.service.clusterIP" -}}
  {{- $appValue := $ -}}
  {{- if hasKey $appValue "service" -}}
    {{- $clusterIP := $appValue.service.clusterIP | default "nil" -}}
    {{- if ne $clusterIP "nil" -}}
clusterIP: {{ $clusterIP -}}
    {{- end -}}
  {{- end -}}
{{- end -}}
