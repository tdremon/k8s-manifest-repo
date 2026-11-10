{{- /*
  _helpers.tpl : 이름이 붙은 템플릿(define)을 모아 두는 파일.
  파일 이름이 `_` 로 시작하면 Helm 이 이 파일을 "리소스"로 렌더링하지 않는다. 다른 템플릿에서 include 로 불러 쓰기만 한다.
  읽는 법: templates/*.yaml 에서 `{{ include "pytorch-infer.xxx" . }}` 를 보면 여기서 같은 이름의 define 을 찾는다.
*/ -}}

{{- /* 앱 이름. chart 이름이 기본이고 nameOverride 로 바꿀 수 있다. 라벨 `app` 의 값으로 쓰인다 */ -}}
{{- define "pytorch-infer.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- /*
  리소스 이름(Deployment, Service 등). 규칙:
    1) fullnameOverride 가 있으면 그대로
    2) release 이름에 chart 이름이 이미 들어 있으면 release 이름만 (release=pytorch-infer -> "pytorch-infer")
    3) 아니면 "<release>-<chart>"  (release=demo -> "demo-pytorch-infer")
  trunc 63: K8S 이름(DNS label)의 길이 제한
*/ -}}
{{- define "pytorch-infer.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{- /* chart 이름-버전. 라벨 helm.sh/chart 에 쓴다 ("+" 는 라벨 값에 쓸 수 없어 "_" 로 바꾼다) */ -}}
{{- define "pytorch-infer.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- /*
  selector 에 쓰는 라벨. 두 가지를 반드시 기억한다.
    1) Deployment 의 spec.selector 는 만든 뒤 바꿀 수 없다(불변). 이 define 을 고치면 helm upgrade 가 실패한다.
       그래서 selector 에는 "절대 안 변하는 값"만 넣는다(version, chart 버전 같은 값은 넣지 않는다).
    2) Service, PDB, ServiceMonitor 의 selector 도 이 define 을 같이 쓴다. 파드 라벨과 어긋나면 트래픽/수집이 끊긴다.
  `app` 은 기존 k8s/manifests 가 쓰던 라벨이라 그대로 유지한다. instance 가 있어야 같은 네임스페이스의 다른 release 와 섞이지 않는다.
*/ -}}
{{- define "pytorch-infer.selectorLabels" -}}
app: {{ include "pytorch-infer.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{- /* 모든 리소스의 metadata.labels. 조회/분류용이므로 바뀌어도 되는 값(버전 등)을 넣는다 */ -}}
{{- define "pytorch-infer.labels" -}}
helm.sh/chart: {{ include "pytorch-infer.chart" . }}
{{ include "pytorch-infer.selectorLabels" . }}
app.kubernetes.io/name: {{ include "pytorch-infer.name" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- /* ServiceAccount 이름. create=true 면 fullname(또는 지정 이름), false 면 지정 이름(없으면 default) */ -}}
{{- define "pytorch-infer.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "pytorch-infer.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{- /* ConfigMap 이름. Deployment(envFrom, checksum)와 configmap.yaml 이 같은 이름을 쓰도록 한 곳에서 정의한다 */ -}}
{{- define "pytorch-infer.configMapName" -}}
{{- printf "%s-config" (include "pytorch-infer.fullname" .) }}
{{- end }}

{{- /*
  ---- Redis (redis.enabled=true 일 때만 쓰는 이름들) ----
  Redis 이름: "<앱 fullname>-redis". release=pytorch-infer 면 "pytorch-infer-redis" 가 되어 같은 네임스페이스의 앱이
  이 이름(Service DNS)으로 접속한다. configmap.yaml 의 REDIS_HOST 와 redis-service.yaml 이 같은 이름을 쓰도록 한 곳에서 정의한다.
  (기존 k8s/manifests 는 이름이 "redis" 였다. 같은 네임스페이스에서 release 가 둘이면 이름이 겹치지 않게 release 이름을 따라간다)
*/ -}}
{{- define "pytorch-infer.redis.fullname" -}}
{{- printf "%s-redis" (include "pytorch-infer.fullname" .) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- /*
  Redis selector 라벨. 앱의 selectorLabels(app: pytorch-infer)와 값이 달라야 한다.
  같으면 앱 Service 가 Redis 파드를 대상으로 잡고, 앱 PDB·Deployment 도 Redis 파드를 자기 것으로 센다.
  앱과 마찬가지로 selector 는 만든 뒤 바꿀 수 없으므로 "절대 안 변하는 값"만 넣는다.
*/ -}}
{{- define "pytorch-infer.redis.selectorLabels" -}}
app: redis
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{- define "pytorch-infer.redis.labels" -}}
helm.sh/chart: {{ include "pytorch-infer.chart" . }}
{{ include "pytorch-infer.redis.selectorLabels" . }}
app.kubernetes.io/name: redis
app.kubernetes.io/component: cache
app.kubernetes.io/version: {{ .Values.redis.image.tag | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}
