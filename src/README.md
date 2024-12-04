# README

DocFxHelper converts and integrates various resources types into a format that DocFx can work with.

The resource types are: Ado Wiki, dotnet class library, REST api, PowerShell module and classic docfx conceptual sites.

Each resource type requires a json specification file (specs.docs.json) that contains the instructions DocFxHelper needs to convert the resources into a format and structure that DocFx requires, and to build the proper hierarchy (parent-child relationship).

| Type             | Name                          | Resource files                                           |
|------------------|-------------------------------|----------------------------------------------------------|
| Main             | Start/Initializer             | Docfx files like docfx.json and templates                |
| AdoWiki          | Azure DevOps Wiki files       | ADO Wiki files                                           |
| DotnetApi        | .net class library            | compiled (.dll) with SourceLink                          |
| RestApi          | Swagger doc                   | [untested]                                               |
| PowershellModule | PowerShell Module             | Source code (psm1, psd1, ps1)                            |
| Conceptual       | Classic Docfx conceptual site | All md, yaml, and media files, the docfx.json is ignored |

## Specs.docs.json

Each resource is defined in a json file (specs.docs.json) and contains properties that are unique to each.

Here's a table of mapping properties and resource type:

| Property           | Type       | Default Value           | Main     | AdoWiki  | DotnetApi | RestApi  | PowershellModule | Conceptual |
|--------------------|------------|-------------------------|----------|----------|-----------|----------|------------------|------------|
| Id                 | string     |                         | No       | Required | Required  | Required | Required         | Required   |
| Templates          | Template[] |                         | Optional | Optional | Optional  | Optional | Optional         | Optional   |
| Name               | string     | {MenuDisplayName}, {Id} | No       | Optional | Optional  | Optional | Required         | Optional   |
| ParentId           | string     |                         | No       | Optional | Optional  | Optional | Optional         | Optional   |
| Target             | string     | /                       | No       | Optional | Optional  | Optional | Optional         | Optional   |
| IsRoot             | bool       | false                   | No       | Optional | Optional  | Optional | Optional         | Optional   |
| CloneUrl           | URI        |                         | No       | Required | Required  | Required | Required         | Required   |
| MenuParentItemName | string     |                         | No       | Optional | Optional  | Optional | Optional         | Optional   |
| MenuDisplayName    | string     |                         | No       | Optional | Optional  | Optional | Optional         | Optional   |
| MenuPosition       | int        | -1                      | No       | Optional | Optional  | Optional | Optional         | Optional   |
| Homepage           | string     |                         | No       | Optional | Optional  | Optional | Optional         | Optional   |
| MenuUid            | string     |                         | No       | Optional | Optional  | Optional | Optional         | Optional   |
| RepoRelativePath   | string     |                         | No       | Optional | Optional  | Optional | Optional         | Optional   |
| Branch             | string     | main                    | No       | Optional | Optional  | Optional | Optional         | Optional   |
| Excludes           | string     |                         | No       | Optional | Optional  | Optional | Optional         | Optional   |
| Medias             | string     |                         | No       | Optional | Optional  | Optional | Optional         | Optional   |
| DocFx_Json         | string     |                         | Optional | No       | No        | No       | No               | No         |
| WikiUrl            | URI        |                         | No       | Required | No        | No       | No               | No         |
| Psd1               | string     | {Name}.[psd1]           | No       | No       | No        | No       | Optional         | No         |

## Setup DocFxHelper

DocFxHelper script works with 3 folders:

| Name          | Usage                                                  |
|---------------|--------------------------------------------------------|
| Drops         | Where each resource will drop their pipeline artifacts |
| Workspace     | DocFxHelper's working folder                           |
| Site          | The DocFx generated site                               |
| PublisherSite | The DocFxHelper Publisher site                         |
| PublisherLogs | The DocFxHelper Publisher logs                         |

Note: Tested with the following setup

- workstation: Windows, with WSL and Docker for Desktop
  - WSL: Ubuntu
  - Docker for Destkop: WSL Integration enabled
    - Distribution: Ubuntu

