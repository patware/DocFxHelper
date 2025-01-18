set-location $PSScriptRoot

& kubectl delete -f publisher-sidecar-deploy.yaml
& kubectl delete -f site-deploy.yaml

& kubectl delete -f publisher-svc.yaml
& kubectl delete -f site-svc.yaml

& kubectl delete -f site-site-pvc.yaml
& kubectl delete -f publisher-site-pvc.yaml
& kubectl delete -f workspace-pvc.yaml
& kubectl delete -f drops-pvc.yaml

& kubectl delete -f site-site-pv.yaml
& kubectl delete -f publisher-site-pv.yaml
& kubectl delete -f workspace-pv.yaml
& kubectl delete -f drops-pv.yaml

Write-Host "What's left?"
& kubectl get all