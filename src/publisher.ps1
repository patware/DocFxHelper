#Requires -Modules 'Posh-git', 'yayaml', 'Poshstache', 'PlatyPS'

param(
    [Parameter(Mandatory)][System.IO.DirectoryInfo]$DropsPath,
    [Parameter(Mandatory)][System.IO.DirectoryInfo]$WorkspacePath,
    [Parameter(Mandatory)][System.IO.DirectoryInfo]$SitePath      
)

$script:Versions = @(
    [ordered]@{version=[Version]"0.0.1"; title="Initial version Write-Host only"}
    [ordered]@{version=[Version]"0.0.1.1"; title="Initial version Write-Host only - Parameters"}
    [ordered]@{version=[Version]"0.0.1.2"; title="Initial version Write-Host only - print parameters and test paths with get-location"}
    [ordered]@{version=[Version]"0.0.1.3"; title="Initial version Write-Host only - print out current location's child items"}
    [ordered]@{version=[Version]"0.0.1.3"; title="Initial version Write-Host only - omg dockfxhelper typo instead of docfxhelper"}
    [ordered]@{version=[Version]"0.0.2"; title="Calling specs.ps1"}
    [ordered]@{version=[Version]"0.0.2.1"; title="Calling specs.ps1 - and added ErrorAction, Information, Debug and Verbose preferences"}
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


$ErrorActionPreference = 'Stop'

if (Test-Path $DropsPath)
{
    Write-Host "  - drops path - found [$(Resolve-Path $DropsPath)]"
}
else
{
    Write-Error "  - drops path [$DropsPath] not found"
}

if (Test-Path $WorkspacePath)
{
    Write-Host "  - Workspace path - found [$(Resolve-Path $WorkspacePath)]"
}
else
{
    Write-Error "  - Workspace path [$WorkspacePath] not found"
}

if (Test-Path $SitePath)
{
    Write-Host "  - Site path - found [$(Resolve-Path $SitePath)]"
}
else
{
    Write-Error "  - Site path [$SitePath] not found"
}

$InformationPreference = 'Continue'
$DebugPreference = 'Continue'
$VerbosePreference = 'Continue'

$specs_ps1 = (Join-Path $PSScriptRoot -ChildPath "specs.ps1")
Write-Host "Calling script $specs_ps1 -DropsPath `$DropsPath -WorkspacePath `$WorkspacePath -SitePath `$SitePath"
& $specs_ps1 -DropsPath $DropsPath -WorkspacePath $WorkspacePath -SitePath $SitePath
