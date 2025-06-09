{{- define "appSpec.application.containersVolumes" -}}

  {{- $volumes      := index $ 0 -}}
  {{- $releaseName  := index $ 1 -}}
  {{- $appValue     := index $ 2 -}}

  {{- range $volumeName, $volumeValue := $volumes -}}
    {{- include "appSpec.application.containersVolume" (list $volumeName $volumeValue $releaseName $appValue ) | nindent 2 }}
  {{- end -}}

{{- end -}}

