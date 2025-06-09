{{- define "appSpec.service.ports" -}}

  {{- $appValue := $ -}}
ports:
  {{- range $containerName, $containerValue := $appValue.containers }}
    {{- range $portName, $portValue := $containerValue.extraPorts }}
      {{- $portNameLower := lower $portName }}
- name: {{ if eq $portNameLower "ingress" }}ingress{{- else }}{{ $containerValue.name }}-{{ $portName }}{{- end }}
  port: {{ $portValue.containerPort }}
  targetPort: {{ $portValue.containerPort }}
  protocol: {{ $portValue.protocol }}
    {{- end }}
  {{- end }}
{{- end -}}

{{- define "appSpec.service.ingress.status" -}}

  {{- $appValue := $ -}}
  {{- $ingressServiceStatus := false -}}

  {{- range $containerName, $containerValue := $appValue.containers -}}
    {{- range $portName, $portValue := $containerValue.extraPorts -}}
      {{- $portNameLower := lower $portName -}}
      {{- if eq $portNameLower "ingress" -}}
        {{- $ingressServiceStatus = true -}}
      {{- end -}}
    {{- end -}}
  {{- end -}}

  {{-  $ingressServiceStatus -}}

{{- end -}}

