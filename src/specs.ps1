#Requires -Modules "Poshstache"

<#
.SYNOPSIS
Converts, assembles and builds sources

.DESCRIPTION
Gathers specs.docs.json from DropsPath, calculates the sources dependency graph, converts and assembles them 
into formats that docfx understands, and generates the docfx site html.

.PARAMETER DropsPath
The path to the folder where all the sources are uploaded (typically by pipelines).

.PARAMETER WorkingPath
The workspace path used by this script and docfx to convert, assemble and publish sources.

.PARAMETER SitePath
The path to the generated docfx site.

#>

param(
  [Parameter(Mandatory)][System.IO.DirectoryInfo]$DropsPath,
  [Parameter(Mandatory)][System.IO.DirectoryInfo]$WorkspacePath,
  [Parameter(Mandatory)][System.IO.DirectoryInfo]$SitePath      
)

<#
    $ErrorActionPreference = 'Inquire'
    $InformationPreference = 'Continue'
    $DebugPreference = 'Continue'
    $VerbosePreference = 'Continue'
#>

$env:DocFxHelper_Publisher = $true

. $PSScriptRoot/specs.include.ps1

$script:SpecsVersions = @(
  [ordered]@{version = [Version]"0.1.6"; title = "Using drops folder" }
  [ordered]@{version = [Version]"0.1.7"; title = "Merging resources" }
  [ordered]@{version = [Version]"0.1.8"; title = "New script parameter names" }
  [ordered]@{version = [Version]"0.1.9"; title = "Copy-Robo instead of robocopy" }
  [ordered]@{version = [Version]"0.1.10"; title = "Checking if specs are valid" }
  [ordered]@{version = [Version]"0.1.10.1"; title = "Copy-Robo renamed para -ShowVerbose" }
  [ordered]@{version = [Version]"0.1.11"; title = "If no specs found in Drops, use those from Samples" }
  [ordered]@{version = [Version]"0.1.12"; title = "Add Invoke-CommandWithRetry for failing commands" }
  [ordered]@{version = [Version]"0.1.13"; title = "Loop until work to do" }
)

$script:SpecsVersion = $SpecsVersions[-1]
Write-Host "specs.ps1 Version [$($SpecsVersion.Version)] $($SpecsVersion.title)"

$DocFxHelperFolders = [ordered]@{
  sources       = (Join-Path $WorkspacePath -ChildPath "sources")
  converted     = (Join-Path $WorkspacePath -ChildPath "converted")
  staging       = (Join-Path $WorkspacePath -ChildPath "staging")
}


Write-Host "Verifying the [$($DocFxHelperFolders.Keys.Count)] Workspace folders"
foreach ($key in $DocFxHelperFolders.Keys) {
  <#
        $key = $DocFxHelperFolders.Keys | select-object -first 1
        $key
    #>
  Write-Host " - $($key): [$($DocFxHelperFolders."$key")]"
  if (Test-Path $DocFxHelperFolders."$key") {
    Write-Host "    $Key folder found"
  }
  else {
    Write-Host "    $Key folder not found: Creating [$($DocFxHelperFolders."$key")]"
    new-Item -Path $DocFxHelperFolders."$key" -ItemType Directory
  }
}

$DocFxHelperFiles = @{
  docfx_json          = (join-Path $DocFxHelperFolders.staging -ChildPath "docfx.json")
  docfxhelper_json    = (join-Path $PublisherLogsPath -ChildPath "docfxhelper.json")
  docfx_build_vm_json = (Join-Path $PublisherLogsPath -ChildPath "docfx.build.json")
}

Write-Host "DocFx files:"
Write-Host "  - docfx.json: [$($DocFxHelperFiles.docfx_json)]"
Write-Host "  - docfxhelper_json: [$($DocFxHelperFiles.docfxhelper_json)] (docfx helper viewModel used in templates)"
Write-Host "  - docfx_build_vm_json: [$($DocFxHelperFiles.docfx_build_vm_json)] (docfx build viewModel used in templates)"