| Folder        | Windows                          | WSL - Ubuntu                         |
|---------------|----------------------------------|--------------------------------------|
| Drops         | C:\dev\temp\Docs\drops         | /mnt/c/dev/docfxhelper/Drops         |
| Workspace     | C:\dev\temp\Docs\workspace     | /mnt/c/dev/docfxhelper/Workspace     |
| Site          | C:\dev\temp\Docs\site          | /mnt/c/dev/docfxhelper/Site          |
| publishersite | C:\dev\temp\Docs\publishersite | /mnt/c/dev/docfxhelper/publishersite |
| publisherlogs | C:\dev\temp\Docs\publisherlogs | /mnt/c/dev/docfxhelper/publisherlogs |

Note: Tested with the following resources

| Name             | Spec Type        | Content                                       |
|------------------|------------------|-----------------------------------------------|
| MainDocs         | Main             | docfx.json, custom docfx template             |
| WikiMain         | AdoWiki          | copy of git repo, excluding .git folder       |
| WikiChild        | AdoWiki          | copy of git repo, excluding .git folder       |
| SimpleConceptual | Conceptual       | md and toc.yml files                          |
| myDotNetApi      | DotnetApi        | library compiled files (dll, pdb, xml)        |
| myPSModule       | PowershellModule | all PowerShell source files (psd1, psm1, ps1) |

### Windows

Run publisher.ps1 from the folder where the 5 docfxhelper folders are located, and when it's finished, run docfx serve to run the web site.

Install the prerequisites.

- PowerShell recent (7.0 and above, currently running 7.4.2)
- PowerShell modules:
  - PlatyPS
  - Posh-git
  - Poshstache
  - yayaml
- dotnet recent (8.0 and above, currently running 8.0.4)
- dotnet tools:
  - docfx recent (2.75 and above, currently running 2.75.1)

```powershell
set-location c:\dev\docfxhelper
. ..\github\Patware\DocFxHelper\src\publisher.ps1
docfx serve site
```

### WSL

Tested on WSL Ubuntu 22.04.4

Install the prerequisites

- apt
  - rsync
  - diff
- PowerShell recent (7.0 and above, currently running 7.4.2)
- PowerShell modules:
  - PlatyPS
  - Posh-git
  - Poshstache
  - yayaml
- dotnet recent (8.0 and above, currently running 8.0.4)
- dotnet tools:
  - docfx recent (2.75 and above, currently running 2.75.1)

Run publisher.ps1 from the folder where the 5 docfxhelper folders are located, and when it's finished, run docfx serve to run the web site.

```powershell
set-location /mnt/c/dev/docfxhelper
. ../github/Patware/DocFxHelper/src/publisher.ps1
docfx serve site
```

### docker

Prerequisites, Docker Desktop, enable WSL Integration with Ubuntu

From Ubuntu (WSL), this src folder.

Build the docker images:

```bash
docker build -f publisher.dockerfile -t publisher:local .
docker build -f docs.dockerfile -t docs:local .
```

Note, when you build the docker images, if you want the whole build logs to show, pass the --progress=plain argument.

```bash
docker build -f publisher.dockerfile -t publisher:local --progress=plain .
docker build -f docs.dockerfile -t docs:local --progress=plain .
```

#### With 1 volume

Create the volume

```bash
docker volume create --opt type=none --opt o=bind --opt device=/mnt/c/dev/docfxhelper docfxhelper

docker volume ls --format "table {{.Name}}\t{{.Mountpoint}}\t{{.Labels}}"
```

Run the docker containers

```bash
docker run -it -d --volume docfxhelper:/docfxhelper publisher:local
docker run -it -d --volume site:/usr/share/nginx/html/ -p 8083:80 -e "NGINX_PORT=80" docs:local
```

