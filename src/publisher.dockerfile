# syntax=docker/dockerfile:1

# build: 
#  docker build -f publisher.dockerfile -t publisher:local .
#  docker build -f publisher.dockerfile -t publisher:local --progress=plain .
# run: 
#  3 distinct volume mounts
#    docker run --volume drops:/docfxhelper/drops --volume workspace:/docfxhelper/workspace --volume site:/docfxhelper/site publisher:local
#  1 volume mount with the drops, workspace and site subfolders (FYI case is important)
#    docker run --volume docfxhelper:/docfxhelper publisher:local

ARG DOTNET_SDK_VERSION=8.0
FROM mcr.microsoft.com/dotnet/sdk:${DOTNET_SDK_VERSION}

LABEL version="0.0.3"
LABEL releasenotes="Parameterized FROM image tag"
LABEL image_reference="https://hub.docker.com/_/microsoft-dotnet-sdk/"

# Add dotnet tools to path.
ENV PATH="${PATH}:/root/.dotnet/tools"

RUN apt update \
    && apt install rsync -y \
    && dotnet tool update -g docfx --verbosity detailed

SHELL ["pwsh", "-Command"]
RUN Install-Module -Name "Poshstache", "Posh-git", "PlatyPS", "yayaml" -Scope AllUsers -AcceptLicense -Force -Verbose

# Powershell scripts will run from /app
WORKDIR /app
COPY . .

# All DocFxHelper script working folders will be based out of /docfxhelper folder
#  /docfxhelper/drops: Where Specs and meta will uploaded to for consumption by DocFxHelper PowerShell scripts
#  /docfxhelper/workspace: DocFxHelper script's internal working folder
#  /docfxhelper/site: Where DocFx generated _site will copied to and made available to the site image

WORKDIR /docfxhelper
CMD ["pwsh", "-File", "/app/publisher.ps1", "-DropsPath", "drops", "-WorkspacePath", "workspace", "-SitePath", "site"]
