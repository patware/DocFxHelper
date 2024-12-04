#Requires -Modules PlatyPS, Posh-git, Poshstache, yayaml

param(
  [System.IO.DirectoryInfo]$DropsPath = "Drops",
  [System.IO.DirectoryInfo]$WorkspacePath = "Workspace",
  [System.IO.DirectoryInfo]$SitePath = "Site",
  [switch]$Loop,
  [switch]$Log,
  [switch]$Information,
  [switch]$Verbose,
  [switch]$Debug
)

<#
    $ErrorActionPreference = 'Inquire'
    $InformationPreference = 'Continue'
    $VerbosePreference = 'Continue'
    $DebugPreference = 'Continue'

    exec.docs.json:
    [ordered]@{CleanWorkspace=$true;DeleteSelf=$true} | ConvertTo-Json | set-content "drops\exec.docs.json"
    [ordered]@{QuitLoop=$true;DeleteSelf=$true} | ConvertTo-Json | set-content "drops\exec.docs.json"

    $Loop = [switch]$true
    $Log = [switch]$true
#>

$script:PublisherVersions = @(
  [ordered]@{version = [Version]"0.0.1"; title = "Initial version Write-Host only" }
  [ordered]@{version = [Version]"0.0.1.1"; title = "Initial version Write-Host only - Parameters" }
  [ordered]@{version = [Version]"0.0.1.2"; title = "Initial version Write-Host only - print parameters and test paths with get-location" }
  [ordered]@{version = [Version]"0.0.1.3"; title = "Initial version Write-Host only - print out current location's child items" }
  [ordered]@{version = [Version]"0.0.1.3"; title = "Initial version Write-Host only - omg dockfxhelper typo instead of docfxhelper" }
  [ordered]@{version = [Version]"0.0.2"; title = "Calling specs.ps1" }
  [ordered]@{version = [Version]"0.0.2.1"; title = "Calling specs.ps1 - and added ErrorAction, Information, Debug and Verbose preferences" }
  [ordered]@{version = [Version]"0.0.3"; title = "Parameters are now optional with default values relative to the user's current folder." }
  [ordered]@{version = [Version]"0.0.4"; title = "Add parameters -Logs, -Information, -Verbose and -Debug - Logs turns on Transcript to record publisherlogs folder" }
  [ordered]@{version = [Version]"0.0.5"; title = "Copying static nooutputyet.html to Site/index.html when no files in site yet." }
  [ordered]@{version = [Version]"0.0.6"; title = "Added handling of exec.docs.json" }
  [ordered]@{version = [Version]"0.0.6.1"; title = "Moved the handling of exec.docs.json in specs.ps1"}
  [ordered]@{version = [Version]"0.0.7"; title = "Added argument -Loop which will run specs.ps1 in a loop, with a wait pause time of 60sec"}
  [ordered]@{version = [Version]"0.0.7.1"; title = "Displaying the versions of the files being used"}
  [ordered]@{version = [Version]"0.0.8"; title = "Transcript now uses a date + revision id to simplify finding the logs"}
)

$global:PublisherVersion = $script:PublisherVersions[-1]

$global:StaticFolder = join-path $PSScriptRoot -childPath "static"
$global:PublisherSitePath = Join-Path (Get-Location).Path -ChildPath "publishersite"
$global:PublisherLogsPath = Join-Path (Get-Location).Path -ChildPath "publisherlogs"

if (Test-Path $global:PublisherSitePath)
{
  Write-Host "Folder publishersite found [$($global:PublisherSitePath)]"
}
else
{
  Write-Host "Folder publishersite not found.  Creating [$($global:PublisherSitePath)]"
  New-Item $global:PublisherSitePath -ItemType Directory -Force
  Write-Host "Created folder publishersite [$($global:PublisherSitePath)]"
}

if (Test-Path $global:PublisherLogsPath)
{
  Write-Host "Folder publisherlogs found [$($global:PublisherLogsPath)]"
}
else
{
  Write-Host "Folder publisherlogs not found.  Creating [$($global:PublisherLogsPath)]"
  New-Item $global:PublisherLogsPath -ItemType Directory -Force
  Write-Host "Created folder publisherlogs [$($global:PublisherLogsPath)]"
}

Write-Host "Current script: [$($PSCommandPath)]"
Write-Host "Publisher Version [$($global:PublisherVersion.version)] $($global:PublisherVersion.title)"
Write-Host "Parameters:"
Write-Host " - DropsPath :     [$($DropsPath)]"
Write-Host " - WorkspacePath : [$($WorkspacePath)]"
Write-Host " - SitePath :      [$($SitePath)]"
Write-Host " - Log :           [$($Log)]"
Write-Host " - Information :   [$($Information)]"
Write-Host " - Verbose :       [$($Verbose)]"
Write-Host " - Debug :         [$($Debug)]"
Write-Host ""
Write-Host "Current Folder: [$(get-location)]"
Write-Host ""

if ($Information)
{
  Write-Host "Setting InformationPreference to [Continue]"
  $InformationPreference = 'Continue'
}

if ($Verbose)
{
  Write-Host "Setting VerbosePreference to [Continue]"
  $VerbosePreference = 'Continue'
}

if ($Debug)
{
  Write-Host "Setting DebugPreference to [Continue]"
  $DebugPreference = 'Continue'
}

Write-Host "Verifying parameters provided"

$specsFolders = @{
  Drops     = $null
  Workspace = $null
  Site      = $null
}

