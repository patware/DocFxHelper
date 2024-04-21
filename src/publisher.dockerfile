# syntax=docker/dockerfile:1

# build: docker build -f publisher.dockerfile -t publisher:local .
# run: 
#  3 distinct volume mounts
#    docker run --volume drops:/docfxhelper/drops --volume workspace:/docfxhelper/workspace --volume site:/docfxhelper/site publisher:local
#  1 volume mount with the drops, workspace and site subfolders (FYI case is important)
#    docker run --volume docfxhelper:/docfxhelper publisher:local
FROM mcr.microsoft.com/dotnet/sdk:8.0

LABEL version="0.0.2"
LABEL releasenotes="Install-Modules"

# Add dotnet tools to path.
ENV PATH="${PATH}:/root/.dotnet/tools"

RUN apt update \
    && apt install rsync -y

RUN dotnet tool update -g docfx --verbosity detailed
RUN docfx --version

SHELL ["pwsh", "-Command"]
RUN Install-Module -Name "Poshstache", "Posh-git", "PlatyPS", "yayaml" -Scope AllUsers -AcceptLicense -Force -Verbose

WORKDIR /app
COPY . .

WORKDIR /docfxhelper
CMD ["pwsh", "-File", "/app/publisher.ps1", "-DropsPath", "drops", "-WorkspacePath", "workspace", "-SitePath", "site"]
