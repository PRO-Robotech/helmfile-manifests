{{- define "appSpec.ingress.tls" -}}

  {{- $appName     := index $ 0 -}}
  {{- $appValue    := index $ 1 -}}
  {{- $globalValue := index $ 2 -}}
tls:
  {{- if hasKey $appValue "ingress" -}}
    {{- range $hostName, $hostValue := $appValue.ingress.hosts | default list }}
    {{- if hasKey $hostValue "tls" }}
- hosts:
    - {{ $hostName }}
  secretName: "{{ $globalValue.Release.Name }}-{{ $hostValue.tls.secretName }}"
    {{- end }}
    {{- end }}
  {{- end -}}
{{- end -}}
