{{- define "appSpec.application.annotations" -}}

  {{- $appValue := index $ 0 -}}

  {{- if eq (include "appSpec.configMap.status" $appValue) "true" -}}
    {{- range $volumeName, $volumeValue := $appValue.volumes -}}
      {{- if eq $volumeValue.volume.mode "configMap" -}}
        {{- include "appSpec.configMap.checksum.yaml" $volumeValue.volume | nindent 0 }}
        {{- include "appSpec.configMap.checksum.json" $volumeValue.volume | nindent 0 }}
        {{- include "appSpec.configMap.checksum.text" $volumeValue.volume | nindent 0 }}
      {{- end -}}
    {{- end -}}
  {{- end -}}

{{- end -}}
