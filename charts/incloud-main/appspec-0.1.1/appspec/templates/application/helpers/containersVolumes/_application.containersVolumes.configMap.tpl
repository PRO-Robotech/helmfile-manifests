{{- define "appSpec.application.containersVolumes.configMap" -}}

  {{- $volumeName   := index $ 0 -}}
  {{- $volumeValue  := index $ 1 -}}
  {{- $releaseName  := index $ 2 -}}

  {{- if and (hasKey $volumeValue.volume "mode") (eq $volumeValue.volume.mode "configMap") -}}
- name: {{ $volumeName | lower }}
  configMap: 
    {{- if $volumeValue.volume.notReleased | default false }} # внешний от релиза ресурс
    name: {{ $volumeValue.volume.name }}
    {{- else }}
    name: {{ $releaseName }}-{{ $volumeValue.volume.name }}
    {{- end }}
    {{- with  $volumeValue.volume.spec  }}
      {{- . | toYaml | nindent 6 }}
    {{- end }}
  {{- end -}}

{{- end -}}
