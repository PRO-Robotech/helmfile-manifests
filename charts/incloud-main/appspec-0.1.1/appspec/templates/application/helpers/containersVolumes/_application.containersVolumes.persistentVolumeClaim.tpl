{{- define "appSpec.application.containersVolumes.pvc" -}}

  {{- $volumeName   := index $ 0 -}}
  {{- $volumeValue  := index $ 1 -}}


  {{- if and (hasKey $volumeValue.volume "mode") (eq $volumeValue.volume.mode "pvc") -}}
- name: {{ $volumeName | lower }}
  pvc: 
    {{- $volumeValue.volume.spec | toYaml | nindent 4 }}
  {{- end -}}

{{- end -}}
