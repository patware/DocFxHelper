#Requires -modules 'PlatyPS', 'Posh-git', 'Poshstache', 'yayaml'

. $PSScriptRoot/DocFxHelper.ps1

$script:SpecsIncludeVersions = @(
  [ordered]@{version = [Version]"0.1.1"; title = "DocSpecAdoWiki" }
  [ordered]@{version = [Version]"0.1.2"; title = "Using drops" }
  [ordered]@{version = [Version]"0.1.3"; title = "Dotnet Api" }
  [ordered]@{version = [Version]"0.1.4"; title = "REST Api" }
  [ordered]@{version = [Version]"0.1.5"; title = "Main" }
  [ordered]@{version = [Version]"0.1.6"; title = "Add-DocResource" }
  [ordered]@{version = [Version]"0.1.7"; title = "PowerShell Module" }
  [ordered]@{version = [Version]"0.1.7.1"; title = "ConvertTo-DocFxAdoWiki removed parameters" }
  [ordered]@{version = [Version]"0.1.7.2"; title = "ConvertTo-DocFxAdoWiki Added AllMetadataExportPath" }
  [ordered]@{version = [Version]"0.1.8"; title = "using Copy-Robo instead of robocopy" }
  [ordered]@{version = [Version]"0.1.8.1"; title = "Copy-Robo renamed param ShowVerbose" }
  [ordered]@{version = [Version]"0.1.9"; title = "Conceptual" }
  [ordered]@{version = [Version]"0.1.10"; title = "Using new docfxhelper as remote meta" }
  [ordered]@{version = [Version]"0.1.11"; title = "PowershellModule remove fake ps repo, Import-Module from path to psd1/psm1" }
  [ordered]@{version = [Version]"0.1.12"; title = "Add properties Medias and Excludes to DocSpecResource type" }
  [ordered]@{version = [Version]"0.1.13"; title = "Try catch around PS PowerShell Module" }
  [ordered]@{version = [Version]"0.1.14"; title = "PowerShell module spec loading, setting Psd1 value fallback using any psd1/psm1 file found in path" }
  [ordered]@{version = [Version]"0.1.14.1"; title = "Wrapped IO commands with CommandWithRetry to get around IO issues" }
  [ordered]@{version = [Version]"0.1.14.2"; title = "Fix: problem with Remove-Item, solution = Use the -Force" }
  [ordered]@{version = [Version]"0.1.14.3"; title = "Fix: Still failed remove-items, bumping RetryCount to 50!" }
  [ordered]@{version = [Version]"0.1.15"; title = "Logging in the Virtual Path when not set" }
  [ordered]@{version = [Version]"0.1.15.1"; title = "Remove-items got close to 50, bumping RetryCount to 99!" }
  [ordered]@{version = [Version]"0.1.16"; title = "Add missing RepoRelativePath arg" }
  [ordered]@{version = [Version]"0.1.17"; title = "New spec type ApiYaml" }
)

$global:SpecsIncludeVersion = $SpecsIncludeVersions[-1]
Write-Host "specs.include.ps1 Version [$($global:SpecsIncludeVersion.Version)] $($global:SpecsIncludeVersion.title)"

#region DocSpec classes
enum DocSpecType
{
  Main = 1
  AdoWiki = 2
  DotnetApi = 3
  RestApi = 4
  PowerShellModule = 5
  Conceptual = 6
  Template = 7
  ApiYaml = 8
}

class DocSpecTemplate
{
  [DocSpec]$Spec
  [string]$Name
  [string]$Template
  [string]$Dest
}

class DocSpec
{
  [DocSpecType]$Type
  [System.IO.DirectoryInfo]$Path
  [DocSpecTemplate[]]$Templates
}


class DocSpecResource : DocSpec
{
  [string]$Id
  [string]$Name
  [string]$ParentId
  [string]$Target = "/"
  [bool]$IsRoot
  [Uri]$CloneUrl
  [string]$MenuParentItemName
  [string]$MenuDisplayName
  [int]$MenuPosition = -1
  [string]$Homepage
  [string]$MenuUid
  [string]$RepoRelativePath
  [string]$Branch = "main"
  [string[]]$Excludes = @()
  [string[]]$Medias = @()