Now, browse to [http://localhost:8083/](http://localhost:8083/)

#### Create individual volumes

Create the volumes

```bash
docker volume create --opt type=none --opt o=bind --opt device=/mnt/c/dev/docfxhelper/Drops drops
docker volume create --opt type=none --opt o=bind --opt device=/mnt/c/dev/docfxhelper/Workspace workspace
docker volume create --opt type=none --opt o=bind --opt device=/mnt/c/dev/docfxhelper/Site site
docker volume create --opt type=none --opt o=bind --opt device=/mnt/c/dev/docfxhelper/publishersite publishersite
docker volume create --opt type=none --opt o=bind --opt device=/mnt/c/dev/docfxhelper/publisherlogs publisherlogs

docker volume ls --format "table {{.Name}}\t{{.Mountpoint}}\t{{.Labels}}"
```

Run the docker containers

```bash
docker run -it -d --volume drops:/docfxhelper/drops --volume workspace:/docfxhelper/workspace --volume site:/docfxhelper/site --volume publishersite:/docfxhelper/publishersite --volume publisherlogs:/docfxhelper/publisherlogs publisher:local
docker run -it -d --volume site:/usr/share/nginx/html/ -p 8083:80 -e "NGINX_PORT=80" docs:local
```

Now, browse to [http://localhost:8083/](http://localhost:8083/)

### docker-compose

Prerequisites, Docker Desktop, enable WSL Integration with Ubuntu

From Ubuntu (WSL), this src folder, build the docker images:

```bash
docker build -f publisher.dockerfile -t publisher:local .
docker build -f docs.dockerfile -t docs:local .
```

Start docker compose

```bash
docker-compose --file docker.compose.yml --project-name docfxhelper up --detach
```

Now, browse to [http://localhost:8084/](http://localhost:8084/)

### Kubernetes

Local kubernetes, see [k8s.local](./k8s.local/README.md) README.

## Using DocFxHelper

With DocFxHelper running, all that is left to do is to drop your specs in the Drops\{SpecName}\ folder.

## Example scenario

To help you figure out where to put what, here's a scenario that supports the 4 resources types.

The target Acme Technical Documentation site will have the following site map:

- Products
  - Acme WinApp
- APIs
  - Acme Api
- PowerShell Modules
  - Acme Lorem
- Blogs

The site map above, with file names, their source and the relative link back to their source

| file                             | Source      | relative link to source |
|----------------------------------|-------------|-------------------------|
| ./products.md                    | Acme.Wiki   | ./products.md           |
| ./products/Acme.WinApp/*         | Acme.WinApp | ./docs/Acme.WinApp/*    |
| ./apis.md                        | Acme.Wiki   | ./apis.md               |
| ./apis/Acme.Api/*                | Acme.Api    | ./src/{code}            |
| ./powershellModules.md           | Acme.Wiki   | ./powershellModules.md  |
| ./powershellModules/Acme.Lorem/* | Acme.Lorem  | ./src/{code}            |
| ./blogs.md                       | Acme.Wiki   | ./blogs.md              |
| ./blogs/*                        | Acme.Wiki   | ./blogs/*               |

Details on the Sources above:

- [Acme.TechDocs](#acmetechdocs): A git repo that bootstraps the whole site
- [Acme.Wiki](#acmewiki): An ADO wiki of type git repo
- [Acme.Api](#acmeapi): A git repo for an API
- [Acme.WinApp](#acmewinapp): A git repo for an app which contains also DocFx conceptual docs
- [Acme.Lorem](#acmelorem): A git repo for a PowerShell Module

### Acme.TechDocs

The git repo url: https://acmecorp@dev.azure.com/acmecorp/acme/_git/Acme.TechDocs

The git repo will have the following key files:

- ./devops/
  - azure-pipelines.yml
  - DocFxHelper.ps1
  - DocFxHelper.api.list.template
- ./docs/
  - ./templates/
    - ./DocFxHelper/
  - docfx.json [optional]

The azure-pipelines.yml multi-stage pipeline would look like this

```yml
variables:
  system.debug : true

trigger:
  batch: "true"
  branches:
    include:
    - main
    - dev
    - Feature/*
    exclude:
    - Feature/experimental/*

resources:
  repositories:
    - repository: Acme_Wiki
      type: git
      name: Acme.Wiki

  pipelines:
    - pipeline: Acme_Api
      source: 'Acme.Api'
    - pipeline: Acme_WinApp
      source: 'Acme.WinApp'
    - pipeline: Acme_Lorem
      source: 'Acme.Lorem'

stages:
- stage: Build
  displayName: Build the docs

  pool:
    vmImage: windows-latest

  jobs:
    - job: Compile
      steps:
        - checkout: self
          displayName: Checkout to ./s/Acme.TechDocs
        - checkout: Acme_Wiki
          displayName: Checkout to ./s/Acme.Wiki

        - task: PowerShell@2
          displayName: "Install dependent PowerShell modules"
          inputs:
            targetType: 'inline'
            script: |
              Write-Host "Install module Powershell-yaml"
              Install-Module Powershell-yaml -Scope CurrentUser -Force
              
              Write-Host "Install module Posh-git"
              Install-Module Posh-git -Scope CurrentUser -Force

              Write-Host "Install module Poshstache"
              Install-Module Poshstache -Scope CurrentUser -Force
            pwsh: true

        - download: Acme_Api
        - download: Acme_WinApp
        - download: Acme_Lorem


        - task: CopyFiles@2
          displayName: Copy Acme.TechDocs's docfx.jso and templates to DocFxHelper
          inputs:
            SourceFolder: '$(Pipeline.Workspace)\s\Acme.TechDocs\docs'
            Contents: |
              docfx.json
              templates\**
            TargetFolder: '$(Pipeline.Workspace)\DocFxHelper'

        - task: PowerShell@2
          displayName: Run DocFxHelper on Wikis, APIs, Conceptuals, PowerShell Modules and templates
          inputs:
            targetType: 'inline'
            script: |
              . .\s\Acme.TechDocs\devops\DocFxHelper.ps1
              
              Initialize-DocFxHelper
              
              Add-AdoWiki -CloneUrl "https://acmecorp@dev.azure.com/acmecorp/acme/_git/Acme.Wiki"

              Add-Api -CloneUrl "https://acmecorp@dev.azure.com/acmecorp/acme/_git/Acme.Api" -PipelineId "Acme_Api"  -ArtifactName "Docs.ApiYaml" -Target "apis/Acme.Api" -MenuParentItemName "All APIs" -MenuDisplayName "Acme API" -HomepageUid "Acme.Api.Common"

              Add-Conceptual -CloneUrl "https://acmecorp@dev.azure.com/acmecorp/acme/_git/Acme.WinApp" -RepoRelativePath "docs/products/WinApp" -PipelineId "Acme_WinApp"  -ArtifactName "Docs.ConceptualDocs" -Target "products/Acme.WinApp" -MenuParentItemName "All Products" -MenuDisplayName "Acme WinApp" -Medias @("images")

              Add-PowerShellModule -CloneUrl "https://acmecorp@dev.azure.com/acmecorp/acme/_git/Acme.Lorem" -RepoRelativePath "src" -PipelineId "Acme_Lorem" -ArtifactName "docs" -Target "powershellmodules//Acme.Lorem" -MenuDisplayName "Acme.Lorem"

              Set-Template -Template ".\s\Acme.TechDocs\devops\DocFxHelper.ps1\DocFxHelper.api.list.template" -Target ".\s\Acme.Wiki\includes\api.list.md"
            warningPreference: 'continue'
            informationPreference: 'continue'
            verbosePreference: 'continue'
            debugPreference: 'continue'
            failOnStderr: true
            pwsh: true
            workingDirectory: '$(Pipeline.Workspace)\'


        # DocFx
        - task: CmdLine@2
          inputs:
            script: |
              dotnet tool update -g docfx
              docfx build --log $(Pipeline.Workspace)\a\Logs\docfx.log --logLevel Verbose --exportViewModel --viewModelOutputFolder $(Pipeline.Workspace)\a\ViewModel
            workingDirectory: '$(Pipeline.Workspace)\DocFxHelper\'

        - task: CopyFiles@2
          displayName: Copy generated _site to staging directory
          inputs:
            SourceFolder: '$(Pipeline.Workspace)/DocFxHelper/_site'
            Contents: '**'
            TargetFolder: '$(Pipeline.Workspace)/a/docs'
            CleanTargetFolder: true

        - task: CopyFiles@2
          displayName: Copy generated source DocFxHelper source files to Artifacts folder
          inputs:
            SourceFolder: '$(Pipeline.Workspace)/DocFxHelper/'
            Contents: |
              **
              !_site/**
              !obj/**
            TargetFolder: '$(Pipeline.Workspace)/a/Source'
            CleanTargetFolder: true

        - publish: $(Pipeline.Workspace)/a/docs
          displayName: Publish to Site Artifacts
          artifact: Docs


```

The pipeline result will the pipeline artifact "Docs" which contains the files generated by DocFx (_site).

The ./docs/docfx.json is optional and would be used to customize the docfx experience.  If no docfx.json is specified, a docfx.json will be generated by DocFxHelper.ps1 with default values.

### Acme.Wiki

- Contains: Acme Wiki
- Url: https://acmecorp@dev.azure.com/acmecorp/acme/_git/Acme.Wiki
- Wiki: https://acmecorp@dev.azure.com/acmecorp/acme/_wiki/wikis/Acme.Wiki
- Pipeline: not needed
- Acme.TechDoc pipeline: resources.repositories.repository

The Acme Wiki is an Ado Wiki of type [Publish code as Wiki](https://learn.microsoft.com/en-us/azure/devops/project/wiki/publish-repo-to-wiki?view=azure-devops&tabs=browser)

The wiki doesn't need an Ado pipeline.

### Acme.Api

- Contains: Api
- Url: https://acmecorp@dev.azure.com/acmecorp/acme/_git/Acme.Api
- Pipeline: needed to generate the DocFx metadata
- Acme.TechDoc pipeline: resources.pipelines.pipeline

Key files:

- ./devops/
  - azure-pipelines.yml
- ./docs/
  - docfx.json [optional]
- ./src/* the api's source code

The azure-pipelines.yml would:

- Build the api
- Unit test the api
- Publish Pipeline Artifacts: (unused by Acme.TechDocs)
  - name: Drop
  - content: Acme.Api/*
- Run DocFx metadata to generate the API's documentation in Yaml format
- Publish Pipeline Artifacts:
  - name: Docs.ApiYaml
  - content: ./s/docs/obj/api/*

The docfx.json is optional, you could perform the same result with the metadata command line.

Example of a docx.json to generate the API metadata

```json
{
  "metadata":[
    {
      "src":[
        {
          "files": ["**.csproj", "**.vbproj"],
          "src" : "../src/",
          "exclude": [
            "**.Test.csproj",
            "**.Test.vbproj",
            "**.Tests.csproj",
            "**.Tests.vbproj",
            "**.Testing.csproj",
            "**.Testing.vbproj",
            "**.UnitTests.csproj",
            "**.UnitTests.vbproj"
          ]
        }
      ],
      "comment": "",
      "dest": "obj/api/"
    }
  ]
}
```

### Acme.WinApp

- Contains: Windows Application
- Url: https://acmecorp@dev.azure.com/acmecorp/acme/_git/Acme.WinApp
- Pipeline: needed to publish the markdown files
- Acme.TechDoc pipeline: resources.pipelines.pipeline

Key files:

- ./devops/
  - azure-pipelines.yml
- ./docs/
  - ./Acme.WinApp/*: files that will be used by Acme.TechDocs
  - index.md : ignored by Acme.TechDocs, only used by devs to test the Acme.WinApp docs
  - docfx.json : ignored by Acme.TechDocs, only used by devs to test the Acme.WinApp docs
  - toc.yml : ignored by Acme.TechDocs, only used by devs to test the Acme.WinApp docs
- ./src/*: source code for the app, ignored by Acme.TechDocs

The azure-pipelines.yml would:

- Build the app
- Unit test the app
- Publish Pipeline Artifacts: (unused by Acme.TechDocs)
  - name: Drop
  - content: WinApp/*
- Publish Pipeline Artifacts:  Note: includes only the files from Acme.Lorem sub folder
  - name: Docs.ConceptualDocs
  - content: ./s/docs/Acme.Lorem/

### Acme.Lorem

Git repo:

- Contains: PowerShell module
- Url: https://acmecorp@dev.azure.com/acmecorp/acme/_git/Acme.Lorem
- Pipeline: needed to generate the PowerShell documentation via PlatyPS
- Acme.TechDoc pipeline: resources.pipelines.pipeline

Key files:

- ./devops/
  - azure-pipelines.yml
- ./src/
  - ./Acme.Lorem/
    - Acme.Lorem.psd1
    - Acme.Lorem.psm1

The azure-pipelines.yml would:

- use [PlatyPS](https://github.com/PowerShell/platyPS) to generate the docs for your Acme.Lorem
- Copy or generate an index.html as a landing page
- Copy or generate a toc.yml for the list of exported functions/cmdLets
- Publish Pipeline Artifacts
  - name: Docs
  - Content: *.md and toc.yml

## Helm chart

The Docs folder is the Helm chart for DocFx Helper Docs and Publisher

### namespace

The Helm chart works with a namespace, locally the namespace is docfxhelper, and needs to be deployed on your workstation prior to doing anything.

```powershell
kubectl apply -f .\k8s.namespace.v1.yml
```

### Validate the Chart

```powershell
kubectl config set-context --current --namespace docs-local
helm lint docfxhelper
helm template docfxhelper
helm template docfxhelper --debug
helm install local docfxhelper --debug --dry-run 
helm install local docfxhelper --debug --values .\docfxhelper.workstation.values.yaml --dry-run 
helm install local docfxhelper --debug  --set docs.host.ports.http=5003,docs.host.ports.https=5004,docs.host.provider=dockerDesktop --dry-run 
```

### Deploy the Chart locally

```powershell
kubectl config set-context --current --namespace docfxhelper
az acr login --name testaks.azurecr.io
# helm install my docfxhelper --debug --set docs.host.ports.http=5003,docs.host.ports.https=5004,docs.host.provider=dockerDesktop
# or
helm install my docfxhelper --debug --values .\docfxhelper.workstation.values.yaml
helm list
helm status my
kubectl get all
```

### Uninstalling a deployment by Helm

```powershell
kubectl config set-context --current
helm uninstall my
kubectl get all
```

## running local/workstation

You'l need:

- Prerequisites:
  - [Install](#install-docker-for-windows-and-enable-kubernetes) Docker for Windows and enable Kubernetes
  - [Enable Ingress](#enable-ingress)

- Create deployment
- Create service
- Create ingress resource
- Add host into local hosts file
- Test

### Install Docker for Windows and enable Kubernetes

Install Docker application with all the default options and enable Kubernetes

Manual install: [Download](https://docs.docker.com/desktop/install/windows-install/)

winget: (run PowerShell or shell as admin)

```powershell
winget install Docker.DockerDesktop
```

Start Docker Desktop, enable Kubernetes

### Install Ingress

Run this commands:

```powershell
helm upgrade --install ingress-nginx ingress-nginx --repo https://kubernetes.github.io/ingress-nginx --namespace ingress-nginx --create-namespace
```

Sample result:

```dos
Release "ingress-nginx" has been upgraded. Happy Helming!
NAME: ingress-nginx
LAST DEPLOYED: Mon Jul 17 08:44:01 2023
NAMESPACE: ingress-nginx
STATUS: deployed
REVISION: 2
TEST SUITE: None
NOTES:
The ingress-nginx controller has been installed.
It may take a few minutes for the LoadBalancer IP to be available.
You can watch the status by running 'kubectl --namespace ingress-nginx get services -o wide -w ingress-nginx-controller'

An example Ingress that makes use of the controller:
  apiVersion: networking.k8s.io/v1
  kind: Ingress
  metadata:
    name: example
    namespace: foo
  spec:
    ingressClassName: nginx
    rules:
      - host: www.example.com
        http:
          paths:
            - pathType: Prefix
              backend:
                service:
                  name: exampleService
                  port:
                    number: 80
              path: /
    # This section is only required if TLS is to be enabled for the Ingress
    tls:
      - hosts:
        - www.example.com
        secretName: example-tls

If TLS is enabled for the Ingress, a Secret containing the certificate and key must also be provided:

  apiVersion: v1
  kind: Secret
  metadata:
    name: example-tls
    namespace: foo
  data:
    tls.crt: <base64 encoded cert>
    tls.key: <base64 encoded key>
  type: kubernetes.io/tls
```

### Test ingress

```powershell
kubectl get pods --namespace=ingress-nginx
kubectl wait --namespace ingress-nginx --for=condition=ready pod --selector=app.kubernetes.io/component=controller --timeout=120s
kubectl create deployment demo --image=httpd --port=80
kubectl expose deployment demo
kubectl create ingress demo-localhost --class=nginx --rule="demo.localdev.me/*=demo:80"
kubectl port-forward --namespace=ingress-nginx service/ingress-nginx-controller 5001:80
```

Test the url:

```powershell
curl --resolve demo.localdev.me:5001:127.0.0.1 http://demo.localdev.me:5001
```

Launch the browser to the address [demo.localdev.me:5001](http://demo.localdev.me:5001)

### Delete Ingress Test Demo

```powershell
kubectl delete ingress demo-localhost
kubectl delete deployment demo
kubectl delete service demo
```

### Cert

```bash
openssl pkcs12 -in your-certificate.pfx -nocerts -out private-key.pem -nodes
openssl pkcs12 -in your-certificate.pfx -clcerts -nokeys -out certificate.pem

ca bundle:
openssl pkcs12 -in your-certificate.pfx -out ca-bundle.pem -nodes -nokeys -cacerts
```
