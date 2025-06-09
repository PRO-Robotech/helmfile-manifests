{{- define "appSpec.service.status" -}}

  {{- $appValue         := $     -}}
  {{- $serviceStatus    := false -}}
  {{- $appEnabled       := false -}}
  {{- $serviceEnabled   := false -}}
  {{- $servicePortExist := false -}}

  {{- range $containerName, $containerValue := $appValue.containers -}}
    {{- if hasKey $containerValue "extraPorts" -}}
      {{- range $portName, $portValue := $containerValue.extraPorts -}}
        {{- $servicePortExist = true -}}
      {{- end -}}
    {{- end -}}
  {{- end -}}

  {{- if hasKey $appValue "service" -}}
    {{- $serviceEnabled = $appValue.service.enabled -}}
  {{- end -}}

  {{- $appEnabled = $appValue.enabled -}}

  {{- if and ($appEnabled) ($serviceEnabled) ($servicePortExist) }}
    {{- $serviceStatus = true -}}
  {{- end -}}

  {{- $serviceStatus -}}

{{- end -}}