  hidden [string]$_virtualPath
  [string]VirtualPath()
  {
    if ($null -eq $this._virtualPath)
    {
      Write-Debug "VirtualPath not set for ID: [$($this.Id)] - Calculating Virtual Path Fixed"
      $baseUri = [Uri]::new("http://home.local")
      $this._virtualPath = [Uri]::new($baseUri, (("/$($this.Target)/" -split "/" | where-object { $_ })) -join "/").AbsolutePath
      Write-Debug "VirtualPath for ID: [$($this.Id)] - [$($this._virtualPath)]"
    }

    return $this._virtualPath
  }

  SetDefaults()
  {
    if ([string]::IsNullOrEmpty($this.Name))
    {
      $this.Name = $this.Id

      if (![string]::IsNullOrEmpty($this.MenuDisplayName))
      {
        $this.Name = $this.MenuDisplayName
      }
    }
  }
}

class DocSpecMain : DocSpec
{
  [System.IO.FileInfo]$DocFx_Json
  [bool]$UseModernTemplate

  LoadFromDocFxJson()
  {
    if ($this.DocFx_Json)
    {
      $docfx = Get-Content (Join-Path $this.Path -ChildPath $this.DocFx_Json) | ConvertFrom-Json

      $this.UseModernTemplate = $docfx.build.template -contains "modern"
    }
  }

}
class DocSpecAdoWiki : DocSpecResource
{
  [Uri]$WikiUrl
}

class DocSpecPowershellModule : DocSpecResource
{
  [string]$Psd1

  SetDefaults()
  {
    ([DocSpecResource]$this).SetDefaults()

    if ([string]::IsNullOrEmpty($this.Psd1))
    {
      $f = Join-Path $this.Path -ChildPath "$($this.Name).psd1"
      if (Test-Path $f)
      {
        Write-Debug "Found .psd1 with the given spec name: [$($f)]"
        $this.Psd1 = $f
      }
      else
      {
        $f = Join-Path $this.Path -ChildPath "$($this.Name).psm1"
        if (Test-Path $f)
        {
          Write-Debug "Found .psm1 with the given spec name: [$($f)]"
          $this.Psd1 = $f
        }
        else
        {
          $f = Get-ChildItem -Path $this.Path -Filter "*.psd1"

          if ($f)
          {
            $this.Psd1 = $f | select-object -first 1 -ExpandProperty FullName
            Write-Debug "Found a .psd1 in the spec path: [$($this.Psd1)]"
          }
          else
          {
            $f = Get-ChildItem -Path $this.Path -Filter "*.psm1"
           
            if ($f)
            {
              $this.Psd1 = $f | select-object -first 1 -ExpandProperty FullName
              Write-Debug "Found a .psm1 in the spec path: [$($this.Psd1)]"
            }
            else
            {
              Write-Warning "No .psd1 nor any .psm1 found for this PowerShell Module."
              Write-Information "  Check the files in path: [$($this.Path)]"
            }
            
          }
        }
      }
    }
  }
}

class DocSpecs
{
  [DocSpecMain]$Main
  [System.Collections.Generic.Dictionary[string, DocSpecResource]]$All
  [System.Collections.Generic.Dictionary[string, DocSpecResource[]]]$Hierarchy
  [System.Collections.Generic.List[DocSpecResource]]$Ordered
  [System.Collections.Generic.Dictionary[string, DocSpecResource[]]]$Children
  [System.Collections.Generic.List[DocSpecTemplate]]$Templates

  DocSpecs()
  {
    $this.All = [System.Collections.Generic.Dictionary[string, DocSpecResource]]::new()
    $this.Hierarchy = [System.Collections.Generic.Dictionary[string, DocSpecResource[]]]::new()
    $this.Ordered = [System.Collections.Generic.List[DocSpecResource]]::new()
    $this.Children = [System.Collections.Generic.Dictionary[string, DocSpecResource[]]]::new()        
    $this.Templates = [System.Collections.Generic.List[DocSpecTemplate]]::new()
  }