# ------------------------------------------------------------------------
if (Get-ChildItem -Path $DropsPath)
{
  $diffCounter=0
  $compare_json = join-Path $PublisherLogsPath -childPath "Compare.json"
  $comparePrevious_json = join-Path $PublisherLogsPath -childPath "Compare.Previous.json"
  
  copy-item (join-path $PSScriptRoot -childPath "static" -AdditionalChildPath "1.checkworktodo.html") -Destination (join-path $PublisherSitePath -ChildPath "index.html")

  do
  {
    $diffCounter++
    Write-Host "Checking what needs to be done"
  
    if (Test-Path $compare_json)
    {
      Move-Item $compare_json -Destination $comparePrevious_json -Force
    }
    
    $source = $DropsPath
    $destination = $DocFxHelperFolders.sources

    $startedAt = (Get-Date)
  
    $compare = [ordered]@{
      Source = $source
      Destination = $destination
      Counter = $diffCounter
      StartedAt = "$($startedAt.ToUniversalTime())"
      FinishedAt = $null
      TotalSeconds = $null
      HasDifferences = $null
    }
  
    $compare | ConvertTo-Json | Set-Content $compare_json
  
    $hasDifferences = Test-Different -source $source -destination $destination
  
    $finishedAt = Get-Date
    $compare.FinishedAt = "$($finishedAt.ToUniversalTime())"
    $compare.TotalSeconds = [int]($finishedAt - $startedAt).TotalSeconds
    $compare.HasDifferences = $hasDifferences
  
    $compare | ConvertTo-Json | Set-Content $compare_json
  
    if ($hasDifferences)
    {
      Write-Host "Drops and Workspace Sources are different, there's work to do."
      if ($diffCounter -gt 1)
      {
        Write-Host "Better safe than sorry, let's give them a 15 seconds to finish copying files"
        start-sleep -Seconds 15
      }
    }
    else
    {
      Write-Host "Drops and Workspace Sources match, nothing to do, sleeping for 5 seconds, before checking again"
      Start-Sleep -Seconds 5
    }
  }until($hasDifferences)
}


# ------------------------------------------------------------------------
copy-item (join-path $PSScriptRoot -childPath "static" -AdditionalChildPath "2.specs.html") -Destination (join-path $PublisherSitePath -ChildPath "index.html")

Write-Host "Fetching Doc Specs"
Write-Host "Searching for specs.docs.json"

$retry = 0
do
{
  $retry++
  $specs_docs_json_list = Get-ChildItem -Path $DropsPath -Filter "specs.docs.json" -Recurse -Force

  if ($specs_docs_json_list.Count -eq 0) {
    Write-Warning "No specs.docs.json file found in $DropsPath"
    Write-Host "Using the builtin Samples"  

    Write-Host "Sample Main"
    $source = Join-Path $PSScriptRoot -ChildPath "Samples" -AdditionalChildPath "SampleMain"
    $destination = Join-Path $DropsPath -ChildPath "SampleMain"
    #& robocopy $source $destination /E
    Copy-Robo -Source $source -Destination $destination -ShowFullPath -ShowVerbose

    Write-Host "DocFxHelper Template"
    $source = Join-Path $PSScriptRoot -ChildPath "DocFxTemplate" -AdditionalChildPath "DocFxHelper"
    $destination = Join-Path $DropsPath -ChildPath "SampleMain" -AdditionalChildPath "Templates", "DocFxHelper"
    #& robocopy $source $destination /E
    Copy-Robo -Source $source -Destination $destination -ShowFullPath -ShowVerbose

    Write-Host "Sample Site"
    $source = Join-Path $PSScriptRoot -ChildPath "Samples" -AdditionalChildPath "SampleSite"
    $destination = Join-Path $DropsPath -ChildPath "SampleSite"
    Copy-Robo -Source $source -Destination $destination -ShowFullPath -ShowVerbose

  }
}while($specs_docs_json_list.Count -eq 0 -and $retry -lt 2)

