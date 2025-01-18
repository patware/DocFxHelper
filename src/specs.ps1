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
  [ordered]@{version = [Version]"0.1.14"; title = "Samples will be deleted from drops after copy to source" }
  [ordered]@{version = [Version]"0.1.15"; title = "Nerd Stats"}
  [ordered]@{version = [Version]"0.1.16"; title = "Handling of special file exec.docs.json"}
  [ordered]@{version = [Version]"0.1.17"; title = "Refactor to functions"}
  [ordered]@{version = [Version]"0.1.18"; title = "Optimized overall process by skipping what's already done."}
  [ordered]@{version = [Version]"0.1.18.1"; title = "Wrapped IO commands with CommandWithRetry to get around IO issues"}
  [ordered]@{version = [Version]"0.1.18.2"; title = "Move-Item with source/* syntax and -Force"}
  [ordered]@{version = [Version]"0.1.18.3"; title = "Copy-Robo instead of Move-Item because of Azure issues"}
  [ordered]@{version = [Version]"0.1.18.4"; title = "Fix: problem with Remove-Item, solution = Use the -Force"}
  [ordered]@{version = [Version]"0.1.18.5"; title = "Fix: Crazy problems with Remove-Item and drops path and Azure, added more logging and moved test-path inside the retry script blocks"}
  [ordered]@{version = [Version]"0.1.18.6"; title = "Fix: Still failed remove-items, bumping RetryCount to 50!"}
  [ordered]@{version = [Version]"0.1.19"; title = "Add check/filter for a specs.docs.json in Drops folder.  Pipeline concurrency workaround."}
  [ordered]@{version = [Version]"0.1.20"; title = "Checks and logging for missing files in Invoke-Templates"}
  [ordered]@{version = [Version]"0.1.20.1"; title = "Remove-items got close to 50, bumping RetryCount to 99!"}
  [ordered]@{version = [Version]"0.1.21"; title = "Fix: special instruction file exec.docs.json was not being deleted"}
  [ordered]@{version = [Version]"0.1.22"; title = "Feature: Special instructions can now delete individual items from workspace sub folders"}
  [ordered]@{version = [Version]"0.1.22.1"; title = "Fix: Cut and paste error in the special instructions delete feature"}
  [ordered]@{version = [Version]"0.1.23"; title = "Revised how to handle Poshstache errors"}
)

$global:SpecsVersion = $SpecsVersions[-1]
Write-Host "specs.ps1 Version [$($global:SpecsVersion.Version)] $($global:SpecsVersion.title)"

function Start-NerdStats
{
  return [PSCustomObject][ordered]@{
    StartedAt = get-date
    Steps = @()
    FinishedAt = $null
    Elapsed = $null
    ElapsedDisplay = $null
  }
}

function Add-NerdStatsStep
{
  param(
    [Parameter(Mandatory)]$Stats, 
    $Display
  )

  if ($Stats.Steps.Count -gt 0)
  {
    $Stats.Steps[-1].FinishedAt = get-date
    $Stats.Steps[-1].Elapsed = $Stats.Steps[-1].FinishedAt - $Stats.Steps[-1].StartedAt
    $Stats.Steps[-1].ElapsedDisplay = "$($Stats.Steps[-1].Elapsed)"
  }

  $Stats.Steps += [PSCustomObject][ordered]@{
    No = (1 + $Stats.Steps.Count)
    Step = $Display
    StartedAt = get-date
    FinishedAt = $null
    Elapsed = $null
    ElapsedDisplay = $null
  }  
}

function Stop-NerdStats
{
  param($Stats)

  if ($Stats.Steps.Count -gt 0)
  {
    $Stats.Steps[-1].FinishedAt = get-date
    $Stats.Steps[-1].Elapsed = $Stats.Steps[-1].FinishedAt - $Stats.Steps[-1].StartedAt
    $Stats.Steps[-1].ElapsedDisplay = "$($Stats.Steps[-1].Elapsed)"
  }

  $Stats.FinishedAt = get-date
  $Stats.Elapsed = $Stats.FinishedAt - $Stats.StartedAt
  $Stats.ElapsedDisplay = "$($Stats.Elapsed)"
  
}


