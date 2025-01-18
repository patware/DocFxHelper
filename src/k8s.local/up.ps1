set-location $PSScriptRoot

Write-Host "Persistent Volumes"
& kubectl apply -f drops-pv.yaml
& kubectl apply -f workspace-pv.yaml
& kubectl apply -f site-site-pv.yaml
& kubectl apply -f publisher-site-pv.yaml

& kubectl get pv -L app -L tier -L type

Write-Host "Persistent Volume Claims"
& kubectl apply -f drops-pvc.yaml
& kubectl apply -f workspace-pvc.yaml
& kubectl apply -f site-site-pvc.yaml
& kubectl apply -f publisher-site-pvc.yaml

& kubectl get pvc -L app -L tier -L type
<#
  & kubectl describe -f drops-pvc.yaml
  & kubectl describe -f workspace-pvc.yaml
  & kubectl describe -f site-site-pvc.yaml
  & kubectl describe -f publisher-site-pvc.yaml
#>

Write-Host "Services"
& kubectl apply -f site-svc.yaml
& kubectl apply -f publisher-svc.yaml

& kubectl get svc -L app -L tier

Write-Host "Deployments"
& kubectl apply -f site-deploy.yaml
& kubectl apply -f publisher-sidecar-deploy.yaml

& kubectl get deploy -L app -L tier