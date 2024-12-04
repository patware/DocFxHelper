# k8s README

Running DocFxHelper site and publisher in a local Docker Destkop Kubernetes.

You'll need Docker Destkop, Kubernetes enabled.

## Starting the deployment

From this folder.

```powershell

cd ..
& docker build -f site.dockerfile -t docs:local .
& docker build -f publisher.dockerfile -t publisher:local .

cd k8s.local

. .\up.ps1
```

See DocFxHelper in action:

| web | link |
| --- | --- |
| site | [localhost:8085](http://localhost:8085/) |
| publisher | [localhost:8086](http://localhost:8086/) |

To get the details of the publisher pod:

```powershell
& kubectl describe (& kubectl get pod -l app=docfxhelper -l tier=publisher --output name)
```

To see the logs from the publisher-job

```powershell
# publisher-site
& kubectl logs -l app=docfxhelper -l tier=publisher

# publisher-job
& kubectl logs -l app=docfxhelper -l tier=publisher --container publisher-job --follow
```

## To get list of objects

```bash

kubectl get pv
kubectl get pvc
kubectl get deploy
kubectl get svc

```

## To delete

From this folder,

```powershell
. .\down.ps1
```