function Show-NerdStats 
{
  param($Stats)

  Write-Debug "Stats:"
  Write-Debug "  Started at: $($Stats.StartedAt)"
  Write-Debug " Finished at: $($Stats.FinishedAt)"
  Write-Debug " Time to run: $($Stats.ElapsedDisplay)"
  Write-Debug ($Stats.Steps | select-object No, Step, ElapsedDisplay | format-table -AutoSize -Wrap | Out-String)
  
}

function Get-SpecialInstructions
{
  param($Path)

  Write-Information "Checking for special instructions file [exec.docs.json]"
  $exec_docs_json = join-path $Path -childPath "exec.docs.json"

  if (Test-Path $exec_docs_json)
  {
    return $exec_docs_json
  }
  else
  {
    return $null
  }
  
}


function Invoke-SpecialInstructions
{
  param($specialInstructions)

  if ($specialInstructions)
  {
    Write-Information "Loading instructions from [$specialInstructions]"
  
    $exec_docs = Get-Content $specialInstructions | ConvertFrom-Json -AsHashtable
  
    if ($exec_docs.CleanWorkspace)
    {
      Write-Information "Workspace Clean is true: deleting items from Workspace folder [$WorkspacePath]"
  
      foreach($item in Get-ChildItem -Path $WorkspacePath -Directory)
      {
        Write-Information "- $($item.FullName)"
        Invoke-CommandWithRetry {if (Test-Path $item) {remove-item $item -Recurse -Force}} -RetryCount 99 -TimeoutInSecs 5
      }
      Write-Information "Workspace folder is clean."
    }

    if ($exec_docs.Delete)
    {
      Write-Information "Deleting individual items from workspace sub folders"

      foreach($itemToDelete in $exec_docs.Delete)
      {
        Write-Information "- $($itemToDelete)"

        foreach($workspaceFolder in Get-ChildItem -Path $WorkspacePath -Directory)
        {
          $itemWorkspaceSubFolder = Join-Path -Path $workspaceFolder.FullName -ChildPath $itemToDelete

          Write-Information "  - $($itemWorkspaceSubFolder)"
          if (Test-Path $itemWorkspaceSubFolder)
          {
            Write-Debug "    - Removing [$($itemWorkspaceSubFolder)] ..."
            Invoke-CommandWithRetry {if (Test-Path $itemWorkspaceSubFolder) {remove-item $itemWorkspaceSubFolder -Recurse -Force}} -RetryCount 99 -TimeoutInSecs 5
            Write-Debug "    - [$($itemWorkspaceSubFolder)] Removed"
          }
          else
          {
            Write-Debug "    - [$($itemWorkspaceSubFolder)] not found, nothing to do."
          }
        }
      }
    }
  
    if ($exec_docs.DeleteSelf)
    {
      Write-Information "Removing exec_docs_json [$specialInstructions]"
  
      Invoke-CommandWithRetry {
        if (test-Path $specialInstructions) 
        {
          Write-Verbose "exec_docs_json found at [$specialInstructions], removing it."
          remove-item $specialInstructions -Force
        }
        else
        {
          Write-Verbose "exec_docs_json not found at [$specialInstructions], nothing to do."
        }
      } -RetryCount 99 -TimeoutInSecs 5
    }
  }
}

function Get-NewSpecFolders
{
  param($Path)

  $ret = @()
  
  $folders = Get-ChildItem $Path -Directory

  foreach($folder in $folders)
  {
    $specs_docs_json = Get-ChildItem -Path $folder.FullName -Filter "specs.docs.json"
    if ($specs_docs_json.Count -eq 0)
    {
      Write-Information "[specs.docs.json] not found in [$($folder.FullName)] a pipeline is still uploading files there, skipping"
    }
    else 
    {
      Write-Information "A [specs.docs.json] was found in [$($folder.FullName)], we have a winner."
      $ret += $folder
    }
  }

  Write-Information "Number of new specs found: [$($ret.Count)]"

  return $ret
}

