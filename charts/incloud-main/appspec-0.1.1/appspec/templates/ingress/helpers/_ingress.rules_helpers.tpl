{{- define "appSpec.ingress.rules" -}}

  {{- $appName     := index $ 0 -}}
  {{- $appValue    := index $ 1 -}}
  {{- $globalValue := index $ 2 -}}
rules:
  {{- if hasKey $appValue "ingress" -}}
    {{- range $hostName, $hostValue := $appValue.ingress.hosts | default list }}
- host: {{ $hostName }}
  http:
    paths:
      {{- range $path, $pathValue := $hostValue.paths }}
      - path: {{ $path }}
        pathType: {{ $pathValue.pathType | default "Prefix" }}
        backend:
          service:
            name: {{ $globalValue.Release.Name }}-{{ $appName }}
            port:
              name: ingress
      {{- end }}
    {{- end -}}
  {{- end -}}
{{- end -}}
