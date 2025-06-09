{{- define "appSpec.application.containersVolume" -}}

  {{- $volumeName   := index $ 0 -}}
  {{- $volumeValue  := index $ 1 -}}
  {{- $releaseName  := index $ 2 -}}
  {{- $appValue     := index $ 3 -}}

  {{- include "appSpec.application.containersVolumes.hostpath"    (list $volumeName $volumeValue) -}}
  {{- include "appSpec.application.containersVolumes.emptyDir"    (list $volumeName $volumeValue) -}}
  {{- include "appSpec.application.containersVolumes.pvc"         (list $volumeName $volumeValue) -}}
  {{- include "appSpec.application.containersVolumes.secret"      (list $volumeName $volumeValue $releaseName) -}}

  {{- if eq (include "appSpec.configMap.status" $appValue) "true" -}}
    {{- include "appSpec.application.containersVolumes.configMap" (list $volumeName $volumeValue $releaseName) -}}
  {{- end -}}

{{- end -}}