function Move-NewSpecToSources
{
  [CmdletBinding()]
  param([Parameter(ValueFromPipeline)]$specPath)

  begin{

  }
  process{
    Write-Information "New Spec found [$($specPath.Name)]"
    $source = $specPath
    $destination = join-path $DocFxHelperFolders.sources -ChildPath $source.Name

    Write-Debug "New Spec:"
    Write-Debug "  -        Name: [$($specPath.Name)]"
    Write-Debug "  -  Drops path: [$($source)]"
    Write-Debug "  - Source Path: [$($destination)]"

    if (Test-Path $destination)
    {
      Write-Debug "  - delete destination [$destination] for a clean copy (Remove-Item `$destination -Recurse -Force)"
      Invoke-CommandWithRetry {if (Test-Path $destination) {Remove-Item $destination -Recurse -Force}} -RetryCount 99 -TimeoutInSecs 5
      Write-Debug "  - destination [$destination] deleted"
    }
    else
    {
      Write-Debug "  - destination [$destination] doesn't exist, nothing to delete"
    }

    Write-Debug "  - Copy-Robo [$($specPath.Name)] from [$($source)] to [$($destination)] using Mirror, ShowFullPath, ShowVerbose"
    Copy-Robo -source $source -destination $destination -Mirror -ShowFullPath -ShowVerbose

    if (Test-Path $source)
    {
      Write-Debug "  - delete source [$($source)] using Remove-Item `$source -Recurse -Force"
      Invoke-CommandWithRetry {if (Test-Path $source) {Remove-Item $source -Recurse -Force}} -RetryCount 99 -TimeoutInSecs 5
      Write-Debug "  - source [$($source)] deleted"
    }
    else {
      Write-Debug "  - source [$source] doesn't exist, nothing to delete"
    }

    return $destination

  }
  end{
    
  }
}

function Copy-Samples
{
  param($SourcePath, $DestinationPath)

  $todos = @(
    [PSCustomObject][ordered]@{
      name = "Sample Main"
      source = Join-Path $SourcePath -ChildPath "Samples" -AdditionalChildPath "SampleMain", "*"
      destination = Join-Path $DestinationPath -ChildPath "SampleMain"
    }
    [PSCustomObject][ordered]@{
      name = "DocFxHelper Template"
      source = Join-Path $SourcePath -ChildPath "DocFxTemplate" -AdditionalChildPath "DocFxHelper", "*"
      destination = Join-Path $DestinationPath -ChildPath "SampleMain" -AdditionalChildPath "Templates", "DocFxHelper"
    }
    [PSCustomObject][ordered]@{
      name = "Sample Site"
      source = Join-Path $SourcePath -ChildPath "Samples" -AdditionalChildPath "SampleSite", "*"
      destination = Join-Path $DestinationPath -ChildPath "SampleSite"
    }
  )

  foreach($todo in $todos)
  {
    Write-Information $todo.name

    if (Test-Path $todo.destination)
    {
      Write-Verbose "  - Destination: [$($todo.destination)] already exists, skipping"
    }
    else
    {
      Write-Verbose "  - Source: [$($todo.source)]"
      Write-Verbose "  - Destination: [$($todo.destination)]"
      New-Item -Path $todo.destination -ItemType Directory
      Copy-Item -Path $todo.source -Destination $todo.destination -Recurse -Verbose
    }
  
  }
}

function Remove-Samples
{
  param($Path)

  $folders = @(
    Join-Path $Path -ChildPath "SampleMain"
    Join-Path $Path -ChildPath "SampleSite"
  )

  foreach($folder in $folders)
  {
    if (Test-Path $folder)
    {
      Write-Verbose "Removing [$($folder)]"
      Remove-Item $folder -Recurse -Force
    }
  }
}


function Get-SpecsDocsJson
{
  param($Path, [switch]$ExcludeSamples)

  $exclude = @()

  if ($ExcludeSamples)
  {
    $exclude = @("SampleMain", "SampleSite")
  }

  return Get-ChildItem -Path $Path -Directory -Exclude $exclude | Get-ChildItem -Filter "specs.docs.json"

}


