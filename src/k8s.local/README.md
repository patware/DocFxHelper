# k8s README

## To start

```powershell

cd src
& docker build -f site.dockerfile -t site:local .
& docker build -f publisher.dockerfile -t publisher:local .

cd k8s

. .\up.ps1
```

See DocFxHelper in action:

| web | link |
| --- | --- |
| site | [localhost:8085](https://localhost:8085/) |
| publisher | [localhost:8086](https://localhost:8086/) |

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

## To get list

```bash

kubectl get sc
kubectl get pv
kubectl get pvc
kubectl get deploy
kubectl get svc

```

## To delete

```powershell
cd src/k8s
. .\down.ps1
```
