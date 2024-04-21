# k8s README

## To start

```bash

# kubectl apply -f local-sc.yaml

cd src
docker build -f site.dockerfile -t site:local .
docker build -f publisher.dockerfile -t publisher:local .

cd k8s
kubectl apply -f drops-pv.yaml
kubectl apply -f workspace-pv.yaml
kubectl apply -f site-pv.yaml

kubectl apply -f drops-pvc.yaml
kubectl apply -f workspace-pvc.yaml
kubectl apply -f site-pvc.yaml

kubectl apply -f site-svc.yaml
kubectl apply -f publisher-svc.yaml

kubectl apply -f site-deploy.yaml
kubectl apply -f publisher-sidecar.yaml

```

## To get list

```bash

kubectl get sc
kubectl get pv
kubectl get pvc
kubectl get deploy
kubectl get svc

```

## To delete

```bash
kubectl delete -f publisher-deploy.yaml
kubectl delete -f site-deploy.yaml

kubectl delete -f site-svc.yaml

kubectl delete -f site-pvc.yaml
kubectl delete -f workspace-pvc.yaml
kubectl delete -f drops-pvc.yaml


kubectl delete -f site-pv.yaml
kubectl delete -f workspace-pv.yaml
kubectl delete -f drops-pv.yaml

kubectl delete -f local-sc.yaml
```