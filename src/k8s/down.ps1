set-location $PSScriptRoot

& kubectl delete -f publisher-sidecar.yaml
& kubectl delete -f site-deploy.yaml

& kubectl delete -f publisher-svc.yaml
& kubectl delete -f site-svc.yaml

& kubectl delete -f site-pvc.yaml
& kubectl delete -f workspace-pvc.yaml
& kubectl delete -f drops-pvc.yaml

& kubectl delete -f site-pv.yaml
& kubectl delete -f workspace-pv.yaml
& kubectl delete -f drops-pv.yaml