function Invoke-SpecsConversion
{
  param($AllSpecs)
  
  $ret = @()

  $destination =  (Join-Path $DocFxHelperFolders.converted -ChildPath $AllSpecs.Main.Path.Name)

  if (Test-Path $destination)
  {
    Write-Debug "Main spec folder exists in destination, so it didn't change.  skipping"
  }
  else
  {
    Write-Debug "Main spec has changed.  copying"
    $source = (Join-Path $DocFxHelperFolders.sources -ChildPath $AllSpecs.Main.Path.Name)    
    Invoke-CommandWithRetry {Copy-Robo -source $source -destination $destination -Mirror -ShowFullPath -ShowVerbose} -RetryCount 99 -TimeoutInSecs 5

    $ret += $AllSpecs.Main
  }

  foreach ($spec in $AllSpecs.Ordered) 
  {
    <#
      $spec = $AllSpecs.Ordered | select-object -first 1
      $spec = $AllSpecs.Ordered | select-object -first 1 -skip 1
      $spec = $AllSpecs.Ordered | select-object -first 1 -skip 2
      $spec
    #>
    $counter++

    $destination = (Join-Path $DocFxHelperFolders.converted -ChildPath $Spec.Path.Name)

    if (Test-Path $destination)
    {
      Write-Debug "Spec [$($spec.id)] already converted, skipping"
    }
    else
    {
      Write-Information "Converting [$($spec.Id)] [$($counter)/$($AllSpecs.Ordered.Count)]"
              
      $a = @{}
        
      if ($specs.Main.UseModernTemplate) 
      {
        $a.UseModernTemplate = [switch]$true
      }
      
      Convert-DocResource `
        -Spec $spec `
        -Path (Join-Path $DocFxHelperFolders.Sources -ChildPath $Spec.Path.Name) `
        -Destination $destination `
        @a
  
      $ret += [PSCustomObject]$spec
    }
  }
  Write-Information "[$($ret.Count)] specs Converted"
  return $ret
}

function New-DocFxJson
{
  param($AllSpecs)

  if ($AllSpecs.Main.DocFx_Json) {
    Write-Information "  - New [Workspace.Staging]/Docfx.json from Main Spec's $($AllSpecs.Main.DocFx_Json.Name)"
    New-DocFx `
      -Target $DocFxHelperFolders.Staging `
      -BaseDocFxPath (Join-Path $DocFxHelperFolders.converted -ChildPath $AllSpecs.Main.Path.Name -AdditionalChildPath $AllSpecs.Main.DocFx_Json.Name)
  }
  else {
    Write-Information "  - New vanilla/blank [Workspace.Staging]/Docfx.json"
    New-DocFx `
      -Target $DocFxHelperFolders.Staging `
      -BaseDocFxConfig "{}"
  }
}

