{{- define "pedidos.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/* Labels recomendados pelo Kubernetes (app.kubernetes.io/*). Ferramentas como
     ArgoCD, kubectl e dashboards usam essas chaves para agrupar recursos. */}}
{{- define "pedidos.labels" -}}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" }}
app.kubernetes.io/name: {{ include "pedidos.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: pedidos
{{- end -}}

{{/* selectorLabels: subconjunto IMUTÁVEL. O selector de um Deployment não pode mudar
     depois de criado, então nunca inclua aqui version/chart. */}}
{{- define "pedidos.selectorLabels" -}}
app.kubernetes.io/name: {{ include "pedidos.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "pedidos.databaseUrl" -}}
postgres://{{ .Values.postgres.username }}:$(POSTGRES_PASSWORD)@{{ .Release.Name }}-postgres:5432/{{ .Values.postgres.database }}?sslmode=disable
{{- end -}}

{{- define "pedidos.amqpUrl" -}}
amqp://{{ .Values.rabbitmq.username }}:$(RABBITMQ_PASSWORD)@{{ .Release.Name }}-rabbitmq:5672/
{{- end -}}
