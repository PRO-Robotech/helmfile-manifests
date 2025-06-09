{{- define "appSpec.application.containersVolumes.emptyDir" -}}

  {{- $volumeName   := index $ 0 -}}
  {{- $volumeValue  := index $ 1 -}}


  {{- if and (hasKey $volumeValue.volume "mode") (eq $volumeValue.volume.mode "emptyDir") -}}
- name: {{ $volumeName | lower }}
  emptyDir: 
    {{- $volumeValue.volume.spec | toYaml | nindent 4 }}
  {{- end -}}

{{- end -}}