function Add-SpecsToDocFxJson 
{
  param($AllSpecs)

  $counter = 0

  foreach ($spec in $AllSpecs.Ordered) {
    <#
              $spec = $AllSpecs.Ordered | select-object -first 1
              $spec = $AllSpecs.Ordered | select-object -first 1 -skip 1
              $spec = $AllSpecs.Ordered | select-object -first 1 -skip 2
              $spec
          #>
    $counter++
    Write-Information "  - Adding Resource $($spec.Id) [$($counter)/$($AllSpecs.Ordered.Count)] to DocFx.json"

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
}

function Invoke-DocFx
{
  param([switch]$DryRun)

  push-location $DocFxHelperFolders.staging

  if ($DryRun)
  {
    $ret = [ordered]@{
      docfx_build_log = Join-Path $global:PublisherLogsPath -ChildPath "dryRun" -AdditionalChildPath "docfx.build.log"
      site = Join-Path $DocFxHelperFolders.staging -ChildPath "dryRun_site"
      debug = Join-Path $global:PublisherLogsPath -ChildPath "dryRun" -AdditionalChildPath "_debug"
      rawModel = Join-Path $global:PublisherLogsPath -ChildPath "dryRun" -AdditionalChildPath "_rawModel"
      viewModel = Join-Path $global:PublisherLogsPath -ChildPath "dryRun" -AdditionalChildPath "_viewModel"
    }
  }
  else
  {
    $ret = [ordered]@{
      docfx_build_log = Join-Path $global:PublisherLogsPath -ChildPath "final" -AdditionalChildPath "docfx.build.log"
      site = Join-Path $DocFxHelperFolders.staging -ChildPath "_site"
      debug = Join-Path $global:PublisherLogsPath -ChildPath "final" -AdditionalChildPath "_debug"
      rawModel = Join-Path $global:PublisherLogsPath -ChildPath "final" -AdditionalChildPath "_rawModel"
      viewModel = Join-Path $global:PublisherLogsPath -ChildPath "final" -AdditionalChildPath "_viewModel"
    }
  }
  
  if (test-path $ret.docfx_build_log) { remove-item $ret.docfx_build_log -Force}
  Invoke-CommandWithRetry {if (test-path $ret.site)      {remove-item $ret.site -Recurse -Force      }} -RetryCount 99 -TimeoutInSecs 5
  Invoke-CommandWithRetry {if (test-path $ret.debug)     {remove-item $ret.debug -Recurse -Force     }} -RetryCount 99 -TimeoutInSecs 5 
  Invoke-CommandWithRetry {if (test-path $ret.rawModel)  {remove-item $ret.rawModel -Recurse -Force  }} -RetryCount 99 -TimeoutInSecs 5
  Invoke-CommandWithRetry {if (test-path $ret.viewModel) {remove-item $ret.viewModel -Recurse -Force }} -RetryCount 99 -TimeoutInSecs 5

  if ($DryRun)
  {
    & docfx build --log $ret.docfx_build_log --verbose --output $ret.site --debugOutput $ret.debug --exportRawModel --rawModelOutputFolder $ret.rawModel --exportViewModel --viewModelOutputFolder $ret.viewModel --dryRun
  }
  else
  {
    & docfx build --log $ret.docfx_build_log --verbose --output $ret.site --debugOutput $ret.debug --exportRawModel --rawModelOutputFolder $ret.rawModel --exportViewModel --viewModelOutputFolder $ret.viewModel
  }
  Pop-Location

  $global:lastDocfxRunDetails = [PSCustomObject]$ret
}


function Invoke-Templates
{
  param($AllSpecs)

  $counter = 0
  foreach ($t in $AllSpecs.Templates) {
    <#
              $t = $AllSpecs.Templates | select-object -first 1
              $t
          #>
    $counter++
    Write-Information "Generating [$($t.Dest)] from template [$($t.Name)] [$($counter)/$($AllSpecs.Templates.Count)]"
    $source = join-path -Path $DocFxHelperFolders.converted -ChildPath $t.Spec.Path.Name -AdditionalChildPath $t.Template
    $destination = join-path -Path $DocFxHelperFolders.staging -ChildPath $t.Spec.Path.Name -AdditionalChildPath $t.Dest
    Write-Information "   view model: $($DocFxHelperFiles.docfxhelper_json)"
    Write-Information "     template: $($source)"
    Write-Information "  destination: $($destination)"
    $folder = (split-path $destination)
    if (!(Test-Path $folder)) {
      New-Item $folder -itemType Directory -Force | out-null
    }

    $proceed=$true

    if (!(Test-Path $source))
    {
      $proceed = $false
      Write-Warning "Did not find the template file [$($source)]"
    }

    if (!(Test-Path $DocFxHelperFiles.docfxhelper_json))
    {
      $proceed = $false
      Write-Warning "Did not find the DocFxHelper file [$($DocFxHelperFiles.docfxhelper_json)]"
    }

    if (!(Test-Path (Split-Path $destination)))
    {
      Write-Information "Folder where the generated file will be copied to does not exist, creating it [$((Split-Path $destination))]"
      New-Item -Path (Split-Path $destination) -ItemType Directory -Force | Out-Null
    }

    if ($proceed)
    {      
      $generatedString = $null
      $PoshstacheError = $null
      $vm = (Get-Content $DocFxHelperFiles.docfxhelper_json | ConvertFrom-Json -AsHashtable)

      Write-Verbose "Launching Poshstache for Generating file [$destination] from template [$source] and view model [$($DocFxHelperFiles.docfxhelper_json)]"

      try
      {
        $generatedString = ConvertTo-PoshstacheTemplate -InputFile $source -ParametersObject $vm -HashTable
      }
      catch
      {
        Write-Warning "Problem generating file [$destination] from template [$source] and view model [$($DocFxHelperFiles.docfxhelper_json)]"
        Write-Warning "Poshstache error: [$($PoshstacheError)]"
        Write-Information "Error Message: [$($Error[0].Exception.Message)]"
        Write-Information "Error Source: [$($Error[0].Exception.Source)]"
        Write-Information "Error StackTrace: [$($Error[0].Exception.StackTrace)]"
      }

      Write-Verbose "Writing generated content to file [$destination]"
      set-content $destination -Force -Value "$($generatedString)"
      Write-Verbose "Generated content written to file [$destination]"

    }
    else
    {
      Write-Verbose "File not generated because of missing files"
    }
  }

}

function Show-DocFxDryRunDetails
{  
  $docfx_build_log = $global:lastDocfxRunDetails.docfx_build_log

  $docfx_build_vm = Get-DocFxBuildLogViewModel -DocFxLogFile $docfx_build_log
  $docfx_build_vm | convertTo-Json -Depth 5 | set-content $DocFxHelperFiles.docfx_build_vm_json
 
  Write-Information "This will be helpful for helping out writing templates:"
  Write-Information "  docfxhelper view model:      [$($DocFxHelperFiles.docfxhelper_json)]"
  Write-Information "  docfxHelper global variable: [`$DocfxHelper]"
  Write-Information "  docfx.json:                  [$($DocFxHelperFiles.docfx_json)]"
  Write-Information "  docfx build view model:      [$($DocFxHelperFiles.docfx_build_vm_json)]"
  Write-Information "  docfx raw Models:            [$($global:lastDocfxRunDetails.rawModel)]"
  Write-Information "  docfx view Models:           [$($global:lastDocfxRunDetails.viewModel)]"
  Write-Information "  docfx debug:                 [$($global:lastDocfxRunDetails.debug)]"
  Write-Information "docfx_build_vm:"
  $docfx_build_vm | select-object -ExcludeProperty All, GroupByMessageSeverity, Warnings | format-list | out-host
  Write-Information "DocFx Message count by Severity:"
  Write-Information ($docfx_build_vm.GroupByMessageSeverity | format-table -AutoSize | out-String)
  Write-Information "Warnings: [$($docfx_build_vm.Warnings.ItemCount)]"
  Write-Information "Top Problem files: [$($docfx_build_vm.Warnings.TopProblemFiles.Count)]"
  Write-Information ($docfx_build_vm.Warnings.TopProblemFiles | format-table -autosize | out-string)
  Write-Information "By Code: [$($docfx_build_vm.Warnings.ByCode.Count)]"
  Write-Information ($docfx_build_vm.Warnings.Bycode | select-object CodeName, ItemCount | format-table -autosize | out-string)

}
function Remove-SpecFolder
{
  [CmdletBinding()]
  param([Parameter(ValueFromPipeline)]$Name, $Target)

  begin{}
  process{
    $specFolder = Join-Path -Path $Target -ChildPath $Name

    if (Test-Path $specFolder)
    {
      Write-Information "Removing obsolete Spec Folder [$($Name)] from [$($Target)]"
      Invoke-CommandWithRetry {if (Test-Path $specFolder) {Remove-Item $specFolder -Recurse -Force}} -RetryCount 99 -TimeoutInSecs 5
    }
    else
    {
      Write-Debug "Spec Folder [$($Name)] not found in [$($Target)], nothing to do."
    }
  }
  end{}
}

function Copy-NewSpecs
{
  [CmdLetBinding()]
  param([Parameter(ValueFromPipeline)]$SpecFolderName, $Source, $Destination)

  begin{}
  process
  {

  
    Write-Debug "Copying new spec [$SpecFolderName] from [$Source] to [$Destination]"
    
    $folderFrom = Join-Path -Path $Source -ChildPath $SpecFolderName
    $folderTo = Join-Path -Path $Destination -ChildPath $SpecFolderName

    Write-Debug "  - Source: [$folderFrom]"
    Write-Debug "  - Destination: [$folderTo]"
    
    Invoke-CommandWithRetry {Copy-Robo -source $folderFrom -destination $folderTo -Mirror -ShowFullPath -ShowVerbose} -RetryCount 99 -TimeoutInSecs 5
  }
  end
  {}
}

function Get-ObsoleteSpecFolders
{
  param($Current, $Target)

  $validNames = $current | select-object -ExpandProperty directory | select-object -ExpandProperty Name

  $validNames += "_site"
  $validNames += "dryRun_site"
  $validNames += "templates"


  if (Test-Path $Target)
  {
    return Get-ChildItem -Path $Target -Directory -exclude $validNames
  }
  
  return $null

}

function Remove-ObsoleteSpecFolder
{
  param($Obsolete)

  if (Test-Path $Obsolete)
  {
    Write-Information "Removing extra folder: [$($Obsolete.FullName)]"
    Invoke-CommandWithRetry {if (Test-Path $Obsolete) {Remove-Item $Obsolete -Recurse -Force}} -RetryCount 99 -TimeoutInSecs 5
  }
}

# ------------------------------------------------------------------------
$nerdStats = Start-NerdStats
Add-NerdStatsStep -Stats $nerdStats -Display "Checking the folders"

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
  docfxhelper_json    = (join-Path $global:PublisherLogsPath -ChildPath "docfxhelper.json")
  docfx_build_vm_json = (Join-Path $global:PublisherLogsPath -ChildPath "docfx.build.json")
}