  [DocSpec] Add([System.IO.FileInfo]$path)
  {
    $spec = Get-Content $path | ConvertFrom-Json
    $docSpec = $null

    if ([DocSpecType]$spec.Type -eq [DocSpecType]::Main)
    {
      $docSpec = [DocSpecMain]$spec
      $docSpec.Path = $path.Directory
      $docSpec.LoadFromDocFxJson()
      $this.Main = $docSpec
    }
    else
    {
      if ([DocSpecType]$spec.Type -eq [DocSpecType]::AdoWiki)
      {
        $docSpec = [DocSpecAdoWiki]$spec
      }
      elseif ([DocSpecType]$spec.Type -eq [DocSpecType]::PowerShellModule)
      {
        $docSpec = [DocSpecPowershellModule]$spec
      }
      else
      {
        $docSpec = [DocSpecResource]$spec
      }

      $docSpec.Path = $Path.Directory

      $docSpec.SetDefaults()
      
    }
        
    [void]$this.Add($docSpec)

    return $docSpec
  }
  [DocSpec] Add([DocSpec]$spec)
  {
    if ($spec -is [DocSpecResource])
    {
      [void]$this.All.Add($spec.Id, $spec)
    }

    foreach ($t in $Spec.Templates)
    {
      $t.Spec = $Spec

      [void]$this.Templates.Add($t)
    }

    return $spec
  }

  BuildHierarchy()
  {
    
    if ($this.All.Values.Count -eq 0)
    {
      Write-Debug "Nothing to sort, no resource."
      return 
    }

    Write-Debug "Sorting the list of resources topologically based on Id and ParentId"
    $sorted = Get-ListSortedTopologically -IdName "Id" -ParentIdPropertyName "ParentId" -Data $this.All.Values
        
    foreach ($spec in $sorted)
    {
      Write-Debug "BuildHierarchy - $($spec.Id)"
      [void]$this.Ordered.Add($spec)
      [void]$this.Children.Add($spec.Id, ($sorted | where-object { $_.ParentId -eq $spec.Id }))
      [void]$this.Hierarchy.Add($spec.Id, ($sorted | where-object { $_.Id -ne $spec.Id -and $_.VirtualPath() -like "$($spec.VirtualPath())*" }))
    }
  }
}
#endregion

#region specs.docs.json related functions
<#
    .SYNOPSIS
    Sorts a list using a Dependency Graph approach, grand parents first, then parents, then children...

    .DESCRIPTION
    Uses the -IdName and -ParentIdPropertyName to identify the Parent-Child relationship to build a dependency graph
    and return the list of items sorted Top-First

#>
function Get-ListSortedTopologically
{
  [cmdletBinding()]
  param(
    [Parameter(Mandatory, Position = 0)][Object[]]$Data,
    [Parameter(Position = 1)][string]$IdName = "Id",
    [Parameter(Position = 2)][string]$ParentIdPropertyName = "ParentId"
  )

  process
  {
    $res = [System.Collections.ArrayList]::new()

    $todo = $Data

    $whereScriptBlocks = [System.Collections.ArrayList]::new()

    Write-Debug "Adding [Filter] Items without a parent"

    [void]$whereScriptBlocks.Add({ $null -eq $_."$parentIdPropertyName" })

    Write-Debug "Checking for items with a [$parentIdPropertyName] that doesn't exist in the [$idName]"

    $foobarIds = $todo | where-object { $null -ne $_."$parentIdPropertyName" -and $_."$parentIdPropertyName" -notin $todo."$idName" }

    if ($foobarIds)
    {
      Write-Debug "Adding [Filter] Items with a non-existent parent"
      [void]$whereScriptBlocks.Add({ $_."$idName" -in $foobarIds })
    }

    $counter = 0

    while ($todo.Count -gt 0 -and $whereScriptBlocks.count -gt 0)
    {
      $counter++
      Write-Verbose "Round #$($counter)"
      $whereScriptBlock = $whereScriptBlocks[0]
      $whereScriptBlocks.RemoveAt(0)

      Write-Debug "Searching for [$whereScriptBlock]"

      $thisBatch = $todo  | where-object $whereScriptBlock

      if ($thisBatch.Count -gt 0)
      {
        foreach ($item in $thisBatch)
        {
          if ($DebugPreference -eq 'Continue')
          {
            Write-Debug ($item | convertto-json)
          }
          [void]$res.Add([PSCustomObject]$item)
        }
        

        Write-Debug "Found $($thisBatch.Count) items"

        $thisBatchIds = $thisBatch | Select-Object id -ExpandProperty "$idName"
        Write-Debug "Found ids in this batch [$($thisBatchIds -join ",")]"
        Write-Debug "Adding [Filter] for next batch"

        [void]$whereScriptBlocks.Add({ $_."$parentIdPropertyName" -in $thisBatchIds })

        $todo = $todo | where-object { $_."$idName" -notin $thisBatchIds }

      }

      Write-Debug($todo | format-table -AutoSize | Out-String)
      Write-Debug "Remaining number of items to filter: [$($todo.Count)]"
    }

    return $res.ToArray()
  }
}