if ($specs_docs_json_list.Count -eq 0) {
  Write-Warning "No specs.docs.json file found in $DropsPath"
  Write-Host "Stopping"
}
else {
  Write-Host "Loading [DocSpecs] object from specs.docs.json found in $DropsPath folder"
  $specs = $specs_docs_json_list | ConvertFrom-Specs

  if ($null -eq $specs.Main -or $specs.All.Count -eq 0) {
    Write-Warning "No specs found, nothing to do"
  }
  else {
    # ------------------------------------------------------------------------
    Write-Host "Copy Specs to DocFxHelper's Workspace/Sources"

    $source = $DropsPath
    $destination = $DocFxHelperFolders.sources

    Copy-Robo -Source $source -Destination $destination -Mirror -ShowFullPath -ShowVerbose

    # ------------------------------------------------------------------------
    Write-Host "Converting Doc Resources (ConvertTo-DocFx*)"

    copy-item (join-path $PSScriptRoot -childPath "static" -AdditionalChildPath "3.conversion.html") -Destination (join-path $PublisherSitePath -ChildPath "index.html")

    Write-Host "Converting Main"
    Write-Host "  - Copy from [Workspace.Sources] to [Workspace.Converted]"
    $source = join-path $DocFxHelperFolders.sources -ChildPath $specs.Main.Path.Name
    $destination = join-path $DocFxHelperFolders.converted -ChildPath $specs.Main.Path.Name
    #& robocopy $source $destination  /MIR /FP /V
    Copy-Robo -Source $source -Destination $destination -Mirror -ShowFullPath -ShowVerbose

    $counter = 0
    foreach ($spec in $specs.Ordered) {
      <#
                $spec = $specs.Ordered | select-object -first 1
                $spec = $specs.Ordered | select-object -first 1 -skip 1
                $spec = $specs.Ordered | select-object -first 1 -skip 2
                $spec
            #>
      $counter++
      Write-Host "Converting [$($spec.Id)] [$($counter)/$($specs.Ordered.Count)]"
      Write-Host "  - Copy from [Workspace.Sources] to [Workspace.Converted]"

      $a = @{}

      if ($specs.Main.UseModernTemplate) {
        $a.UseModernTemplate = [switch]$true
      }

      Write-Host "  - Convert-DocResource"

      Convert-DocResource `
        -Spec $spec `
        -Path (Join-Path $DocFxHelperFolders.Sources -ChildPath $Spec.Path.Name) `
        -Destination (Join-Path $DocFxHelperFolders.converted -ChildPath $Spec.Path.Name) `
        @a

    }

    # ------------------------------------------------------------------------
    Write-Host "Generating DocFx.json for resources"

    copy-item (join-path $PSScriptRoot -childPath "static" -AdditionalChildPath "4.assembly.html") -Destination (join-path $PublisherSitePath -ChildPath "index.html")

    if ($specs.Main.DocFx_Json) {
      Write-Host "  - New [Workspace.Staging]/Docfx.json from Main Spec's $($specs.Main.DocFx_Json.Name)"
      New-DocFx `
        -Target $DocFxHelperFolders.Staging `
        -BaseDocFxPath (Join-Path $DocFxHelperFolders.converted -ChildPath $specs.Main.Path.Name -AdditionalChildPath $specs.Main.DocFx_Json.Name)
    }
    else {
      Write-Host "  - New [Workspace.Staging]/Docfx.json"
      New-DocFx `
        -Target $DocFxHelperFolders.Staging `
        -BaseDocFxConfig "{}"
    }


    $counter = 0
    foreach ($spec in $specs.Ordered) {
      <#
                $spec = $specs.Ordered | select-object -first 1
                $spec = $specs.Ordered | select-object -first 1 -skip 1
                $spec = $specs.Ordered | select-object -first 1 -skip 2
                $spec
            #>
      $counter++
      Write-Host "  - Adding Resource $($spec.Id) [$($counter)/$($specs.Ordered.Count)] to DocFx.json"

      <#
                $Spec = $spec
                $Path = (Join-Path $DocFxHelperFolders.converted -ChildPath $Spec.Path.Name)
                $Destination = (Join-Path $DocFxHelperFolders.staging -ChildPath $Spec.Path.Name)

                $Spec
                $Path
                $Destination
                
            #>

      Add-DocResource `
        -Spec $spec `
        -Path (Join-Path $DocFxHelperFolders.converted -ChildPath $Spec.Path.Name) `
        -Destination (Join-Path $DocFxHelperFolders.staging -ChildPath $Spec.Path.Name)


    }

    # ------------------------------------------------------------------------
    Write-Host "Generating files from templates"
    $counter = 0
    foreach ($t in $specs.Templates) {
      <#
                $t = $specs.Templates | select-object -first 1
                $t
            #>
      $counter++
      Write-Host "Generating $($t.Dest) from template $($t.Name) [$($counter)/$($specs.Templates.Count)]"
      $source = join-path -Path $DocFxHelperFolders.converted -ChildPath $t.Spec.Path.Name -AdditionalChildPath $t.Template
      $destination = join-path -Path $DocFxHelperFolders.staging -ChildPath $t.Spec.Path.Name -AdditionalChildPath $t.Dest
      Write-Host "   view model: $($DocFxHelperFiles.docfxhelper_json)"
      Write-Host "     template: $($source)"
      Write-Host "  destination: $($destination)"
      $folder = (split-path $destination)
      if (!(Test-Path $folder)) {
        New-Item $folder -itemType Directory -Force | out-null
      }
      ConvertTo-PoshstacheTemplate -InputFile $source -ParametersObject (Get-Content $DocFxHelperFiles.docfxhelper_json | ConvertFrom-Json -AsHashtable) -HashTable -ErrorAction Continue | set-content $destination -Force
    }

    # ------------------------------------------------------------------------
    Write-Host "DryRun Building DocFx"

    copy-item (join-path $PSScriptRoot -childPath "static" -AdditionalChildPath "5.dryrun.html") -Destination (join-path $PublisherSitePath -ChildPath "index.html")

    push-location $DocFxHelperFolders.staging
    if (test-path "docfx.build.log") { remove-item "docfx.build.log" }
    if (test-path "dryRun_site") { Invoke-CommandWithRetry {remove-item "dryRun_site" -Recurse -Force}}
    if (test-path "dryRun_debug") { Invoke-CommandWithRetry {remove-item "dryRun_debug" -Recurse -Force }}
    if (test-path "_rawModel") { Invoke-CommandWithRetry {remove-item "_rawModel" -Recurse -Force }}
    if (test-path "_viewModel") { Invoke-CommandWithRetry {remove-item "_viewModel" -Recurse -Force }}
    & docfx build --log "docfx.build.log" --verbose --output "dryRun_site" --debugOutput "dryRun_debug" --dryRun  --exportRawModel --rawModelOutputFolder _rawModel --exportViewModel --viewModelOutputFolder _viewModel --maxParallelism 1
    Pop-Location

    $docfx_build_log = Join-Path $DocFxHelperFolders.staging -ChildPath "docfx.build.log"

    $docfx_build_vm = Get-DocFxBuildLogViewModel -DocFxLogFile $docfx_build_log
    $docfx_build_vm.GroupByMessageSeverity | format-table -AutoSize | out-Host
    $docfx_build_vm | convertTo-Json | set-content $DocFxHelperFiles.docfx_build_vm_json

    Write-Host "This will be helpful for helping out writing templates:"
    Write-Host "  docfx.json: [$($DocFxHelperFiles.docfx_json)]"
    Write-Host "  docfxhelper view model: [$($DocFxHelperFiles.docfxhelper_json)]"
    Write-Host "  docfxHelper global variable: [`$DocfxHelper)]"
    Write-Host "  docfx build view model: [$($DocFxHelperFiles.docfx_build_vm_json)]"
    Write-Host "  docfx raw Models: [$(Join-Path $DocFxHelperFolders.staging -ChildPath "_rawModel")]"
    Write-Host "  docfx view Models: [$(Join-Path $DocFxHelperFolders.staging -ChildPath "_viewModel")]"
    Write-Host "docfxHelper:"
    $DocfxHelper | out-host
    Write-Host "docfx_build_vm:"
    $docfx_build_vm | out-host

    # ------------------------------------------------------------------------
    Write-Host "Building DocFx from [$($DocFxHelperFolders.staging)]"

    copy-item (join-path $PSScriptRoot -childPath "static" -AdditionalChildPath "6.build.html") -Destination (join-path $PublisherSitePath -ChildPath "index.html")

    push-location $DocFxHelperFolders.staging
    if (test-path "docfx.build.log") { remove-item "docfx.build.log" }
    if (test-path "dryRun_site") { Invoke-CommandWithRetry {remove-item "dryRun_site" -Recurse -Force }}
    if (test-path "dryRun_debug") { Invoke-CommandWithRetry {remove-item "dryRun_debug" -Recurse -Force }}

    & docfx build --log "docfx.build.log" --verbose --debugOutput "_debug" 
    $source = (get-item _site).FullName
    $destination = $SitePath.FullName

    copy-item (join-path $PSScriptRoot -childPath "static" -AdditionalChildPath "7.publish.html") -Destination (join-path $PublisherSitePath -ChildPath "index.html")
    Write-Host "Site generated.  Copying to final destination"
    Write-Host "         site: $($source)"
    Write-Host "  destination: $($destination)"
    #& robocopy $source $destination /MIR /FP /V
    Copy-Robo -Source $source -Destination $destination -Mirror -ShowFullPath -ShowVerbose
    Pop-Location
  }

  copy-item (join-path $PSScriptRoot -childPath "static" -AdditionalChildPath "8.finished.html") -Destination (join-path $PublisherSitePath -ChildPath "index.html")

}
