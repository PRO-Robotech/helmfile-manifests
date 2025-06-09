{{- define "appSpec.configMap.status" -}}

  {{- $appValue         := $     -}}
  {{- $appEnabled       := false -}}
  {{- $volumesExist     := false -}}
  {{- $configMapStatus  := false -}}

  {{- $appEnabled   = $appValue.enabled -}}

  {{- if hasKey $appValue "volumes" -}}
    {{- $volumesExist = true -}}
  {{- end -}}

  {{- if and ($appEnabled) ($volumesExist) -}}
    {{- $configMapStatus = true -}}
  {{- end -}}

{{- $configMapStatus -}}

{{- end -}}


{{- define "appSpec.configMap.volume.status" -}}

  {{- $volumeValue      := $     -}}
  {{- $volumeStruct     := false -}}
  {{- $volumeStatus     := false -}}

  {{- $volumeStruct = (and 
    (hasKey $volumeValue "volume") 
    (hasKey $volumeValue.volume "mode") 
    (hasKey $volumeValue.volume "name") 
    (hasKey $volumeValue.volume "payload"))
  -}}

  {{- if $volumeStruct }}
    {{- $volumeStatus = true -}}
  {{- end -}}

{{- $volumeStatus -}}

{{- end -}}