Write-Host "DocFx files:"
Write-Host "  - docfx.json: [$($DocFxHelperFiles.docfx_json)]"
Write-Host "  - docfxhelper_json: [$($DocFxHelperFiles.docfxhelper_json)] (docfx helper viewModel used in templates)"
Write-Host "  - docfx_build_vm_json: [$($DocFxHelperFiles.docfx_build_vm_json)] (docfx build viewModel used in templates)"


# ------------------------------------------------------------------------
Add-NerdStatsStep -Stats $nerdStats -Display "Checking for new specs in Drops folder"
copy-item (join-path $global:StaticFolder -ChildPath "1.checkworktodo.html") -Destination (join-path $global:PublisherSitePath -ChildPath "index.html")


$specialInstructions = Get-SpecialInstructions -Path $DropsPath
Invoke-SpecialInstructions -specialInstructions $specialInstructions

$newSpecs = Get-NewSpecFolders -Path $DropsPath | Move-NewSpecToSources

$newSpecs | split-path -Leaf | Remove-SpecFolder -Target $DocFxHelperFolders.converted
$newSpecs | split-path -Leaf | Remove-SpecFolder -Target $DocFxHelperFolders.staging

# ------------------------------------------------------------------------
Add-NerdStatsStep -Stats $nerdStats -Display "Checking for specs.docs.json files"

