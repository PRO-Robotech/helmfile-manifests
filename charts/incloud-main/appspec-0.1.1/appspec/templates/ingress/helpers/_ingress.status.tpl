{{- define "appSpec.ingress.status" -}}

  {{- $appValue := $ -}}
  {{- $ingressStatus          := false -}}
  {{- $serviceIngressStatus   := false -}}
  {{- $appEnabled             := false -}}
  {{- $serviceStatus          := false -}}
  {{- $ingressEnabled         := false -}}

  {{- if hasKey $appValue "ingress" -}}
    {{- $ingressEnabled = $appValue.ingress.enabled -}}
  {{- end -}}

  {{- $appEnabled = $appValue.enabled -}}

  {{- $serviceStatus        = (eq (include "appSpec.service.status"         $appValue) "true") -}}
  {{- $serviceIngressStatus = (eq (include "appSpec.service.ingress.status" $appValue) "true") -}}
  
  {{- if and ($serviceStatus) ($ingressEnabled) ($appEnabled) ($serviceIngressStatus) }}
    {{- $ingressStatus = true -}}
  {{- end -}}

{{- $ingressStatus -}}

{{- end -}}