copy-item (join-path $global:StaticFolder -ChildPath "0.starting.html") -Destination (join-path $global:PublisherSitePath -ChildPath "index.html")

function Get-DocsFolder
{
  param($Name, $Value, $Default)

  if ([string]::IsNullOrEmpty("$Value".Trim()))
  {
    Write-Warning "-$Name not specified or empty, defaulting to [$Default]"
    return $Default
  }
  
  return $Value
}

function Set-DocsFolder
{
  param($Name, $Path)

  $ret = $null

  if (Test-Path $Path) 
  {
    $ret= (Resolve-Path $Path).Path
    Write-Information "  -[$Name] path - found [$($ret)]"
  }
  else 
  {
    $ret = Join-Path (Get-Location).Path -ChildPath $Path

    Write-Warning "  -[$Name] path [$($ret)] not found.  Creating..."
    
    [void](New-Item $ret -ItemType Directory)
  }

  return $ret
  
}

function Stop-PreviousTranscripts
{
  $continue = $true

  do
  { 
    
    try {
      Stop-Transcript
    }
    catch {
      $continue = $false
    }

  }while ($continue)
}

$DropsPath = Get-DocsFolder -Name "Drops" -Value $DropsPath -Default "drops"
$specsFolders.Drops = Set-DocsFolder -Name "Drops" -Path $DropsPath

$WorkspacePath = Get-DocsFolder -Name "Workspace" -Value $WorkspacePath -Default "workspace"
$specsFolders.Workspace = Set-DocsFolder -Name "Workspace" -Path $WorkspacePath

$SitePath = Get-DocsFolder -Name "Site" -Value $SitePath -Default "site"
$specsFolders.Site = Set-DocsFolder -Name "site" -Path $SitePath

if ($null -ne $specsFolders.Drops -and $null -ne $specsFolders.Workspace -and $null -ne $specsFolders.Site)
{
  if ($null -ne $specsFolders.Site)
  {
    Write-Host "Checking if there are html files in Site [$($specsFolders.Site)]"
    $htmlFilesInSite = Get-ChildItem -Path $specsFolders.Site -Filter "*.html"

    if ($htmlFilesInSite.Count -eq 0)
    {
      Write-Host "No html files in Site, no content has ever been produced, copying the static nooutputyet.html to index.html so there's something to show"
      copy-item (Join-Path $global:StaticFolder -ChildPath "nooutputyet.html") -Destination (join-path $specsFolders.Site -ChildPath "index.html")
    }
    else
    {
      Write-Host "There's already [$($htmlFilesInSite.Count)] html files in Site."
    }
  }

  $specs_ps1 = (Join-Path $PSScriptRoot -ChildPath "specs.ps1")
  Write-Host "Calling script specs.ps1 [$($specs_ps1)]"
  Write-Host "      -Drops: [$($specsFolders.Drops)]"
  Write-Host "  -Workspace: [$($specsFolders.Workspace)]"
  Write-Host "       -Site: [$($specsFolders.Site)]"

  do
  {
    Stop-PreviousTranscripts

    $Transcript = $null

    $publisherRevisionId = (Get-ChildItem -Path $global:PublisherLogsPath -filter "publisher-$(get-date -f yyyy.MM.dd).*.log").Count
    Write-Host "Publisher Revision Id: [$publisherRevisionId]"

    if ($Log)
    {
      $publisherLogsFilename = "publisher-$(get-date -f yyyy.MM.dd).$($publisherRevisionId).log"
      Write-Host "Starting Transcripts in Logs Path [$($global:PublisherLogsPath)]"
      $Transcript = Join-Path $global:PublisherLogsPath -ChildPath $publisherLogsFilename
      Start-Transcript -Path $Transcript -Append
      Write-Host "Transcripts will be availabled in Logs Path [$($global:PublisherLogsPath)]"
      Write-Host "  Details: [$Transcript]"
    }

    try
    {
      . $specs_ps1 -DropsPath $specsFolders.Drops -WorkspacePath $specsFolders.Workspace -SitePath $specsFolders.Site
    }
    catch
    {
      Write-Warning "Something went wrong when running $($specs_ps1)"
      Write-Host "Error Details:"
      Write-Host "Message = $($Error[0].Exception.Message)"
      Write-Host "Source= $($Error[0].Exception.Source)"
      Write-Host "Stack Trace = $($Error[0].Exception.StackTrace)"    
    }

    Write-Host "$($specs_ps1) finished."

    Write-Host "File Versions"
    Write-Host "DocFxHelper.ps1   - [$($global:DocFxHelperVersion.Version)] $($global:DocFxHelperVersion.title)"
    Write-Host "specs.include.ps1 - [$($global:SpecsIncludeVersion.Version)] $($global:SpecsIncludeVersion.title)"
    Write-Host "specs.ps1         - [$($global:SpecsVersion.Version)] $($global:SpecsVersion.title)"
    Write-Host "Publisher         - [$($global:PublisherVersion.version)] $($global:PublisherVersion.title)"


    if ($Transcript)
    {
      Write-Host "Saving Transcript to [$Transcript]"
      Stop-Transcript
    }
    
    
    if ($Loop)
    {
      Write-Host "Sleeping 60 seconds before re-starting it."
      Write-Host "      Current time: $((Get-Date))"
      Write-Host "Next run starts at: $((Get-Date).AddSeconds(60))"
      Start-Sleep -Seconds 60
      Write-Host "Wakey wakey"
    }

  } while($Loop)

}
else
{
  Write-Warning "Missing folder.  Exiting..."
}