$specsInSources = Get-SpecsDocsJson -Path $DocFxHelperFolders.sources -ExcludeSamples

if ($specsInSources.Count -gt 0)
{
  Remove-Samples -Path $DocFxHelperFolders.sources
}
else
{

  Write-Warning "No specs.docs.json file found in [$($DocFxHelperFolders.sources)]"
  Write-Host "Using the builtin Samples"

  # Copy-Samples -SourcePath (get-location).Path -DestinationPath $DocFxHelperFolders.sources
  Copy-Samples -SourcePath $PSScriptRoot -DestinationPath $DocFxHelperFolders.sources
}

Write-Host "Getting list of specs.docs.json"
$specs_docs_json_list = Get-SpecsDocsJson -Path $DocFxHelperFolders.sources

Write-Host "Loading [DocSpecs] object from specs.docs.json found in workspace.sources folder"
$specs = $specs_docs_json_list | ConvertFrom-Specs


if ($null -eq $specs.Main -or $specs.All.Count -eq 0) {
  Write-Warning "No specs found, nothing to do"
}
else 
{
  # ------------------------------------------------------------------------
  Add-NerdStatsStep -Stats $nerdStats -Display "Converting Doc Resources (ConvertTo-DocFx*)"

  Write-Host "Converting Doc Resources (ConvertTo-DocFx*)"
  copy-item (join-path $global:StaticFolder -ChildPath "3.conversion.html") -Destination (join-path $global:PublisherSitePath -ChildPath "index.html")

  $ConvertedSpecs = Invoke-SpecsConversion -AllSpecs $specs

  $obsoleteConverted = Get-ObsoleteSpecFolders -Current $specs_docs_json_list -Target $DocFxHelperFolders.converted

  if ($obsoleteConverted.Count -gt 0)
  {
    Write-Host "Removing [$($obsoleteConverted.Count)] extra folders from Workspace.Converted"

    foreach($obsolete in $obsoleteConverted)
    {
      Remove-ObsoleteSpecFolder -Obsolete $obsolete
    }
  }

  $obsoleteStaging = Get-ObsoleteSpecFolders -Current $specs_docs_json_list -Target $DocFxHelperFolders.staging

  if ($obsoleteStaging.Count -gt 0)
  {
    Write-Host "Removing [$($obsoleteStaging.Count)] extra folders from Workspace.Staging"

    foreach($obsolete in $obsoleteStaging)
    {
      Remove-ObsoleteSpecFolder -Obsolete $obsolete
    }
  }

  if ($ConvertedSpecs.Count -gt 0 -or $obsoleteConverted.Count -gt 0 -or $obsoleteStaging.Count -gt 0)
  {
    # ------------------------------------------------------------------------
    Add-NerdStatsStep -Stats $nerdStats -Display "Generating DocFx.json for resources"
    Write-Host "Generating DocFx.json for resources"
    copy-item (join-path $global:StaticFolder -ChildPath "4.assembly.html") -Destination (join-path $global:PublisherSitePath -ChildPath "index.html")

    New-DocFxJson -AllSpecs $specs

    # ------------------------------------------------------------------------
    Add-NerdStatsStep -Stats $nerdStats -Display "Adding Resources to DocFx.json"

    Add-SpecsToDocFxJson  -AllSpecs $specs

    # ------------------------------------------------------------------------
    Add-NerdStatsStep -Stats $nerdStats -Display "Generating files from templates"

    Write-Host "Generating files from templates"

    Invoke-Templates -AllSpecs $specs

    # ------------------------------------------------------------------------
    Add-NerdStatsStep -Stats $nerdStats -Display "DryRun Building DocFx"
    
    Write-Host "DryRun Building DocFx"
    copy-item (join-path $global:StaticFolder -ChildPath "5.dryrun.html") -Destination (join-path $global:PublisherSitePath -ChildPath "index.html")

    Invoke-DocFx -DryRun
    
    Show-DocFxDryRunDetails

    # ------------------------------------------------------------------------
    Add-NerdStatsStep -Stats $nerdStats -Display "Building DocFx site"
    Write-Host "Building DocFx final html files from [$($DocFxHelperFolders.staging)]"

    copy-item (join-path $global:StaticFolder -ChildPath "6.build.html") -Destination (join-path $global:PublisherSitePath -ChildPath "index.html")

    Invoke-DocFx

    # ------------------------------------------------------------------------
    Add-NerdStatsStep -Stats $nerdStats -Display "Publishing generated [_site] to folder [Site]"
    copy-item (join-path $global:StaticFolder -ChildPath "7.publish.html") -Destination (join-path $global:PublisherSitePath -ChildPath "index.html")

    $source = Join-Path $DocFxHelperFolders.staging -ChildPath "_site"
    $destination = $SitePath
    Write-Host "Site generated.  Copying to final destination"
    Write-Host "         site: $($source)"
    Write-Host "  destination: $($destination)"

    #& robocopy $source $destination /MIR /FP /V
    Invoke-CommandWithRetry {Copy-Robo -Source $source -Destination $destination -Mirror -ShowFullPath -ShowVerbose} -RetryCount 99 -TimeoutInSecs 5

  }
  else
  {
    Write-Debug "No specs has been converted, none was obsolete and removed, nothing else to do..."
  }
}

copy-item (join-path $global:StaticFolder -ChildPath "8.finished.html") -Destination (join-path $global:PublisherSitePath -ChildPath "index.html")

Stop-NerdStats -Stats $nerdStats
Show-NerdStats -Stats $nerdStats

exit 