set-location $PSScriptRoot

& kubectl apply -f drops-pv.yaml
& kubectl apply -f workspace-pv.yaml
& kubectl apply -f site-pv.yaml

& kubectl apply -f drops-pvc.yaml
& kubectl apply -f workspace-pvc.yaml
& kubectl apply -f site-pvc.yaml

& kubectl apply -f site-svc.yaml
& kubectl apply -f publisher-svc.yaml

& kubectl apply -f site-deploy.yaml
& kubectl apply -f publisher-sidecar.yaml