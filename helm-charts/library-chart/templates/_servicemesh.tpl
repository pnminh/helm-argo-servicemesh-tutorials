{{- define "library-chart.enableServiceMesh" -}}
{{- $root := .root -}}
{{- $serviceMesh := .serviceMesh -}}
{{- if not .root.Values.namespaceLabels }}
{{- $_ := set .root.Values "namespaceLabels" (dict) -}}
{{- end }}
{{- $_ := set .root.Values.namespaceLabels "istio-injection" "enabled" -}}
{{- if $serviceMesh.service }}
    {{- $serviceName := $serviceMesh.service.name | default $root.Release.Name }}
    {{- $resourceName := $root.Release.Name -}}
    {{- $meshService := merge $serviceMesh.service (dict "resourceName" $resourceName "serviceName" $serviceName  )}}
    {{- include "library-chart.enableServiceMeshItems" $meshService }}
{{- end }}
{{- $meshServices := list }}
{{- if $serviceMesh.services }}
{{- $meshServices = concat $meshServices $serviceMesh.services -}}
{{- end }}
{{- if $serviceMesh.otherServices }}
{{- $meshServices = concat $meshServices $serviceMesh.otherServices -}}
{{- end }}
{{- range  $index, $meshService := $meshServices }}
    {{- $resourceName := printf "%s-%s" $root.Release.Name $meshService.name -}}
    {{- $meshService := merge $meshService (dict "resourceName" $resourceName )}}
    {{- include "library-chart.enableServiceMeshItems" $meshService }}
{{- end }}
{{- end }}

{{- define "library-chart.enableServiceMeshItems" -}}
    {{- $meshService := . -}}    
    {{- include "library-chart.createVirtualService" $meshService }}
    {{- include "library-chart.createDestinationRule" $meshService }}
    {{- include "library-chart.createServiceEntry" $meshService }}
{{- end }}


{{- define "library-chart.disableServiceMesh" -}}
{{- if not .root.Values.namespaceLabelsToRemove }}
{{- $_ := set .root.Values "namespaceLabelsToRemove" (list) -}}
{{- end }}
{{- $updatedList := append .root.Values.namespaceLabelsToRemove "istio-injection" -}}
{{- $_ := set .root.Values "namespaceLabelsToRemove" $updatedList -}}
{{- end }}