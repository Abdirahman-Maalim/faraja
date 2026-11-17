{{- define "faraja.image" -}}
{{- $reg := .root.Values.imageRegistry -}}
{{- if $reg -}}{{ $reg }}/{{- end -}}{{ .image.repository }}:{{ .image.tag }}
{{- end -}}

{{- define "faraja.commonLabels" -}}
team: {{ .Values.team }}
project: {{ .Values.project }}
{{- end -}}
