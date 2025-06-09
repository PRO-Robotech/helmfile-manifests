{{- define "appSpec.application.containersVolumes.secret" -}}

  {{- $volumeName   := index $ 0 -}}
  {{- $volumeValue  := index $ 1 -}}
  {{- $releaseName  := index $ 2 -}}

  {{- if and (hasKey $volumeValue.volume "mode") (eq $volumeValue.volume.mode "secret") -}}
- name: {{ $volumeName | lower }}
  secret:
    secretName: {{ $releaseName }}-{{ $volumeValue.volume.name }}
  {{- end -}}

{{- end -}}
