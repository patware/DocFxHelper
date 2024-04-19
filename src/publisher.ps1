#Requires -Modules 'Posh-git', 'yayaml', 'Poshstache', 'PlatyPS'

param(
  [System.IO.DirectoryInfo]$DropsPath = "Drops",
  [System.IO.DirectoryInfo]$WorkspacePath = "Workspace",
  [System.IO.DirectoryInfo]$SitePath = "Site"
)

<#
    $ErrorActionPreference = 'Inquire'
    $InformationPreference = 'Continue'
    $DebugPreference = 'Continue'
    $VerbosePreference = 'Continue'
#>

$script:Versions = @(
  [ordered]@{version = [Version]"0.0.1"; title = "Initial version Write-Host only" }
  [ordered]@{version = [Version]"0.0.1.1"; title = "Initial version Write-Host only - Parameters" }
  [ordered]@{version = [Version]"0.0.1.2"; title = "Initial version Write-Host only - print parameters and test paths with get-location" }
  [ordered]@{version = [Version]"0.0.1.3"; title = "Initial version Write-Host only - print out current location's child items" }
  [ordered]@{version = [Version]"0.0.1.3"; title = "Initial version Write-Host only - omg dockfxhelper typo instead of docfxhelper" }
  [ordered]@{version = [Version]"0.0.2"; title = "Calling specs.ps1" }
  [ordered]@{version = [Version]"0.0.2.1"; title = "Calling specs.ps1 - and added ErrorAction, Information, Debug and Verbose preferences" }
  [ordered]@{version = [Version]"0.0.3"; title = "Parameters are now optional with default values relative to the user's current folder." }
)

$script:Version = $script:Versions[-1]

Write-Host "Current script: [$($PSCommandPath)]"
Write-Host "Version [$($script:Version.version)] $($script:Version.title)"
Write-Host "Parameters:"
Write-Host " - DropsPath :     [$($DropsPath)]"
Write-Host " - WorkspacePath : [$($WorkspacePath)]"
Write-Host " - SitePath :      [$($SitePath)]"
Write-Host ""
Write-Host "Current Folder: [$(get-location)]"
Write-Host ""
Write-Host "Verifying parameters provided"

$global:PublisherSitePath = Join-Path (Get-Location).Path -ChildPath "publishersite"
$global:PublisherLogsPath = Join-Path (Get-Location).Path -ChildPath "publisherlogs"

if (Test-Path $PublisherSitePath)
{
  Write-Host "Folder publishersite found [$($PublisherSitePath)]"
}
else
{
  Write-Host "Folder publishersite not found.  Creating [$($PublisherSitePath)]"
  New-Item $PublisherSitePath -ItemType Directory -Force
  Write-Host "Created folder publishersite [$($PublisherSitePath)]"
}

if (Test-Path $PublisherLogsPath)
{
  Write-Host "Folder publisherlogs found [$($PublisherLogsPath)]"
}
else
{
  Write-Host "Folder publisherlogs not found.  Creating [$($PublisherLogsPath)]"
  New-Item $PublisherLogsPath -ItemType Directory -Force
  Write-Host "Created folder publisherlogs [$($PublisherLogsPath)]"
}

copy-item (join-path $PSScriptRoot -childPath "static" -AdditionalChildPath "starting.html") -Destination (join-path $PublisherSitePath -ChildPath "index.html")


$specsFolders = @{
  Drops     = $null
  Workspace = $null
  Site      = $null
}

if (Test-Path $DropsPath) {
  $specsFolders.Drops = (Resolve-Path $DropsPath).Path
  Write-Host "  - drops path - found [$($specsFolders.Drops)]"
}
else {
  Write-Warning "  - drops path [$DropsPath] not found.  Creating..."
  $specsFolders.Drops = Join-Path (Get-Location).Path -ChildPath $DropsPath
}

if (Test-Path $WorkspacePath) {
  $specsFolders.Workspace = (Resolve-Path $WorkspacePath).Path
  Write-Host "  - Workspace path - found [$($specsFolders.Workspace)]"
}
else {
  Write-Warning "  - Workspace path [$WorkspacePath] not found.  Creating..."
  $specsFolders.Workspace = Join-Path (Get-Location).Path -ChildPath $WorkspacePath
}

if (Test-Path $SitePath) {
  $specsFolders.Site = (Resolve-Path $SitePath).Path
  Write-Host "  - Site path - found [$($specsFolders.Site)]"
}
else {
  Write-Warning "  - Site path [$SitePath] not found.  Creating..."
  $specsFolders.Site = Join-Path (Get-Location).Path -ChildPath $SitePath
}


if ($null -ne $specsFolders.Drops -and $null -ne $specsFolders.Workspace -and $null -ne $specsFolders.Site)
{
  $specs_ps1 = (Join-Path $PSScriptRoot -ChildPath "specs.ps1")
  Write-Host "Calling script specs.ps1 [$($specs_ps1)]"
  Write-Host "      -Drops: [$($specsFolders.Drops)]"
  Write-Host "  -Workspace: [$($specsFolders.Workspace)]"
  Write-Host "       -Site: [$($specsFolders.Site)]"
  & $specs_ps1 -DropsPath $specsFolders.Drops -WorkspacePath $specsFolders.Workspace -SitePath $specsFolders.Site
}
else
{
  Write-Warning "Missing folder.  Exiting..."
}

copy-item (join-path $PSScriptRoot -childPath "static" -AdditionalChildPath "finished.html") -Destination (join-path $PublisherSitePath -ChildPath "index.html")