<#
    .SYNOPSIS
    Builds a specs object from every specs.docs.json in the drops folder
#>
function ConvertFrom-Specs
{
  [OutputType([DocSpecs])]
  [CmdletBinding()]
  param(
    [System.IO.FileInfo]$Path,
    [parameter(ValueFromPipeline)][object[]]$InputObject
  )

  begin
  {
    $private:ret = [DocSpecs]::new()
  }
  process
  {
    foreach ($item in $InputObject)
    {
      Write-Information "ConvertFrom-specs item [$Item]"
      if (Test-Path $item)
      {
        [void]$ret.Add($item)
      }
    }

    if ($Path)
    {
      Write-Information "ConvertFrom-specs path [$Path]"
      [void]$ret.Add($Path)
    }
  }
  end
  {
    $ret.BuildHierarchy()
    return $ret
  }

}


function Get-FolderHash
{
  param([System.IO.DirectoryInfo]$Path)

  $tmp = New-TemporaryFile

  Get-ChildItem -Path $Path  -Recurse -Force | Get-FileHash -ErrorAction SilentlyContinue | set-content $tmp

  $ret = Get-FileHash -Path $tmp

  remove-item $tmp -Force -ErrorAction SilentlyContinue

  return $ret.Hash
}

enum State
{
  Same = 0
  New = 1
  Different = 2
  Deleted = 3
}

<#
    .SYNOPSIS
    Gets a list of new, update or delete doc resources

    .DESCRIPTION
    Compares the specs from the drops folders and those from the DocfxHelper/sources
#>
function Get-DocResourcesChanges
{
  param([Parameter(Mandatory)][DocSpecs]$Specs, [Parameter(Mandatory)]$SourcesPath)

  $ret = @()
    
  $verifiedSourcesNames = @()

  foreach ($spec in $Specs.Ordered)
  {
    <#
            $spec = $Specs.Ordered | select-object -first 1
            $spec
        #>
    $item = [ordered]@{
      Id         = $spec.Id
      Name       = $spec.Path.Name
      SpecPath   = $spec.Path
      SpecHash   = Get-FolderHash -Path $spec.Path
      SourcePath = Join-Path $SourcesPath -ChildPath $spec.Path.Name
      SourceHash = $null
      State      = [State]::Same
    }

    if (Test-Path $sourcePath)
    {
      $verifiedSourcesNames += $spec.Path.Name
      $item.SourceHash = Get-FolderHash -Path $sourcePath

      if ($item.SourceHash -ne $item.SpecHash)
      {
        $item.State = [State]::Different
      }
    }
    else
    {
      $item.State = [State]::new
    }

    $ret += $item
  }

  if (Test-Path $sourcesPath)
  {
    foreach ($deletedSource in Get-ChildItem -Path $sourcesPath -Directory -Force | where-object { $_.Name -ne $verifiedSourcesNames })
    {
      $ret += [ordered]@{
        Id         = $null
        Name       = $null
        SpecPath   = $null
        SpecHash   = $null
        SourcePath = $deleteSource
        SourceHash = $null
        State      = [State]::Deleted
      }
    }        
  }

  return $ret
}

function Get-SpecIdsToUpdate
{
  param([DocSpecs]$Specs, $changeList)
  $ret = @()

  foreach ($specToProcess in $changeList | where-object { $_.State -in ([State]::new, [State]::Different) } )
  {
    <#
            $specToProcess = $changeList | select-object -first 1
            $specToProcess
        #>
    $ret += $specToProcess.Id
    foreach ($child in $specs.Hierarchy."$($specToProcess.Id)")
    {
      if (!($ret.Contains($child.Id)))
      {
        $ret += $child.Id
      }
    }
  }

  return $ret
}
#endregion

#region PowerShell Module Specific
function Register-PowerShellModuleFakePSRepository
{
  param(
    [Parameter(Mandatory)][System.IO.DirectoryInfo]$Path, 
    [Parameter(Mandatory)][string]$ModuleName
  )

  Register-PSRepository -Name "$ModuleName"  -SourceLocation $Path.FullName -InstallationPolicy Trusted
}


