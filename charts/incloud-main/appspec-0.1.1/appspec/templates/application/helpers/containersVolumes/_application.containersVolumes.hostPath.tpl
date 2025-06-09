{{- define "appSpec.application.containersVolumes.hostpath" -}}

  {{- $volumeName   := index $ 0 -}}
  {{- $volumeValue  := index $ 1 -}}


  {{- if and (hasKey $volumeValue.volume "mode") (eq $volumeValue.volume.mode "hostPath") -}}
- name: {{ $volumeName | lower }}
  hostPath: 
    {{- $volumeValue.volume.spec | toYaml | nindent 4 }}
  {{- end -}}

{{- end -}}