function Get-PowerShellModuleExportedFunction
{
  param([parameter(Mandatory)]$ModuleDetails)

  return (Get-Command -Module $ModuleDetails.Name) | select-object `
    name `
    , @{l = "scriptRelativePath"; e = { (Resolve-Path $_.ScriptBlock.File -Relative -RelativeBasePath $ModuleDetails.ModuleBase) } } `
    , @{l = "startLine"; e = { $_.ScriptBlock.StartPosition.StartLine } } `
    , @{l = "endLine"; e = { $_.ScriptBlock.StartPosition.EndLine } }

}

function Get-PowerShellModuleItemUri
{
  param(
    [Parameter(Mandatory)][Uri]$CloneUrl,
    [Parameter(Mandatory)][string]$ItemRelativePath,
    [Parameter(Mandatory)][string]$ModuleRelativePath
  )
  $baseUri = [Uri]$CloneUrl
  $ModuleRelativePathFixed = ("$($ModuleRelativePath)".Replace("\", "/") -split "/" | where-object { $_ }) -join "/"
  $ItemRelativePathFixed = ("$($ItemRelativePath)".Replace("\", "/") -split "/" | where-object { $_ -and $_ -ne "." }) -join "/"
  $href = [Uri]::new($baseUri, "?path=/$ModuleRelativePathFixed/$ItemRelativePathFixed")
  return $href.AbsoluteUri
}

function ConvertTo-PowerShellModuleFunctionHelp
{
  [CmdletBinding()]
  param(
    [Parameter(ValueFromPipelineByPropertyName)][string]$Name,
    [Parameter(ValueFromPipelineByPropertyName)][string]$ScriptRelativePath,
    [Parameter(ValueFromPipelineByPropertyName)][int]$startLine,
    [Parameter(ValueFromPipelineByPropertyName)][int]$endLine,
    [Parameter(Mandatory)][Uri]$CloneUrl, 
    [Parameter(Mandatory)][System.IO.DirectoryInfo]$Target,
    [string]$RepoBranch = "main",
    [string]$ModuleRelativePath
  )

  begin
  {
  }
  process
  {
        
    Write-Debug "----------------------------------"
    Write-Debug "              Name: [$($Name)]"
    Write-Debug "ScriptRelativePath: [$($ScriptRelativePath)]"
    Write-Debug "         StartLine: [$($startLine)]"
    Write-Debug "           EndLine: [$($endLine)]"
    Write-Debug "          CloneUrl: [$($CloneUrl)]"
    Write-Debug "            Target: [$($Target)]"
    Write-Debug "ModuleRelativePath: [$($ModuleRelativePath)]"

    if (!(Test-Path $Target))
    {
      New-Item $Target -ItemType Directory | Out-Null
    }

    Write-Debug "[PlatyPs] New-MarkdownHelp -Command $name"
    $generated = New-MarkdownHelp -Command $name -OutputFolder $Target -Verbose -Force

    if ([string]::IsNullOrEmpty($ModuleRelativePath))
    {
      Write-Information "-ModuleRelativePath not provided, defaulting to src/{moduleName}"
      $ModuleRelativePath = "src/$Name"
    }

    $href = Get-PowerShellModuleItemUri -CloneUrl $CloneUrl -ItemRelativePath $ScriptRelativePath -ModuleRelativePath $ModuleRelativePath

    $meta = [ordered]@{
      href      = $href
      repo      = "$CloneUrl"
      branch    = $RepoBranch
      path      = $href.Split("?path=")[1]
      startLine = $startLine
      endLine   = $endLine
    }
                
    Util_Set_MdYamlHeader -file $generated.FullName -key "metadata" -value $meta


  }
  end {}
}

function Get-PowerShellModuleViewModel
{
  param($moduleDetails, $ModuleRelativePath, $CloneUrl, $RepoBranch = "main")

  Write-Debug "Get-PowerShellModuleViewModel"
  Write-Debug "moduleDetails      = [$($moduleDetails)]"
  Write-Debug "ModuleRelativePath = [$($ModuleRelativePath)]"
  Write-Debug "CloneUrl           = [$($CloneUrl)]"
  Write-Debug "RepoBranch         = [$($RepoBranch)]"

  $href = Get-PowerShellModuleItemUri -CloneUrl $CloneUrl -ModuleRelativePath $ModuleRelativePath -ItemRelativePath $moduleDetails.RootModule

  $ret = [ordered]@{
    Name               = $moduleDetails.Name
    Description        = $moduleDetails.Description
    Version            = $moduleDetails.Version
    VersionString      = "$($moduleDetails.Version)"
    Author             = $moduleDetails.Author
    HelpInfoUri        = $moduleDetails.HelpInfoUri
    ProjectUri         = $moduleDetails.ProjectUri
    Tags               = $moduleDetails.Tags
    ReleaseNotes       = $moduleDetails.ReleaseNotes
    RootModule         = $moduleDetails.RootModule
    ModuleRelativePath = $ModuleRelativePath
    Repo               = $CloneUrl
    Branch             = $RepoBranch
    Path               = "$href".Split("?path=")[1]
    RootModuleUri      = "$href"
    ExportedFunctions  = Get-Command -module $moduleDetails.Name | sort-object Name | get-help | select-object name, Synopsis
    Raw                = $moduleDetails
  }

  return [PSCustomObject]$ret
}

function New-PowerShellModuleIndex
{
  param($Target, $viewModel)

  $index_md_mustache = (join-path $PSScriptRoot -ChildPath "PowerShellModules.index.md.mustache")
  $index_md = (join-path $Target -ChildPath "index.md")

  Write-Debug "index.md mustache template [$($index_md_mustache)]"
  Write-Debug "index.md target [$($index_md)]"

  ConvertTo-PoshstacheTemplate -InputFile $index_md_mustache -ParametersObject ($viewModel | ConvertTo-Json -Depth 3) -Verbose | set-content $index_md

}

function New-PowerShellModuleToc
{
  param($Target, $viewModel)

  $toc_yml_mustache = (join-path $PSScriptRoot -ChildPath "PowerShellModules.toc.yml.mustache")
  $toc_yml = (join-path $Target -ChildPath "toc.yml")

  Write-Debug "toc.yml mustache template [$($toc_yml_mustache)]"
  Write-Debug "toc.yml target [$($toc_yml)]"


  ConvertTo-PoshstacheTemplate -InputFile $toc_yml_mustache -ParametersObject ($viewModel | ConvertTo-Json -Depth 3) | set-content $toc_yml

}


#endregion

function Convert-DocResource
{
  param(
    [Parameter(Mandatory)][DocSpec]$Spec,  
    [Parameter(Mandatory)][System.IO.DirectoryInfo]$Path, 
    [Parameter(Mandatory)][System.IO.DirectoryInfo]$Destination,
    [switch]$UseModernTemplate
  )

  <#
        $Spec
        $Spec.UseModernTemplate
        $Path 
        $Destination 
    #>

  Write-Information "[Convert-DocResource]"
  Write-Information "            Spec Id [$($spec.Id)]"
  Write-Information "          Spec Type [$($spec.Type)]"
  Write-Information "        Spec Target [$($Spec.Target)]"
  Write-Information "              -Path [$($Path)]"
  Write-Information "       -Destination [$($Destination)]"
  Write-Information " -UseModernTemplate [$($UseModernTemplate)]"

    
  $pagesUidPrefix = Get-DocFxHelperResourcePageUidPrefix -Target $Spec.Target

  Write-Information "Pages UID Prefix [$($pagesUidPrefix)]"
   

  switch ($spec.Type)
  {
    AdoWiki
    {

      Write-Information "Ado Wiki Url [$($spec.WikiUrl)]"

      Write-Debug "Copy-Robo $Path $Destination -Mirror"
      Copy-Robo -Source $Path -Destination $Destination -Mirror -ShowFullPath -ShowVerbose

      $a = @{}

      if ($UseModernTemplate) { $a.UseModernTemplate = $true }
      if ($spec.IsRoot) { $a.IsRootWiki = $spec.IsRoot }
      if ($spec.RepoRelativePath) {$a.RepoRelativePath = $spec.RepoRelativePath}

      $a.AllMetadataExportPath = (Join-Path (Split-Path $Destination) -ChildPath "$(Split-Path $Destination -Leaf).allmetadata.json")
            
      Write-Information "Calling ConvertTo-DocFxAdoWiki -Path $Destination -WikiUri $($spec.WikiUrl) -PagesUidPrefix $pagesUidPrefix"

      ConvertTo-DocFxAdoWiki `
        -Path "$Destination" `
        -WikiUri $spec.WikiUrl `
        -PagesUidPrefix "$pagesUidPrefix" `
        @a

    }
    DotnetApi
    {

      Write-Information ".Net API"

      $docfx_metadata = [ordered]@{
        metadata = @(
          [ordered]@{
            src  = @(
              [ordered]@{                        
                files = @("**.dll")
                src   = "$Path"
              }
            )
            dest = "$Destination"
          }
        )
      }
      $docfx_json = "./docfx.json"
      $docfx_metadata_log_json = "./docfx.metadata.log.json"

      if (Test-Path $docfx_metadata_log_json)
      {
        remove-item $docfx_metadata_log_json -Force
      }

      $docfx_metadata | convertTo-json -Depth 5 | set-content $docfx_json

      & docfx metadata --log $docfx_metadata_log_json --logLevel verbose

      if (Test-Path $docfx_metadata_log_json)
      {
        $docfx_metadata_log = get-content $docfx_metadata_log_json | convertfrom-json

        Write-Information "docfx metadata logs:"

        $docfx_metadata_log | Group-Object severity | select-object Name, Count | format-table -AutoSize | out-Host

        remove-item $docfx_metadata_log_json -Force
      }

      if (Test-Path $docfx_json)
      {
        remove-item $docfx_json -Force
      }

    }
    RestApi
    {

      Write-Information "REST API - will use swagger.json at docfx build"
            
      Write-Debug "Copy-Robo $Path $Destination"
      Copy-Robo -Source $Path -Destination $destination -Mirror -ShowFullPath -ShowVerbose

    }
    PowerShellModule
    {
      Write-Information "PowerShell Module"

      #Register-PowerShellModuleFakePSRepository -Path $Path -ModuleName $spec.Name
      #Install-Module $spec.Name -Repository $spec.Name -scope CurrentUser
      Write-Information "Import-Module `$spec.Psd1 [$($spec.Psd1)]"

      $importedModule = $null
      try
      {
        $importedModule = Import-Module $spec.Psd1 -Force -PassThru 
      }
      catch{
        Write-Warning "Problem importing module [$($spec.Psd1)]"
        Write-Host "Error:"
        Write-Host "Message: $($Error[0].Exception.Message)"
        Write-Host "Source: $($Error[0].Exception.Source)"
      }
      
      if ($importedModule)
      {
        $moduleDetails = Get-Module $spec.Name
        $exportedFunctions = Get-PowerShellModuleExportedFunction -ModuleDetails $moduleDetails
        $exportedFunctions | ConvertTo-PowerShellModuleFunctionHelp -CloneUrl $spec.CloneUrl -ModuleRelativePath $spec.RepoRelativePath -RepoBranch $spec.Branch -Target $Destination
        $viewModel = Get-PowerShellModuleViewModel -moduleDetails $moduleDetails -CloneUrl $spec.CloneUrl -ModuleRelativePath $spec.RepoRelativePath -RepoBranch $spec.Branch
        New-PowerShellModuleIndex -ViewModel $viewModel -Target $Destination
        New-PowerShellModuleToc -ViewModel $viewModel -Target $Destination
              
        Remove-Module $spec.Name -ErrorAction SilentlyContinue

        $a = @{}
        if ("" -ne "$($spec.Branch)") { $a.RepoBranch = $spec.Branch }
        if ("" -ne "$($spec.RepoRelativePath)") { $a.RepoRelativePath = $spec.RepoRelativePath }
        ConvertTo-DocFxPowerShellModule -Path $Destination -PagesUidPrefix $pagesUidPrefix -CloneUrl $Spec.CloneUrl @a
  
      }
      else
      {
        Write-Host "Ignored: [$($spec.Name)] because couldn't load module"
      }

    }
    Conceptual
    {
      Write-Information "Conceptual - just copy to converted"
            
      Write-Debug "Copy-Robo $Path $Destination"   
      Invoke-CommandWithRetry {Copy-Robo -Source $Path -Destination $destination -Mirror -ShowFullPath -ShowVerbose} -RetryCount 99 -TimeoutInSecs 5
            
      $a = @{}
      if ("" -ne "$($spec.Branch)") { $a.RepoBranch = $spec.Branch }
      if ("" -ne "$($spec.RepoRelativePath)") { $a.RepoRelativePath = $spec.RepoRelativePath }
            
      Write-Information "Calling ConvertTo-DocFxAdoWiki -Path $Destination -PagesUidPrefix $pagesUidPrefix"

      ConvertTo-DocFxConceptual `
        -Path "$Destination" `
        -CloneUrl $Spec.CloneUrl `
        -PagesUidPrefix $pagesUidPrefix `
        @a
    }
    Template
    {

    }
    ApiYaml
    {
      Write-Information "ApiYaml - just copy to /converted, no conversion needed"
            
      Write-Debug "Copy-Robo $Path $Destination"   
      Invoke-CommandWithRetry {Copy-Robo -Source $Path -Destination $destination -Mirror -ShowFullPath -ShowVerbose} -RetryCount 99 -TimeoutInSecs 5

    }
  }

  Write-Information "$($spec.Id) Converted"
}
function Add-DocResource
{
  param(
    [Parameter(Mandatory)][DocSpec]$Spec,  
    [Parameter(Mandatory)][System.IO.DirectoryInfo]$Path, 
    [Parameter(Mandatory)][System.IO.DirectoryInfo]$Destination
  )

  <#
        $Spec
        $Path 
        $Destination 
    #>

  Write-Information "Adding $($spec.Id)"

  if (Test-Path $Path)
  {
    Invoke-CommandWithRetry {Copy-Robo -Source $Path -Destination $Destination -Mirror} -RetryCount 99 -TimeoutInSecs 5
  }

  switch ($spec.Type)
  {
    AdoWiki
    {
      Add-AdoWiki `
        -Path $destination `
        -Id $spec.Id `
        -CloneUrl $spec.CloneUrl `
        -WikiUrl $spec.WikiUrl `
        -Target $spec.Target `
        -MenuParentItemName $spec.MenuParentItemName `
        -MenuDisplayName $spec.MenuDisplayName `
        -MenuPosition $spec.MenuPosition `
        -Homepage $spec.Homepage `
        -MenuUid $spec.MenuUid `
        -Excludes $spec.Excludes `
        -WikiDocsSubfolder $spec.WikiDocsSubfolder `
        -Medias $spec.Medias `
        -ParentId $spec.ParentId
    }
    DotnetApi
    {
      Add-DotnetApi `
        -Path $destination `
        -Id $spec.Id `
        -Target $spec.Target `
        -MenuParentItemName $spec.MenuParentItemName `
        -MenuDisplayName $spec.MenuDisplayName `
        -MenuPosition $spec.MenuPosition `
        -MenuUid $spec.MenuUid `
        -Excludes $spec.Excludes `
        -Medias $spec.Medias `
        -ParentId $spec.ParentId
    }
    RestApi
    {
      Add-RestApi `
        -Path $destination `
        -Id $spec.Id `
        -Target $spec.Target `
        -MenuParentItemName $spec.MenuParentItemName `
        -MenuDisplayName $spec.MenuDisplayName `
        -MenuPosition $spec.MenuPosition `
        -MenuUid $spec.MenuUid `
        -Excludes $spec.Excludes `
        -Medias $spec.Medias `
        -ParentId $spec.ParentId
    }
    PowerShellModule
    {
      Add-PowerShellModule `
        -Path $destination `
        -Id $spec.Id `
        -CloneUrl $spec.CloneUrl `
        -RepoRelativePath $spec.RepoRelativePath `
        -Target $spec.Target `
        -MenuParentItemName $spec.MenuParentItemName `
        -MenuDisplayName $spec.MenuDisplayName `
        -MenuPosition $spec.MenuPosition `
        -Homepage $spec.Homepage `
        -MenuUid $spec.MenuUid `
        -Excludes $spec.Excludes `
        -Medias $spec.Medias `
        -ParentId $spec.ParentId
    }
    Conceptual
    {
      Add-Conceptual `
        -Path $destination `
        -Id $spec.Id `
        -CloneUrl $spec.CloneUrl `
        -RepoRelativePath $spec.RepoRelativePath `
        -Target $spec.Target `
        -MenuParentItemName $spec.MenuParentItemName `
        -MenuDisplayName $spec.MenuDisplayName `
        -MenuPosition $spec.MenuPosition `
        -Homepage $spec.Homepage `
        -MenuUid $spec.MenuUid `
        -Excludes $spec.Excludes `
        -Medias $spec.Medias `
        -ParentId $spec.ParentId
    }
    Template {}
    ApiYaml {
      Add-ApiYaml `
        -Path $destination `
        -Id $spec.Id `
        -Target $spec.Target `
        -MenuParentItemName $spec.MenuParentItemName `
        -MenuDisplayName $spec.MenuDisplayName `
        -MenuPosition $spec.MenuPosition `
        -MenuUid $spec.MenuUid `
        -Excludes $spec.Excludes `
        -Medias $spec.Medias `
        -ParentId $spec.ParentId
    }
  }

  Write-Information "$($spec.Id) added."

}