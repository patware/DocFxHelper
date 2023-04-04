#Requires -Version 7
#Requires -Modules 'Posh-git', 'Powershell-Yaml', 'Poshstache'

<#
  Normal mode:
    $ErrorActionPreference = 'Continue'
    $VerbosePreference = 'SilentlyContinue'
    $DebugPreference = 'SilentlyContinue'

  Verbose mode, more output
    $ErrorActionPreference = 'Inquire'
    $VerbosePreference = 'Continue'
    $DebugPreference = 'SilentlyContinue'

  Debug mode, all output
    $ErrorActionPreference = 'Break'
    $InformationPreference = 'Continue'
    $VerbosePreference = 'Continue'
    $DebugPreference = 'Continue'
#>


$baseUrl = "http://home.local"
$baseUri = [Uri]::new($baseUrl)

enum SourceType {
  Unknown = 0
  Repository = 1
  PipelineArtifact = 2
}
enum ResourceType {
  Unknown = 0
  Wiki = 1
  Api = 2
  Conceptual = 3
  PowerShellModule = 4
}

$private:knownArtifactNames = @("Docs.ApiYaml", "Docs.ConceptualDocs", "Drop")

$private:requiredModules = @("Posh-git", "Powershell-Yaml", "Poshstache")

foreach($private:requiredModule in $private:requiredModules)
{
  if (Get-Module $private:requiredModule)
  {
    Write-Verbose "Module $($private:requiredModule) already loaded"
  }
  else
  {
    Write-Verbose "Loading module $($private:requiredModule)"
    import-module $private:requiredModule -Verbose
  }

}


function script:Get-ResourcePageUidPrefix
{
  param($relativePath)

  $private:homeUrl = "http://home.local"
  $private:homeUri = [Uri]::new($homeUrl)
  $private:siteUri = [Uri]::new($homeUri, "$relativePath")

  $private:sitePath = $siteUri.AbsolutePath

  $private:pagesUidPrefix = "$($private:sitePath)".Replace("\","/").Replace("/", "_")
  $private:pagesUidPrefix = "$($private:pagesUidPrefix)" -replace '(_*)(.*)', '$2'
  $private:pagesUidPrefixSegments = $private:pagesUidPrefix.Split("_")
  
  $private:pagesUidPrefix = ($private:pagesUidPrefixSegments | where-object {$_}) -join "_"
  
  if ("$private:pagesUidPrefix" -ne "")
  {
    $private:pagesUidPrefix = "$($private:pagesUidPrefix)_"
  }
  
  return $private:pagesUidPrefix
}


function script:Get-MdYamlHeader
{
  param($file)
  
  Write-Debug "Get-MdYamlHeader"
  Write-Debug "  file: [$file]"
  $private:md = Convert-FromMdFile -file $file

  return $private:md.data
 
}

function script:Convert-FromMdFile
{
  param($file)

  Write-Debug "Convert-FromMdFile"
  Write-Debug "  file: [$file]"

  $private:content = get-content -path $file

  $private:yamlHeaderMarkers = $private:content | select-string -pattern '^---\s*$'

  $private:ret = @{
    data = [ordered]@{}
    conceptual = $private:content
  }

  if ($private:yamlHeaderMarkers.count -ge 2 -and $private:yamlHeaderMarkers[0].LineNumber -eq 1)
  {
    Write-Debug "Markdown file has Yaml Header Markers"
    $private:yaml = $private:content[1 .. ($private:yamlHeaderMarkers[1].LineNumber - 2)]
    $private:ret.data = ConvertFrom-Yaml -Yaml ($private:yaml -join "`n") -Ordered
    $private:ret.conceptual = $private:content | select-object -skip $private:yamlHeaderMarkers[1].LineNumber
  }

  return $private:ret

}

function script:Set-MdYamlHeader
{
  param($file, $data, $key, $value)
  
  Write-Debug "Set-MdYamlHeader"
  Write-Debug "  file: [$file]"
  Write-Debug "   key: [$key]"
  Write-Debug " value: [$value]"
  
  $private:mdFile = Convert-FromMdFile -file $file

  if ($data)
  {
    $private:mdFile.data = $data
  }

  if ($key)
  {
    $private:mdFile.data[$key] = $value
  }

  $private:content = "---`n$(ConvertTo-Yaml -Data $private:mdFile.data  )---`n$($private:mdFile.conceptual -join "`n")"

  $private:content | set-content -path $file

}


function script:Get-PageUid
{
  param($pagesUidPrefix, $mdFile)

  $private:mdFileDirectoryFullname = (split-path $mdFile)
  $private:mdFileBasename = (split-path $mdFile -LeafBase)

  $private:mdMetadata = Get-MdYamlHeader -file $mdFile

  if ($private:mdMetadata.uid)
  {
    Write-Verbose "Using Yaml Metadata uid: $($private:mdMetadata.uid)"
    return $private:mdMetadata.uid
  }
  else
  {
    Write-Verbose "Generating uid from md file path"
    $private:workingDirectory = (Get-Location)
  
    $relative = (join-path $private:mdFileDirectoryFullname -ChildPath $private:mdFileBasename).Substring($private:workingDirectory.Path.Length)
    
    $pageSegments = $relative.Replace(" ", "_").Split("$([IO.Path]::DirectorySeparatorChar)",[System.StringSplitOptions]::RemoveEmptyEntries)
    
    $pageUid = "$($pagesUidPrefix)$($pageSegments -join "_")"
    Write-Verbose "File: $(Resolve-Path -path $mdfile -Relative) UID: $pageUid"

  }


  return $pageUid

}

function script:UtilRoboCopy
{
  param($Title, $Source, $Destination)

  $private:robocopy = [ordered]@{
    Source = $Source
    Destination = $Destination
  }
  
  Write-Information "Copying [$($Title)]"
  Write-Information "  From: [$($private:robocopy.Source)]"
  Write-Information "    To: [$($private:robocopy.Destination)]"
  
  $private:robocopyResult = Robocopy.exe $private:robocopy.Source $private:robocopy.Destination /MIR /NS /NC /NFL /NDL /NP

  if ($LastExitCode -gt 7) {
    Write-Error ($private:robocopyResult | out-string)
    # an error occurred
    exit $LastExitCode
  }

  $LastExitCode = 0
}

function script:getDocFxHelperResourceViewModel
{
  param(
      [Parameter(Mandatory)][ResourceType]$ResourceType
    , [Parameter(Mandatory)][Uri]$CloneUrl
    , $RepoBranch
    , $RepoRelativePath
    , $PipelineId
    , $ArtifactName
    , $SubFolder
    , $Name
    , $Id
    , $Target
    , $MenuParentItemName
    , $MenuDisplayName
    , $MenuPosition
    , $Excludes
    , $Homepage
    , $HomepageUid
    , $ParentId
    , $Medias
    , $Templates
    )

  $private:repoName = ($CloneUrl).Segments[-1]
  
  $private:vm = [ordered]@{
    resourceType            = $ResourceType                # wiki, api, conceptual or powerShellModule
    resourceIdPrefix        = "$($ResourceType)"           # wiki, api, conceptual or powerShellModule
    sourceType              = [sourceType]::Unknown        # pipeline.resources.repository or pipeline.resources.pipeline (artifactName provided)
    cloneUrl                = $CloneUrl
    gitPath                 = $null                        # full path to the git repo
    gitStatus               = $null                        # 
    repoBranch              = $RepoBranch                  # 
    repoRelativePath        = $RepoRelativePath
    pipelineId              = $PipelineId
    artifactName            = $ArtifactName                # if provided
    resourceRootPath        = $null
    name                    = $Name                        # if not provided, defaults to repoName (depends on repoName)
    id                      = $Id                          # id/name of the item, used to identify parents by id, if not found defaults to name  (depends on name)
    target                  = $Target
    menuParentItemName      = $MenuParentItemName
    menuDisplayName         = $MenuDisplayName
    menuPosition            = $MenuPosition
    excludes                = $Excludes
    medias                  = @()
    docsSubfolder           = $SubFolder                   # (depends on object's type)
    docsSubfolderPath       = $null                        # (depends if artifactName)
    homepage                = $Homepage         
    homepageUid             = $HomepageUid
    parentId                = $ParentId
    parentToc_yml           = $null                        # (depends on parent.docsSubfolderPath + target - parent's target)
    parentTocItemHrefFolder = $null                        # (depends on target)
    templates               = @()
    metadata                = $null                        # not implemented yet
  }

  if ("$($private:vm.name)" -eq "")
  {
    Write-Debug "name: not provided, defaulting to repoName $($private:repoName)"
    $private:vm.name = $private:repoName
  }

  if ("$($private:vm.pipelineId)" -eq "")
  {
    $private:vm.pipelineId = $private:vm.name.replace("-", "_").replace(".", "_")
    Write-Debug "pipelineId: not provided, defaulting to name with - and . replaced with _ [$( $private:vm.pipelineId)]"
  }

  if ("$($private:vm.id)" -eq "")
  {
    $private:vm.id = "$($private:vm.resourceIdPrefix)_$($private:vm.pipelineId)"
    Write-Debug "id: not provided, defaulting to prefix and name $($private:vm.id)"
  }

  foreach($private:knownArtifactName in $private:knownArtifactNames)
  {
    if (!$vm.artifactName -and ((Test-Path (Join-Path -Path (get-location) -ChildPath $private:vm.pipelineId -AdditionalChildPath $private:knownArtifactName))))
    {
      Write-Debug "artifactName not provided, but found a subFolder named $($private:knownArtifactName).  Using that as artifactName, and treating this as a pipeline resource"
      $private:vm.artifactName = "$($private:knownArtifactName)"
    }
  }

  if ($private:vm.artifactName)
  {
    Write-Debug "artifactName provided, so will be treated as a PipelineArtifact.  Artifacts from the associated pipeline resource are downloaded to `$(Pipeline.Workspace)/<pipeline resource identifier>/<artifact name>"
    $private:vm.sourceType = [SourceType]::PipelineArtifact
    if ("$($private:vm.repoBranch)" -eq "")
    {
      $private:vm.repoBranch = "main"
    }    
    if ("$($private:vm.repoRelativePath)" -eq "")
    {
      $private:vm.repoRelativePath = "/"
    }    
    $private:vm.resourceRootPath  = Join-Path -Path (get-location) -ChildPath $private:pipelineId -AdditionalChildPath    $private:vm.artifactName
    $private:vm.docsSubfolderPath = Join-Path -Path (get-location) -ChildPath $private:pipelineId -AdditionalChildPath (@($private:vm.artifactName) + "$($private:vm.docsSubfolder)".replace("/","\").split("\"))
  }
  else
{
    Write-Debug "not artifactName provided, treating item as a resources.repositories.repository"
    $private:vm.sourceType = [SourceType]::Repository
    $private:vm.gitPath = Join-Path -Path (get-location) -ChildPath "s" -AdditionalChildPath $private:repoName

    Push-Location $private:vm.gitPath
    $private:gitStatus = Get-GitStatus | ConvertTo-json -Depth 3 | ConvertFrom-Json
    pop-location

    $private:vm.gitStatus = @{
      GitDir       = "$($private:gitStatus.GitDir)"
      BehindBy     = $private:gitStatus.BehindBy
      StashCount   = $private:gitStatus.StashCount
      HasUntracked = $private:gitStatus.HasUntracked
      HasIndex     = $private:gitStatus.HasIndex
      HasWorking   = $private:gitStatus.HasWorking
      UpstreamGone = $private:gitStatus.UpstreamGone
      Branch       = "$($private:gitStatus.Branch)"
      Upstream     = "$($private:gitStatus.Upstream)"
      RepoName     = "$($private:gitStatus.RepoName)"
      AheadBy      = $private:gitStatus.AheadBy

    }


    $private:vm.resourceRootPath  = Join-Path -Path (get-location) -ChildPath "s" -AdditionalChildPath    $private:repoName
    $private:vm.docsSubfolderPath = Join-Path -Path  $private:vm.resourceRootPath -ChildPath "" -AdditionalChildPath ("$($private:vm.docsSubfolder)".replace("/","\").split("\"))    
  }

  $private:vm.pagesUidPrefix = Get-ResourcePageUidPrefix -relativePath $private:vm.target

  if ($private:vm.homepage -and "$($private:vm.homepageUid)".Trim() -eq "")
  {
    $private:homepagePath = Join-Path -Path $private:vm.docsSubfolderPath -ChildPath $private:vm.homepage
    Write-Debug "homepage provided, but not the homepageUid, reading the yaml header from the homepage [$($private:homepagePath)]"

    $private:homepageMeta = Get-MdYamlHeader -file $private:homepagePath

    $private:vm.homepageUid = $private:homepageMeta.uid
    Write-Debug "HomepageUid: [$($private:vm.homepageUid)]"    
  }

    
  if ($Medias)
  {
    Write-Debug "adding [$($Medias.count)] media to item"

    foreach($private:media in $Medias)
    {
      if (!($private:vm.media | where-object {$_ -eq $private:media}))
      {
        Write-Debug " media: adding [$($private:media)] from DocFxHelper"
        $private:vm.medias += $private:media
      }
    }
  }
  
  return $private:vm
}

function script:setDocFxHelperResourceHierarchy
{
  param($DocFxHelperViewModel, $ResourceViewModel)

  if ($null -eq $DocFxHelperViewModel.root)
  {
    $DocFxHelperViewModel.root = $ResourceViewModel
  }

  Write-Verbose "Set a parentId to items that have none defined"
  if ("$($ResourceViewModel.parentId)" -eq "")
{
    $ResourceViewModel.parentId = $DocFxHelperViewModel.root.id
  }

  if ($ResourceViewModel.id -ne $DocFxHelperViewModel.root.id)
  {
    Write-Information "Identify resource's parent toc.yml"
    <#
      $DocFxHelperViewModel.all | select-object id, pipelineId, parentid
    #>
    $private:parent = $DocFxHelperViewModel.all | where-object {$_.id -eq $ResourceViewModel.parentId}

    if ($private:parent)
    {
      $private:itemTargetSegments = "$($ResourceViewModel.target)".replace("\","/") -split "/" | where-object {$_}
      $private:parentTargetSegments = "$($private:parent.target)".replace("\", "/") -split "/" | where-object {$_}
      $private:adjustedSegments = $private:itemTargetSegments | select-object -skip $private:parentTargetSegments.count
      $ResourceViewModel.parentToc_yml = Join-Path -Path $private:parent.docsSubfolderPath -ChildPath (($private:adjustedSegments | select-object -SkipLast 1) -join "\") -AdditionalChildPath "toc.yml"
      $ResourceViewModel.parentTocItemHrefFolder = $private:adjustedSegments | select-object -last 1    
      Write-Verbose "  For resource: [$($ResourceViewModel.id)]"
      Write-Verbose "Parent toc.yml: [$($ResourceViewModel.parentToc_yml)]"
      Write-Verbose "   href folder: [$($ResourceViewModel.parentTocItemHrefFolder)]"
    }
    else
    {
      Write-Verbose "Parent not found for [$($ResourceViewModel.id)] and parentId [$($ResourceViewModel.parentId)]"
}
  }
  else
  {
    Write-Verbose "Resource [$($ResourceViewModel.id)] is the root and doesn't need a parent toc.yml"
  }
}

function script:saveDocFxHelperViewModel
{
  param($ViewModel)

  $private:destination = "DocFxHelper"

  if (Test-Path $private:destination)
  {
    Write-Verbose "$($private:destination) exists"
  }
  else
{
    Write-Verbose "$($private:destination) does not exist, creating"
    New-Item $private:destination -ItemType Directory | Out-Null
  }
  
  $private:docFxHelperViewModel_json = Join-Path $private:destination -ChildPath "docfxHelper.ViewModel.json"

  $ViewModel | ConvertTo-Json -Depth 3 | Set-Content $private:docFxHelperViewModel_json

}

function script:getDocFxHelperViewModel
{
  $private:destination = "DocFxHelper"

  if (Test-Path $private:destination)
  {
    Write-Verbose "$($private:destination) exists"
  }
  else
  {
    Write-Verbose "$($private:destination) does not exist, creating"
    New-Item $private:destination -ItemType Directory | Out-Null
  }

  $private:docFxHelperViewModel_json = Join-Path $private:destination -ChildPath "docfxHelper.ViewModel.json"

  if (Test-Path $private:docFxHelperViewModel_json)
  {
    Write-Verbose "Loading $($private:docFxHelperViewModel_json)"
    $private:ret = Get-Content $private:docFxHelperViewModel_json | ConvertFrom-Json -AsHashtable
  }
  else
  {
    Write-Verbose "Creating a new blank $($private:docFxHelperViewModel_json)"
    $private:ret = [ordered]@{}
    $private:ret | ConvertTo-Json | Set-Content $private:docFxHelperViewModel_json
  }
  return $private:ret
}

function script:Get-WikiMarkdowns
{
  param($Folder)

  return Get-ChildItem -path $Folder -File -Filter "*.md"

}

function script:Get-DocfxItemMetadata
{
  param($mdFile)

  $private:workingDirectory = (Get-Location)

  $private:item = [ordered]@{
    AdoWiki = [ordered]@{
      File            = $mdFile                 # A-%2D-b%2Dc(d)-(e)-%2D-(f)-%2D-(-h-).md [FileInfo]
      FileName        = $mdFile.Name            # A-%2D-b%2Dc(d)-(e)-%2D-(f)-%2D-(-h-).md
      FileAbsolute    = $mdFile.FullName        # c:\x\y\A-%2D-b%2Dc(d)-(e)-%2D-(f)-%2D-(-h-).md
      FileRelative    = $null                   # .\A-%2D-b%2Dc(d)-(e)-%2D-(f)-%2D-(-h-).md
      FileRelativeUri = $null                   # ./A-%2D-b%2Dc(d)-(e)-%2D-(f)-%2D-(-h-).md
      LinkOrderItem   = $null                   # A-%2D-b%2Dc(d)-(e)-%2D-(f)-%2D-(-h-)
      LinkRelative    = $null                   # ./A-%2D-b%2Dc(d)-(e)-%2D-(f)-%2D-(-h-)
      LinkAbsolute    = $null                   # /A-%2D-b%2Dc(d)-(e)-%2D-(f)-%2D-(-h-)
      LinkMarkdown    = $null                   # /A-%2D-b%2Dc\(d\)-\(e\)-%2D-\(f\)-%2D-\(-h-\)
      LinkDisplay     = $null                   # A - b-c(d) (e) - (f) - ( h )
      FolderName      = $null                   # A-%2D-b%2Dc(d)-(e)-%2D-(f)-%2D-(-h-)
      Folder          = $null
      WikiPath        = $null                   # /A - b-c(d) (e) - (f) - ( h )
    }
    DocFxSafe = [ordered]@{
      File            = $null
      FileName        = $null
      FileAbsolute    = $null
      FileRelative    = $null
      FileRelativeUri = $null
      LinkRelative    = $null
      LinkAbsolute    = $null
      LinkMarkdown    = $null
      LinkDisplay     = $null
      FolderName      = $null
      RenameRequired  = $false
      FileIsRenamed   = $false
    }
  }
  $private:item.AdoWiki.FileRelative    = ".$($private:item.AdoWiki.FileAbsolute.Substring($private:workingDirectory.Path.Length))"
  $private:item.AdoWiki.FileRelativeUri = ".$($private:item.AdoWiki.FileAbsolute.Substring($private:workingDirectory.Path.Length))".Replace("$([IO.Path]::DirectorySeparatorChar)", "/")
  $private:item.AdoWiki.LinkOrderItem   = $private:item.AdoWiki.FileName.Replace(".md", "")
  $private:item.AdoWiki.LinkRelative    = $private:item.AdoWiki.FileRelativeUri.Replace(".md", "")
  $private:item.AdoWiki.LinkAbsolute    = $private:item.AdoWiki.LinkRelative.Substring(1)
  $private:item.AdoWiki.LinkMarkdown    = $private:item.AdoWiki.LinkAbsolute.Replace("\(", "(").Replace("\)", ")")
  $private:item.AdoWiki.LinkDisplay     = [System.Web.HttpUtility]::UrlDecode($private:item.AdoWiki.LinkOrderItem.Replace("\(", "(").Replace("\)", ")").Replace("-", " "))
  $private:item.AdoWiki.Folder          = (Get-ChildItem -Path $mdFile.Directory -Directory | where-object {$_.Name -eq $private:item.AdoWiki.LinkOrderItem})
  if ($private:item.AdoWiki.Folder)
  {
    $private:item.AdoWiki.FolderName    = $private:item.AdoWiki.Folder.Name
  }
  $private:item.AdoWiki.WikiPath        = [System.Web.HttpUtility]::UrlDecode($private:item.AdoWiki.LinkAbsolute.Replace("-", " "))

  $private:item.DocFxSafe.File            = $private:item.AdoWiki.File 
  $private:item.DocFxSafe.FileName        = [System.Web.HttpUtility]::UrlDecode($private:item.AdoWiki.FileName)
  $private:item.DocFxSafe.FileAbsolute    = [System.Web.HttpUtility]::UrlDecode($private:item.AdoWiki.FileAbsolute)
  $private:item.DocFxSafe.FileRelative    = [System.Web.HttpUtility]::UrlDecode($private:item.AdoWiki.FileRelative)
  $private:item.DocFxSafe.FileRelativeUri = [System.Web.HttpUtility]::UrlDecode($private:item.AdoWiki.FileRelativeUri)
  $private:item.DocFxSafe.LinkRelative    = "$([System.Web.HttpUtility]::UrlDecode($private:item.AdoWiki.LinkRelative)).md"
  $private:item.DocFxSafe.LinkAbsolute    = "$([System.Web.HttpUtility]::UrlDecode($private:item.AdoWiki.LinkAbsolute)).md"
  $private:item.DocFxSafe.LinkMarkdown    = "$([System.Web.HttpUtility]::UrlDecode($private:item.AdoWiki.LinkMarkdown)).md"
  $private:item.DocFxSafe.LinkDisplay     = $private:item.AdoWiki.LinkDisplay
  $private:item.DocFxSafe.FolderName      = [System.Web.HttpUtility]::UrlDecode($private:item.AdoWiki.FolderName)
  
  $private:item.DocFxSafe.RenameRequired = $private:item.DocFxSafe.FileName -ne $private:item.AdoWiki.FileName

  return [PSCustomObject]$private:item
  }

  

function script:Get-AdoWikiMetadata
{
  param($Path)

  push-location $Path

  $private:metadataList = [System.Collections.ArrayList]::new()

  $private:folders = Get-AdoWikiFolders -Path . -Exclude @(".git", ".attachments")

  foreach($private:folder in $private:folders)
  {
    <#
      $private:folder = $private:folders | select-object -first 1
    #>
    $private:mdFiles = Get-WikiMarkdowns -Folder $private:folder   

    foreach($private:mdFile in $private:mdFiles)
  {
      $private:metadata = Get-DocfxItemMetadata -mdFile $private:mdFile
  
      $private:metadataList.Add($private:metadata) | Out-Null
  }
  }
  
  Pop-Location # docs

  return $private:metadataList
}

function script:Get-AdoWikiFolders
  {
  param($Path, [string[]]$Exclude)

  $private:workingDirectory = (Get-Location).Path
  $private:folders = [System.Collections.ArrayList]::new()
  
  $private:folders.Add((Get-Item $Path).FullName) | Out-null

  $private:subFolders = Get-ChildItem -path $Path -Recurse -Directory

  foreach($private:subFolder in $private:subFolders)
  {
    <#
      $private:subFolder = $private:subFolders | select-object -first 1
    #>
    $private:relative = $private:subFolder.FullName.Substring($private:workingDirectory.Length)
    
    $private:segments = $private:relative.Split("$([IO.Path]::DirectorySeparatorChar)", [System.StringSplitOptions]::RemoveEmptyEntries)

    if (!$private:segments.Where({$_ -in $Exclude}))
  {
      $private:folders.Add($private:subFolder.FullName) | out-null
    }
  }

  return $private:folders
  }

function script:Convert-FromWikiOrder
{
  param([System.IO.FileInfo]$Order)

  $private:workingDirectory = (Get-Location)
  
  $o = [ordered]@{
    orderFile           = $Order
    content             = @() + (Get-Content -path $Order)
    folderAbsolute      = $Order.Directory.FullName
    folderName          = $Order.Directory.Name
    folderRelative      = $null
    folderUri           = $null
    depth               = $null
    orderItems          = [System.Collections.ArrayList]::new()
}
  $o.folderRelative = $o.folderAbsolute.Substring($private:workingDirectory.Path.Length)
  $o.folderUri = [Uri]::new($baseUri, $o.folderRelative.replace("$([IO.Path]::DirectorySeparatorChar)", "/"))
  $o.depth = $o.folderRelative.Split("$([IO.Path]::DirectorySeparatorChar)").Count - 1

  foreach($orderItem in $o.content)
  {
    <#
      $orderItems

      $orderItem = $o.content | select-object -first 1
      $orderItem = $o.content | select-object -first 1 -skip 1
      $orderItem = $o.content | select-object -last 1

      $orderItem = "Foo"
      $orderItem = "Foo-Bar"
      $orderItem = "Foo-Bar-(Snafu)"
  #>

    if ("$orderItem" -ne "")
    {

      Write-Debug "OrderItem: $orderItem"

      $oi = [ordered]@{
        orderItem              = $orderItem
        orderItemMd            = "$($orderItem).md"
        orderItemMdUri         = $null
        orderItemFolderPath    = Join-Path -path $order.Directory.FullName -ChildPath $orderItem
        display                = [System.Web.HttpUtility]::UrlDecode($orderItem.Replace("-", " "))
      }
      $oi.orderItemMdUri = [Uri]::new($o.folderUri, $oi.orderItemMd)

      $o.orderItems.Add([PSCustomObject]$oi) | Out-Null
    }
  }

  return [PSCustomObject]$o

}

function script:ConvertTo-DocFxToc
{
  param($OrderItems, $depth)

  $tocItems = [System.Collections.ArrayList]::new()

  foreach ($orderItem in $OrderItems)
  {
  <#
      $orderItem = $OrderItems | select-object -first 1
  #>
    
    $tocItem = [ordered]@{
      name = $orderItem.display
      href = $null
  }

    if (Test-Path $orderItem.orderItemFolderPath)
    {

      if ($depth -eq 0)
  {
        <#
          name: some thing
          href: some-thing/
        #>
        $tocItem.href = "$($orderItem.orderItem)/"
  }
      else
  {
        <#
          name: some thing
          href: some-thing/toc.yml
        #>
        $tocItem.href = "$($orderItem.orderItem)/toc.yml"
  }

      $tocItem.homepage = "$($orderItem.orderItemMd)"

    }
    else
  {
      <#
        name: some thing
        href: some-thing.md
      #>
      $tocItem.href = $orderItem.orderItemMd

    }      

    $tocItems.Add([PSCustomObject]$tocItem) | out-null

  }

  return @{
    items = $tocItems
  }

}

function script:Get-MdSections
{
  param($Content)

  $codeRegex = "^(?<code>``{3}\s*\w*\s*)$"

  $sections = [System.Collections.ArrayList]::new()

  $codeSections = $Content | select-string $codeRegex
  $lineStart = 0
  $codeBlock = 0

  Write-Verbose "Code section count: $($codeSections.count)"

  if ($codeSections.count -gt 0)
  {
    for($i=0;$i -lt $codeSections.count/2;$i++)
    {
      $codeBlock = $i*2
      if ($codeSections[$codeBlock].LineNumber-1 -gt $lineStart)
      {
        $sections.Add([PSCustomObject]@{type="Conceptual";content=$content[$lineStart..($codeSections[$codeBlock].LineNumber -2)]}) | out-null
      }
      $sections.Add([PSCustomObject]@{type="Code";content=$content[($codeSections[$codeBlock].LineNumber-1)..($codeSections[$codeBlock+1].LineNumber-1)]}) | out-null
      $lineStart=$codeSections[$codeBlock+1].LineNumber
    }
    if ($lineStart -lt $content.count)
    {
      $sections.Add([PSCustomObject]@{type="Conceptual";content=$content[$lineStart..($content.count-1)]}) | out-null
    }
  }
  else 
  {
    $sections.Add([PSCustomObject]@{type="Conceptual";content=$content}) | out-null
  }

  return $sections

}

function script:Update-Links
{
  param($Content, $ReplaceCode)

  $private:findRegex = "\[(?'display'(?:[^\[\]]|(?<Open>\[)|(?<Content-Open>\]))+(?(Open)(?!)))\]\((?'link'(?:[^\(\)]|(?<Open>\()|(?<Content-Open>\)))+(?(Open)(?!)))\)"

  if ("$content" -ne "" -and $content -match $findRegex)
  {
    $private:sections = Get-MdSections -Content $content
    
    $private:conceptualSectionNumber = 0
  
    foreach($private:conceptual in $sections | where-object type -eq "Conceptual")
    {
      <#
        $conceptual = $sections | where-object type -eq "Conceptual" | select-object -first 1
      #>
      $conceptualSectionNumber++
      if ($conceptual.content -match $f)
      {        
        if ($VerbosePreference -eq 'Continue')       
        {
        Write-Verbose "Conceptual section $conceptualSectionNumber"
        Write-Verbose "Before:"
        $conceptual.content | select-string $findRegex -AllMatches | Out-Host
        }
        $conceptual.content = $conceptual.content -replace $findRegex, $replaceCode
        if ($VerbosePreference -eq 'Continue')
        {
        Write-Verbose "After:"
        $conceptual.content | select-string $findRegex -AllMatches | Out-Host
      }
    }
    }
    $Content = $sections | select-object -ExpandProperty content
  }

  return $Content

}

function script:Update-FixAdoWikiEscapes
{
  param($Content)

  $private:r = {
    $private:in = @{
      display = $_.Groups["display"].Value
      link = $_.Groups["link"].Value  
    }
    <#
    $in = @{}
      $in.display = "This is the display"
      $in.link = "https://user:password@www.contoso.com:80/Home/Index.htm?q1=v1&q2=v2#FragmentName"
      $in.link = "xfer:Home_Index#FragmentName"
      $in.link = "/Home \(escaped folder\)/Index.md?q1=v1&q2=v2#FragmentName"
      $in.link = "/Home/Index\(escaped folder\).md?q1=v1&q2=v2#FragmentName"
    #>
    $private:out = @{
      display = $in.display
      link = $in.link
    }
    if ($private:out.link.StartsWith("/"))
    {
      $private:out.link = $private:out.link.replace("\(", "(").replace("\)", ")")
    }

    $private:ret = "[$($private:out.display)]($($private:out.link))"
    return $ret

  }
    
  $private:UpdatedContent = Update-Links -Content $Content -ReplaceCode $r

  return $UpdatedContent
}

function script:Update-ToMdLinks
{
  param($Content, $AllMdFiles, $MdFileMetadata)

  $private:r = {
    $private:in = @{
      display = $_.Groups["display"].Value
      link = $_.Groups["link"].Value  
    }
    Write-Debug "  $($in.link)"
    <#
    $in = @{}
      $in.display = "This is the display"
      $in.link = "https://user:password@www.contoso.com:80/Home/Index.htm?q1=v1&q2=v2#FragmentName"
      $in.link = "xfer:Home_Index#FragmentName"
      $in.link = "mail:foo@bar.com"
      $in.link = "tel:foo@bar.com"
      $in.link = "/.attachments"
      $in.link = ".attachments"
      $in.link = "#Anchor"
      
      # to verify
      $in.link = "/Home/Index.md?q1=v1&q2=v2#FragmentName"
      $in.link = "Home/Index?q1=v1&q2=v2#FragmentName"
      $in.link = "/With%20Space/With%20Space%20Too.md?q1=v1&q2=v2#FragmentName"
      $in.link = "/With Space/With Space Too.md?q1=v1&q2=v2#FragmentName"
      $in.display = Read-Host "Display"
      $in.link = Read-Host "Link"
    #>
    $private:out = @{
      display = $in.display
      link = $in.link
    }

    $private:testUri = [Uri]::new($baseUri,$private:out.link)

    if ($private:testUri.Host -ne $baseUri.Host)
    {
      Write-Debug "    ignored $($private:out.link) is external"
    }
    else
    {
      if ($private:testUri.Segments -contains ".attachments/")
      {
        Write-Debug "    ignored - links to an image"
      }
      else
      {
        if ($private:testUri.LocalPath.EndsWith(".md"))
        {
          Write-Debug "    already points to a .md file"
        }
        elseif ($AllMdFiles -contains $private:testUri.AbsolutePath)
        {
          Write-Debug "    link to a known .md file"
          $private:out.link = "$($private:testUri.AbsolutePath).md$($private:testUri.Query)$($private:testUri.Fragment)"
        }
        else
        {          
          $private:PageUri = [Uri]::new($baseUri, $MdFileMetadata.AdoWiki.FileRelativeUri)
          $private:pageRelativeLink = [Uri]::new($private:pageUri, $out.link)
          
          if ($AllMdFiles -contains $private:pageRelativeLink.AbsolutePath)
    {
            Write-Debug "    link is relative to an existing .md"
            $private:out.link = "$($private:pageRelativeLink.AbsolutePath).md$($private:pageRelativeLink.Query)$($private:pageRelativeLink.Fragment)"
          }
        }
      }
      
    }

    $private:ret = "[$($private:out.display)]($($private:out.link))"
    return $private:ret

  }
    
  $private:UpdatedContent = Update-Links -Content $content -ReplaceCode $r

  return $UpdatedContent
 
}

function script:Update-RenamedLinks
{
  param($Content, $Map)

  $private:r = {
    $private:in = @{
      display = $_.Groups["display"].Value
      link = $_.Groups["link"].Value
    }
    <#
    $in = @{}
      $in.display = "This is the display"
      $in.link = "/With Space/With Space.md?q1=v1&q2=v2#FragmentName"
      $in.link = "/With Space/With Space?q1=v1&q2=v2#FragmentName"
      $in.display = Read-Host "Display"
      $in.link = Read-Host "Link"
    #>
    $private:out = @{
      display = $in.display
      link = $in.link
    }

    $private:testUri = [Uri]::new($baseUri,$private:out.link)

    if ($private:testUri.Host -ne $baseUri.Host)
      {
      Write-Debug "ignored $($private:out.link) is external"
      }
      else
      {
      if ($private:testUri.Segments -contains ".attachments/")
      {
        Write-Debug "ignored - links to an image"
      }
      elseif ($private:testUri.LocalPath -eq "/" -and "$($private:testUri.Anchor)" -ne "")
      {
        Write-Debug "ignored - links to anchor"
      }
      else
      {
        $private:matchedMap = $Map | where-object {$_.from -eq ".$($private:testUri.LocalPath)" -or $_.from -eq ".$($private:testUri.LocalPath).md"}
        if ($private:matchedMap)
        {
          $private:newUri = [Uri]::new($baseUri, "$($private:matchedMap.to)")

          $private:out.link = "$($private:newUri.AbsolutePath)$($private:testUri.Query)$($private:testUri.Fragment)"
        }
      }
    }
    $private:ret = "[$($private:out.display)]($($private:out.link))"
    return $private:ret
  }
    
  $private:updatedContent = Update-Links -Content $content -ReplaceCode $r

  return $updatedContent
 
}

function script:Update-ToRelativeLinks
{
  param($Content, [Uri]$PageUri)

  $private:r = {
    $private:in = @{
      display = $_.Groups["display"].Value
      link = $_.Groups["link"].Value
    }
    <#
    $in = @{}
      $in.display = "This is the display"
      $in.link = "https://user:password@www.contoso.com:80/Home/Index.htm?q1=v1&q2=v2#FragmentName"
      $in.link = "xfer:Home_Index#FragmentName"
      $in.link = "/Home/Index.md?q1=v1&q2=v2#FragmentName"
      $in.link = "Home/Index?q1=v1&q2=v2#FragmentName"
      $in.link = "#Anchor"
      $in.link = "/With%20Space/With%20Space%20Too.md?q1=v1&q2=v2#FragmentName"
      $in.link = "/With Space/With Space Too.md?q1=v1&q2=v2#FragmentName"
      $in.display = Read-Host "Display"
      $in.link = Read-Host "Link"
    #>
    $private:out = @{
      display = $in.display
      link = $in.link
    }
    Write-Debug $in.link
    if ($private:out.link.StartsWith("/"))
    {
      $private:linkUri = [Uri]::new($baseUri, $private:out.link)

      $private:out.link = $PageUri.MakeRelativeUri($linkUri).ToString()
      }

    $private:ret = "[$($private:out.display)]($($private:out.link))"
    return $ret

  }
    
  $private:updatedContent = Update-Links -Content $content -ReplaceCode $r

  return $updatedContent
}

function script:Update-MermaidCodeDelimiter
{
  param($mdFile)

  $content = get-content -path $mdfile.FullName -raw
  if ("" -ne "$content" -and ("$content".Contains(":::mermaid") -or "$content".Contains("::: mermaid")))
{
    Write-Verbose "Found Mermaid Code in $($mdfile.FullName). Fixing..."
    $content = $content.replace(":::mermaid", "<pre class=""mermaid"">")
    $content = $content.replace("::: mermaid", "<pre class=""mermaid"">")
    $content = $content.replace(":::", "</pre>")
    set-content -path $mdfile.FullName -value $content
}
      }
  
function script:Update-AdoWikiToDocFx
  {
  param($AdoWikiViewModel)

  $Path = $AdoWikiViewModel.docsSubfolderPath
  $IsChildWiki = $AdoWikiViewModel.isChildWiki

  Write-Host "Updating AdoWiki [$Path] to make it DocFx friendly"

  if ($IsChildWiki)
      {
    $private:Depth = 1
    }
    else
    {
    $private:Depth = 0
  }

  push-location $Path
  
  $private:renameMap = [System.Collections.ArrayList]::new()
  $private:allMetadata = Get-AdoWikiMetadata -Path .
  $private:workingDirectory = (Get-Location)

  # ------------------------------------------------------------------------
  Write-Verbose "   - Convert .order to toc.yml"

  $private:folders = Get-AdoWikiFolders -Path . -Exclude @(".git", ".attachments")
    
  foreach($private:folder in $private:folders)
  {
    <#
      $private:folder = $private:folders | select-object -first 1
      $private:folder = $private:folders | select-object -first 1 -skip 1
    #>

    $private:dot_order = Join-Path $private:folder -ChildPath ".order"

    if (Test-Path $private:dot_order)
    {
      $private:dot_order = Get-Item (Join-Path $private:folder -ChildPath ".order")
  
      # $Order = $order
      # $MetadataItems = $metadataItemsInFolder
      $private:adoWikiOrder = Convert-FromWikiOrder -Order $private:dot_order
      $private:totalDepth = $Depth + $folder.substring($private:workingDirectory.Path.Length).split("$([IO.Path]::DirectorySeparatorChar)").count - 1
  
      if (($private:adoWikiOrder.orderItems | select-object -first 1).orderItem -eq "Index")
      {
        $private:orderItemsExceptIndex = $private:adoWikiOrder.orderItems | select-object -skip 1
      }
      else
      {
        $private:orderItemsExceptIndex = $private:adoWikiOrder.orderItems 
      }
  
      <#
        $OrderItems = $orderItemsExceptIndex 
        $depth = $depth
      #>
  
      $private:toc = ConvertTo-DocFxToc -OrderItems $private:orderItemsExceptIndex -depth $private:totalDepth
    }
    else
    {
      $private:toc = @{items = @()}
    }
  
    ConvertTo-Yaml $private:toc -OutFile (Join-Path $private:folder -ChildPath "toc.yml") -Force
  }





  # ------------------------------------------------------------------------
  Write-Host "   - Set Yaml Headers"
  Write-Verbose "     - adoWikiPath"
  Write-Verbose "     - adoWikiOriginalMd"
  foreach($private:metadata in $private:allMetadata)
  {
    $private:mdFile = $private:metadata.DocFxSafe.File
    $private:adoWikiOriginalMd = $private:mdFile.FullName.Substring($private:workingDirectory.Path.Length)

    Set-MdYamlHeader -file $private:mdFile -key "adoWikiPath" -value $private:metadata.AdoWiki.WikiPath
    Set-MdYamlHeader -file $private:mdFile -key "adoWikiOriginalMd" -value $private:adoWikiOriginalMd
  }



  # ------------------------------------------------------------------------
  Write-Host "   - Rename [md Files] to DocFx safe name format"
  foreach($private:metadata in $private:allMetadata)
  {
    <#
      $metadata = $allMetadata | select-object -first 1
      
    #>
    $private:mdFile = $private:metadata.AdoWiki.File

    if ($private:metadata.DocFxSafe.RenameRequired)
    {
      $private:renameMap.Add([PSCustomObject]@{
        from = $private:metadata.AdoWiki.FileRelativeUri
        to  = $private:metadata.DocFxSafe.FileRelativeUri
      }) | Out-Null

      Write-Verbose "   - File $($private:metadata.AdoWiki.Filename) is not DocFx safe, rename required"
      $private:filePathToRename = $private:metadata.AdoWiki.FileAbsolute
      $private:newName = $private:metadata.DocFxSafe.FileName

      $private:metadata.DocFxSafe.File = Rename-Item -Path $private:filePathToRename -NewName $private:newName -Force -PassThru
      $private:metadata.DocFxSafe.FileIsRenamed     = $true

      Set-MdYamlHeader -file $private:metadata.DocFxSafe.File -key "DocFxSafeFileName" -value $private:newName

      $private:toc_yaml = (join-path $private:mdFile.Directory.FullName -childPath "toc.yml")
      $private:toc = get-content $private:toc_yaml | ConvertFrom-yaml -Ordered

      $private:tocItem = $private:toc.items | where-object {$_.href -eq $private:mdFile.Name -or $_.homepage -eq $private:mdFile.Name}

      if ($private:tocItem)
      {
        if ($private:tocItem.href -eq $private:mdFile.Name)
        {
          $private:tocItem.href = $private:newName
        }
        else
        {
          $private:tocItem.homepage = $private:newName
        }
      }
      else
      {
        Write-Warning "$($private:mdFile.FullName) not found in $private:toc_yaml"
      }

      ConvertTo-Yaml -Data $private:toc -OutFile $private:toc_yaml -Force
    }     
  }




  # ------------------------------------------------------------------------
  Write-Host "   - Rename [Folders] to DocFx safe name format"

  $private:foldersMetadata = [System.Collections.ArrayList]::new()
  foreach($private:metadata in $private:allMetadata)
  {

    $private:folder = $private:metadata.AdoWiki.File.Directory

    if (!($private:foldersMetadata | where-object {$_.Folder.Fullname -eq $private:folder.FullName}))
    {
      $private:foldersMetadata.Add([PSCustomObject]@{
        Folder = $private:folder
        FolderRelative = $private:folder.FullName.Substring($private:workingDirectory.Path.Length)
        Depth = $private:folder.FullName.Split("$([IO.Path]::DirectorySeparatorChar)").Count
      }) | out-null
    }
  }

  foreach($private:folderMetadata in $private:foldersMetadata | sort-object Depth -Descending)
  {
    <#
      $private:folderMetadata = $private:foldersMetadata | sort-object Depth -Descending | select-object -first 1
      $private:folderMetadata = $private:foldersMetadata | select-object -first 1 -skip 1

    #>    
    $private:folderUri = [Uri]::new($baseUri, $private:folderMetadata.FolderRelative.Replace("$([IO.Path]::DirectorySeparatorChar)", "/"))

    if ($private:folderUri.AbsoluteUri -ne $private:folderUri.OriginalString)
    {
      Write-Verbose "   - Folder $($private:folderMetadata.FolderRelative) is not DocFx safe, rename required"

      $private:filePathToRename = $private:folderMetadata.Folder.FullName
      $private:oldName = $private:folderMetadata.Folder.Name
      $private:newName = $private:folderUri.Segments[-1]
      Write-Verbose "      From: $($private:oldName)"
      Write-Verbose "        To: $($private:newName)"
      Rename-Item -Path $private:filePathToRename -NewName $private:newName -Force

      $private:renameMap.Add([PSCustomObject]@{
        from = "$($private:oldName)/"
        to  = "$($private:newName)/"
      }) | Out-Null

      $private:toc_yaml = join-path $private:folderMetadata.Folder.Parent.FullName -ChildPath "toc.yml"
      $private:toc = get-content $private:toc_yaml | ConvertFrom-Yaml -Ordered

      foreach($private:tocItem in $private:toc.items)
      {
        <#
          $private:tocItem = $private:toc.items | select-object -first 1
          $private:tocItem = $private:toc.items | select-object -first 1 -skip 1
          $private:tocItem = $private:toc.items | select-object -first 1 -skip 2
        #>
        if ($private:tocItem.href.StartsWith("$($private:oldName)/"))
        {
          $private:segments = $private:tocItem.href.split("/")
          $private:segments[0] = $private:newName
          $private:tocItem.href = $private:segments -join "/"
        }

        if ("$($private:tocItem.homepage)".StartsWith("$($private:oldName)/"))
        {
          $private:segments = $private:tocItem.homepage.split("/")
          $private:segments[0] = $private:newName
          $private:tocItem.homepage = $private:segments -join "/"
        }

      }

      ConvertTo-Yaml -Data $private:toc -OutFile $private:toc_yaml -Force

    }
  }




  # ------------------------------------------------------------------------
  Write-Host "   - Update Hyperlinks"
  Write-Verbose "     - Convert absolute links to relative"
  Write-Verbose "     - Update wiki links to .md extension"
  Write-Verbose "     - Update wiki links to match the renamed mdFiles or folder"

  $private:allMetadata = Get-AdoWikiMetadata -Path .

  foreach($private:metadata in $private:allMetadata)
  {    
    $private:mdFile = $private:metadata.DocFxSafe.File

    Write-Verbose $private:mdFile.fullname

    $private:content = Get-Content -Path $private:mdFile
    
    $private:content = Update-FixAdoWikiEscapes -content $private:content
    
    # /foo/bar -> /foo/bar.md
    $private:content = Update-ToMdLinks -content $private:content -AllMdFiles $private:allMetadata.AdoWiki.LinkAbsolute -MdFileMetadata $private:metadata
    
    # /foo bar/foo bar.md -> /foo_bar/foo_bar.md
    $private:content = Update-RenamedLinks -Content $private:content -Map $private:renameMap
    
    # /foo/bar.md -> [[../]foo/]bar.md depends on the current page's uri
    $private:pageUri = [Uri]::new($baseUri, $private:mdFile.FullName.Substring($private:workingDirectory.Path.Length))
    $private:content = Update-ToRelativeLinks -content $private:content -PageUri $private:pageUri
       

    $private:content | Set-Content -Path $private:mdFile
  }





  # ------------------------------------------------------------------------
  Write-Host "   - Update Mermaid Code Delimiters"

  foreach($private:metadata in $private:allMetadata)
  {
    $private:mdFile = $private:metadata.DocFxSafe.File

    Update-MermaidCodeDelimiter -mdfile $private:mdFile
  }

  # ------------------------------------------------------------------------
  Write-Host "   - Set each page's UID"

  foreach($private:metadata in $private:allMetadata)
  {
    $private:mdFile = $private:metadata.DocFxSafe.File

    $private:pageUID = Get-PageUid -pagesUidPrefix $AdoWikiViewModel.pagesUidPrefix -mdfile $private:mdFile
    Set-MdYamlHeader -file $private:mdFile -key "uid" -value $private:pageUID    
}

  pop-location # target
}

function script:Get-TocItem
{
  param($Items, $Name, [switch]$Recurse)

  Write-Verbose "Trying to find [$Name] in a toc of $($Items.count) items.  Recursive ? $($Recurse)"
  foreach($private:item in $Items)
{
    if ($private:item.name -eq $Name)
    {
      Write-Verbose "Found $Name"
      return $private:item
    }
  }

  if ($Recurse)
  {
    foreach($private:item in $Items)
    {
      $private:childFound = Get-TocItem -Items $private:item.Items -Name $Name -Recurse $Recurse
      if ($private:childFound)
      {
        return $private:childFound
      }
    }
  }

  return $null

}

function script:Merge-ResourceWithParent
  {
  param([Parameter(Mandatory)]$ResourceViewModel)

  Write-Information "Merge [Child] resources into [Parent]"
    <#
    $private:item -> $ResourceViewModel

    #>
    
  if ($ResourceViewModel.parentId -eq $ResourceViewModel.id)
  {
    Write-Verbose "$($ResourceViewModel.id) is the root item, it doesn't have to be merged with itself"
  }
  elseif ($ResourceViewModel.menuDisplayName)
  {
    Write-Information "   ... [$($ResourceViewModel.id)] merging into [$($ResourceViewModel.parentToc_yml)]"

    if (!(Test-Path $ResourceViewModel.parentToc_yml))
    {
      Write-Debug "$($ResourceViewModel.parentToc_yml) doesn't exist, creating a blank one, with an empty items list"
      New-Item $ResourceViewModel.parentToc_yml -Force -ItemType File
      [PSCustomObject][ordered]@{items = [System.Collections.ArrayList]::new()} | ConvertTo-Yaml -OutFile $ResourceViewModel.parentToc_yml -Force
    }

    Write-Debug "parent toc.yml: [$($ResourceViewModel.parentToc_yml)]"

    $private:parentToc = get-content $ResourceViewModel.parentToc_yml | ConvertFrom-Yaml -Ordered
    if ($null -eq $private:parentToc.items)
    {
      Write-Debug "parentToc doesn't have an items collection, creating a new one"
      $private:tempParentToc = @{items = [System.Collections.ArrayList]::new()}
      Write-Debug "and moving [$($private:parentToc.count)] items in it"
      foreach($private:oldItem in $private:parentToc)
    {
        $private:tempParentToc.items.Add($private:oldItem) | out-null

      }
      $private:parentToc = $private:tempParentToc
    }

    if ($ResourceViewModel.menuParentItemName)
    {
      Write-Debug "Looking for a parent item named [$($ResourceViewModel.menuParentItemName)] in toc items"
      $private:parentTocItem = Get-TocItem -Items $private:parentToc -Name $ResourceViewModel.menuParentItemName -Recurse

      if ($null -eq $private:parentTocItem)
      {
        Write-Debug "not found, appending a parent item named [$($ResourceViewModel.menuParentItemName)] at the toc's root items"
        $private:parentTocItem = [ordered]@{
          name = $ResourceViewModel.menuParentItemName
          items = [System.Collections.ArrayList]::new()
        }
        $private:parentToc.items.Add($private:parentTocItem) | out-null
    }
    else
    {
        Write-Debug "a parent item named [$($ResourceViewModel.menuParentItemName)] found in toc items"
      }
    }
    else
    {
      Write-Debug "item's menuParentItemName not provided, using the root toc items"
      $private:parentTocItem = $private:parentToc
    }



    Write-Debug "Loading for a [$($ResourceViewModel.menuDisplayName)] parent's toc"
    $private:childTocItem = Get-TocItem -Items $private:parentTocItem.items -Name $ResourceViewModel.menuDisplayName

    if ($null -eq $private:childTocItem)
      {
      Write-Debug "[$($ResourceViewModel.menuDisplayName)] not found, creating a new toc item"
      $private:childTocItem = [ordered]@{
        name = $ResourceViewModel.menuDisplayName
      }
  
      if ($null -eq $private:parentTocItem.items)
      {
        Write-Debug "but wait, the parentTocItem doesn't have an items property, adding it"
        $private:parentTocItem.items = [System.Collections.ArrayList]::new()
      }
      else
      {
        Write-Debug "the parentTocItem has an items property, good"
      }

      if ($ResourceViewModel.menuPosition -and $ResourceViewModel.menuPosition -ge 0)
      {
        if ($ResourceViewModel.menuPosition -lt $private:parentTocItem.items.count)
        {
          Write-Debug "Inserting the toc item at desired $($ResourceViewModel.menuPosition) position"
          $private:parentTocItem.items.Insert($ResourceViewModel.menuPosition, $private:childTocItem)
        }
        else
        {
          Write-Debug "Appending the toc item at the bottom since the menuPosition [$($ResourceViewModel.menuPosition)] is greater or equal than the number of items [$($private:parentTocItem.items.count)]"
          $private:parentTocItem.items.Add($private:childTocItem) | out-null
        }
      }
      else
      {
        Write-Debug "Appending the toc item at the bottom since the menuPosition was not provided"
        $private:parentTocItem.items.Add($private:childTocItem) | out-null
      }
    }
    else
    {
      Write-Debug "a toc item already exists in the parent's toc.yml, no need to create a new one."
    }
  
    Write-Debug "Figuring out what the href value should be."
    push-location (split-path $ResourceViewModel.parentToc_yml)
    if (("$($ResourceViewModel.target)".replace("\","/") -split "/").count -ge 2)
      {
      Write-Debug "Toc $($ResourceViewModel.parentToc_yml) is not at the root, so the href will be {folder}/toc.yml"
      $private:targetTocYmlPath = Join-Path $ResourceViewModel.docsSubfolderPath -ChildPath "toc.yml"
      if (!(Test-Path $private:targetTocYmlPath))
        {
          
        New-Item $private:targetTocYmlPath -Force
        ConvertTo-Yaml -Data (@{items = @()}) -OutFile $private:targetTocYmlPath -Force
    
      }
      $private:childTocItem.href = "$(Resolve-Path -Path $private:targetTocYmlPath -Relative)".Replace("\","/")
    }
    else
          {
      Write-Debug "Toc $($ResourceViewModel.parentToc_yml) is at the root, so the href is {folder}/"
      $private:childTocItem.href = "$(Resolve-Path $ResourceViewModel.docsSubfolderPath -Relative)/".Replace("\","/")
    }
    pop-location

    if ($ResourceViewModel.homepageUid)
    {
      Write-Debug "item's homepageUid specified [$($ResourceViewModel.homepageUid)], using it to set the toc item's topicUid"
      $private:childTocItem.topicUid = "$($ResourceViewModel.homepageUid)"
          }
          else
          {
      Write-Debug "item's homepageUid not specified, the folder's default html pages will be used: default or index"
          }

    Write-Debug "Toc Item: `r`n$($private:childTocItem | ConvertTo-Yaml)"
    
    $private:parentToc | ConvertTo-Yaml -OutFile $ResourceViewModel.parentToc_yml -Force
    
  }
  else
  {
    Write-Information "Item [$($ResourceViewModel.id)] doesn't have a menuDisplayName defined, so not added to any toc.yml"
      }
  
}

function script:Get-TocDepth
      {
  param($resourceTarget, $resourcePath, $tocPath)

  $private:resourceDepth = 0
  $private:resourceDepth += (("$resourceTarget".replace("\", "/").split("/") | where-object {$_}).count)
  $private:resourceDepth += ((get-item $tocPath).Directory.FullName.Split("\") | where-object {$_}).Count
  $private:resourceDepth -= ((get-item $resourcePath).FullName.Split("\") | where-object {$_}).Count

  return $private:resourceDepth
}

function script:FixTocItemsThatShouldPointToTheirFolderInstead
{
  param([Parameter(Mandatory)]$ResourceViewModel)

  Write-Information "Fixing toc items with an href pointing to an .md file when in fact it should point to their subfolder"
  
  $private:tableOfContents = get-childitem -path $ResourceViewModel.docsSubfolderPath -filter "toc.yml" -Recurse

  foreach($private:tableOfContent_yml in $private:tableOfContents)
  {
    <#
      $private:tableOfContent_yml = $private:tableOfContents | select-object -first 1

      scenarios:

      #4 href to an .md file in a subfolder: TODO: review
      - name: foo
        href: bar/snafu.md

      #5 href to an .md file, a subfolder with that name does not exist: nothing todo
      - name: foo
        href: bar.md

      #6 href to an .md file, a subfolder with that name exists
      - name: foo
        href: bar.md
      
      update required: href set to folder name, homepage set to md file
      - name: foo
        href: bar/
        homepage: bar.md

  
    #>

    $private:tocDepth = Get-TocDepth -resourceTarget $ResourceViewModel.target -resourcePath $ResourceViewModel.docsSubfolderPath -tocPath $private:tableOfContent_yml
  
    $private:tocItems = Get-Content $private:tableOfContent_yml | ConvertFrom-yaml -Ordered
  
    push-location (split-path $private:tableOfContent_yml)

    $private:tocItemsQueue = [System.Collections.Queue]::new()
                
    $private:tocItemsQueue.Enqueue($private:tocItems)

    while ($private:tocItemsQueue.count -gt 0)
    {
      $private:tocItem = $private:tocItemsQueue.Dequeue()

      foreach($private:childTocItem in $private:tocItem.items)
      {        
        $private:tocItemsQueue.Enqueue($private:childTocItem)
      }

      if ($private:tocItem.href)
      {
        if (Test-Path $private:tocItem.href)
        {
          $private:tocItemHrefItem = get-item $private:tocItem.href
          
          if ($private:tocItemHrefItem.PSIsContainer)
          {
            Write-Debug "href $($private:tocItem.href) points to a folder.  Nothing to do (Point #2 href to a folder: nothing to do)"
          }
          else
          {
            if ($private:tocItem.topicUid)
            {
              Write-Debug "href $($private:tocItem.href) points to a file, and tocItem has a topicUid [$($private:tocitem.topicUid)].  Nothing to do"
            }
            elseif ($private:tocItem.homepage)
            {
              Write-Debug "href $($private:tocItem.href) points to a file, and tocItem has a homepage [$($private:tocitem.homepage)].  Nothing to do"
            }
            elseif ($private:tocItemHrefItem.name -eq "toc.yml")
            {
              Write-Debug "href $($private:tocItem.href) points to a toc.yml.  Nothing to do (Point #3 href to a toc.yml in a subfolder: nothing to do)"
            }
            else
            {
              if ($private:tocItemHrefItem.Directory.Fullname -eq (Get-Location))
              {
                Write-Debug "href $($private:tocItem.href) points to a file in the current folder."
                if (Test-Path (join-path $private:tocItemHrefItem.Basename -childPath "toc.yml"))
                {
                  Write-Information "href $($private:tocItem.href) points to a file in the current folder, and a toc.yml found in a sub folder with the file's base name.  Update required"
                  Write-Debug "TocItem Before:`r`n$($private:tocItem | ConvertTo-yaml)"
                  $private:tocItem.homepage = $private:tocItem.href
                  $private:tocItem.href = "$(split-path $private:tocItem.href -LeafBase)/"
        
                  if ($private:tocDepth -gt 0)
                  {
                    Write-Information "and since the toc.yml's depth [$($private:tocDepth)] is greater than 0, the href should actually point to the child folder's toc.yml"
                    $private:tocItem.href = "$($private:tocItem.href)toc.yml"
                  }
                  Write-Debug "TocItem After:`r`n$($private:tocItem | ConvertTo-yaml)"
                }
                else
                {
                  Write-Debug "href $($private:tocItem.href) points to a file in the current folder, but a toc.yml wasn't found a sub folder with the file's base name.  Nothing to do"
                }
              }
            }
          }
        }
        else
        {
          Write-Warning "File $($private:tocItem.href), referenced from toc, not found."
        }
      }
      else
      {
        Write-Debug "no href.  Nothing to do (point #1)"
      }
    }

    $private:tocItems | ConvertTo-yaml -OutFile $private:tableOfContent_yml -Force

    pop-location

  }

}

function script:Set-ConceptualYamlHeader
{
  param($File, $RepoRelativePath)

  $private:fileRelativePath = (Resolve-Path $File -Relative).Substring(2).Replace("\", "/")

  Write-Verbose $private:fileRelativePath

  $private:yml = [ordered]@{
    remote = [ordered]@{
      path = "$((join-path $RepoRelativePath -ChildPath $private:fileRelativePath).Replace("\", "/"))"
      branch = "$Branch"
      repo = "$CloneUrl"
    }
    startLine = 0.0
    endLine = 0.0
    isExternal = $false
      }

  Set-MdYamlHeader -file $File -key "source" -value $private:yml
  Set-MdYamlHeader -file $File -key "documentation" -value $private:yml

}

function script:Set-ConceptualMarkDownFiles
{
  param($ViewModel)

  Write-Host "   Conceptual path: [$($ViewModel.docsSubfolderPath)]"
  Write-Host "          CloneUrl: [$($ViewModel.cloneUrl)]"
  Write-Host "            Branch: [$($ViewModel.repoBranch)]"
  Write-Host "Repo relative path: [$($ViewModel.repoRelativePath)]"
  Write-Host "Site relative path: [$($ViewModel.target)]"
    
  Push-Location $ViewModel.docsSubfolderPath
  
  $private:mdFiles = get-childitem -Path . -Filter "*.md" -Recurse
  
  Write-Host "$($private:mdFiles.count) markdown files found"
  
  foreach($private:mdFile in $private:mdFiles)
  {
    <#
      $private:mdFile = $private:mdFiles | select-object -first 1
      $private:mdFile 
    #>
    <#
      $File = $private:mdfile
    #>
  
    $private:pageUid = Get-PageUid -pagesUidPrefix $ViewModel.pagesUidPrefix -mdfile $private:mdFile
    Set-MdYamlHeader -file $private:mdFile -key "uid" -value $private:pageUid
    Set-ConceptualYamlHeader -File $mdFile -RepoRelativePath $ViewModel.repoRelativePath
    }
  pop-location

  }

function script:ConvertTo-DocFxJson
{
  param([Parameter(Mandatory)]$ResourceViewModel)
  
  Write-Information "Adding resource to docfx"

  $private:workingDirectory = Join-Path (Get-Location) -childPath "DocFxHelper"

  $private:docfx_json = Join-Path $private:workingDirectory -childPath "docfx.json"

  if (test-path $private:docfx_json)
  {
    Write-Verbose "Loading existing docFx.json [$($private:docfx_json)]"
    $private:docfx = get-content $private:docfx_json | ConvertFrom-Json -AsHashtable
  }
  else
  {
    Write-Verbose "docFx.json [$($private:docfx_json)] not found"
    $private:docfx = $null
}


  if ($null -eq $private:docfx)
{  
    Write-Verbose "docfx is null, generating a generic docfx schema"
    $private:docfx = [ordered]@{
      metadata = @()
      build = [ordered]@{
        content             = @() 
        resource            = @()
        dest                = "_site"
        globalMetadata      = @{
          _enableNewTab     = $true
          _enableSearch     = $true
        }
        postProcessors      = @()
        markdownEngineName  = "markdig"
        noLangKeyword       = $false
        keepFileLink        = $false
        cleanupCacheHistory = $false
        disableGitFeatures  = $false
      }
    } 
  }
  
  

  <#
  
  $private:docfx.metadata = @()
  $private:docfx.build.content = @()
  $private:docfx.build.resource = @()
  
  #>


  push-location $private:workingDirectory

  if ($ResourceViewModel.resourceType -eq [ResourceType]::Wiki)
  {
 
    Write-Information "Wiki: [$($ResourceViewModel.id)]"
   
    $private:docfx_build_content_item = [ordered]@{
      files = "**/*.{md,yml}"
      exclude = @()
      src = "$((Resolve-Path $ResourceViewModel.docsSubfolderPath -Relative))\"
    }

    if ($ResourceViewModel.excludes)
    {
      $private:docfx_build_content_item.exclude = $ResourceViewModel.excludes
    }
  
  
    $private:docfx_build_resource_item = [ordered]@{
      files = @(".attachments/**")
      src = "$((Resolve-Path $ResourceViewModel.docsSubfolderPath -Relative))\"
    }

    if ("$($ResourceViewModel.target)" -ne "")
    {
      $private:docfx_build_content_item.dest = "$($ResourceViewModel.target)"
      $private:docfx_build_resource_item.dest = "$($ResourceViewModel.target)"
    }

    $private:docfx.build.content += $private:docfx_build_content_item
    $private:docfx.build.resource += $private:docfx_build_resource_item

    if (!$private:docfx.build.fileMetadata)
    {
      $private:docfx.build.fileMetadata = [ordered]@{}
    }
  
    if (!$private:docfx.build.fileMetadata._gitContribute)
    {
      $private:docfx.build.fileMetadata._gitContribute = [ordered]@{}
  }

    if (!$private:docfx.build.fileMetadata._gitUrlPattern)
  {
      $private:docfx.build.fileMetadata._gitUrlPattern = [ordered]@{}
    }
    
    $private:git_pattern = "$((Resolve-Path $ResourceViewModel.docsSubfolderPath -Relative))/**".replace("\", "/")
  
    $private:docfx.build.fileMetadata._gitContribute."$($private:git_pattern)" = [ordered]@{
      repo = $ResourceViewModel.wikiUrl
      branch = $ResourceViewModel.gitStatus.Branch
      relativePath = "$($ResourceViewModel.repoRelativePath)"
    }
    $private:docfx.build.fileMetadata._gitUrlPattern."$($private:git_pattern)" = "adowiki"
  }

  
  if ($ResourceViewModel.resourceType -eq [ResourceType]::Api)
  {
  
    Write-Information "  $($ResourceViewModel.id)"
  
    if ($ResourceViewModel.metadata)
  {
      $private:apiPathRelative = Resolve-Path $ResourceViewModel.metadata.srcFolder -Relative
  
      $private:docfx_metadata_content_item = [ordered]@{
        src = @(
            [ordered]@{
              files = @("**.csproj", "**.vbproj")
              src = $private:apiPathRelative
              exclude = @(
                 "**.Test.csproj"
                ,"**.Test.vbproj"
                ,"**.Tests.csproj"
                ,"**.Tests.vbproj"
                ,"**.Testing.csproj"
                ,"**.Testing.vbproj"
                ,"**.UnitTests.csproj"
                ,"**.UnitTests.vbproj"
              )
            }
        )
        comment =  "Api name: $($ResourceViewModel.id)"
        dest =  $ResourceViewModel.metadata.apiYamlPath
        disableGitFeatures =  $false
        disableDefaultFilter =  $false
        shouldSkipMarkup = $true
        #properties = @{}   
  }

      $private:docfx.metadata += $private:docfx_metadata_content_item
    }

    $private:docfx_build_content_item = [ordered]@{
      files = "**/*.{md,yml}"
      exclude = @()
      src  =  "$((Resolve-Path $ResourceViewModel.docsSubfolderPath -Relative))\"
      dest = $ResourceViewModel.target
    }

    $private:docfx.build.content += $private:docfx_build_content_item
    
  }


  if ($ResourceViewModel.resourceType -eq [ResourceType]::Conceptual)
  {
    $private:docfx_build_content_item = [ordered]@{
      files = "**/*.{md,yml}"
      exclude = @()
      src  = (Resolve-Path $ResourceViewModel.docsSubfolderPath -Relative)
      dest = $ResourceViewModel.target
  }

    $private:docfx.build.content += $private:docfx_build_content_item

    if ($ResourceViewModel.medias)
  {
      Write-Debug "Setting resources for conceptual"
      $private:docfx_build_resource_item = [ordered]@{
        files = @()
        src = "$((Resolve-Path $ResourceViewModel.docsSubfolderPath -Relative))\"
        dest = $ResourceViewModel.target
      }

      foreach ($private:media in $ResourceViewModel.medias)
    {
        $private:docfx_build_resource_item.files += "**/$($private:media)/**"
    }

      $private:docfx.build.resource += $private:docfx_build_resource_item
  }

    $private:git_pattern = "$((Resolve-Path $ResourceViewModel.docsSubfolderPath -Relative))/**".replace("\", "/")


    $private:docfx.build.fileMetadata._gitContribute."$($private:git_pattern)" = [ordered]@{
      repo = $ResourceViewModel.cloneUrl
      branch = $ResourceViewModel.gitStatus.Branch
      relativePath = "$($ResourceViewModel.repoRelativePath)"
    }

  }

  if ($ResourceViewModel.resourceType -eq [ResourceType]::PowerShellModule)
  {
    $private:docfx_build_content_item = [ordered]@{
      files = "**/*.{md,yml}"
      exclude = @()
      src  = (Resolve-Path $ResourceViewModel.docsSubfolderPath -Relative)
      dest = $ResourceViewModel.target
    }

    $private:docfx.build.content += $private:docfx_build_content_item
   
    $private:git_pattern = "$((Resolve-Path $ResourceViewModel.docsSubfolderPath -Relative))/**".replace("\", "/")
  
    $private:docfx.build.fileMetadata._gitContribute."$($private:git_pattern)" = [ordered]@{
      repo = $ResourceViewModel.cloneUrl
      branch = $ResourceViewModel.gitStatus.Branch
      relativePath = "$($ResourceViewModel.repoRelativePath)"
    }

  }

  Pop-Location

  $private:docfx | ConvertTo-Json -Depth 4 | Set-Content $private:docfx_json -Force
  Write-Host "Resource [$($ResourceViewModel.id)] added to docfx"
}

function Initialize-DocFxHelper
{
  saveDocFxHelperViewModel -ViewModel ([ordered]@{root = $null;all = @()})
}

function Add-AdoWiki
{
  param(
    [Parameter(Mandatory)][Uri]$CloneUrl,
    [Uri]$WikiUrl,
    [string]$Target,
    [string]$MenuParentItemName,
    [string]$MenuDisplayName,
    [int]$MenuPosition,
    [string]$Homepage,
    [string[]]$Excludes,
    [string]$WikiDocsSubfolder,
    [string[]]$Medias,
    [string]$ParentId
    )

  Write-Information "$CloneUrl"

  $private:a = @{
    ResourceType       = [ResourceType]::Wiki
    CloneUrl           = $CloneUrl
    SubFolder          = $WikiDocsSubfolder
    Target             = $Target
    MenuParentItemName = $MenuParentItemName
    MenuDisplayName    = $MenuDisplayName
    MenuPosition       = $MenuPosition
    Homepage           = $Homepage
    Medias             = $Medias
    ParentId           = $ParentId
  }
  Write-Verbose "Generate Wiki ViewModel"
  $private:wikiViewModel = getDocFxHelperResourceViewModel @private:a    
  $private:wikiViewModel.wikiUrl = "$WikiUrl"
  $private:wikiViewModel.isChildWiki = ("$($private:wikiViewModel.target)" -eq "")
  $private:wikiViewModel.medias += ".attachments"
  
  if ("$($private:wikiViewModel.wikiUrl)" -eq "")
  {
    $private:wikiViewModel.wikiUrl = "$($CloneUrl.Scheme)://$($CloneUrl.DnsSafeHost)$($CloneUrl.PathAndQuery.Replace("/_git/", "/_wiki/wikis/"))"
  }

  $private:docFxHelperViewModel = getDocFxHelperViewModel

  setDocFxHelperResourceHierarchy -DocFxHelperViewModel $private:docFxHelperViewModel -ResourceViewModel $private:wikiViewModel
  
  if ($null -eq $private:docFxHelperViewModel.wikis)
{
    $private:docFxHelperViewModel.wikis = @()
  }
  $private:docFxHelperViewModel.all += $private:wikiViewModel
  $private:docFxHelperViewModel.wikis += $private:wikiViewModel
  
  saveDocFxHelperViewModel -ViewModel $private:docFxHelperViewModel

  Write-Host "Updating AdoWiki files to make them DocFx friendly"
  Write-Host "WikiPath: [$($private:wikiViewModel.docsSubfolderPath)]"
  Write-Host "Is Child Wiki: [$($private:wikiViewModel.isChildWiki)]"
  Update-AdoWikiToDocFx -AdoWikiViewModel $private:wikiViewModel

  Write-Host "Merging Wiki with parent"
  Merge-ResourceWithParent -ResourceViewModel $private:wikiViewModel

  FixTocItemsThatShouldPointToTheirFolderInstead -ResourceViewModel $private:docFxHelperViewModel.root

  ConvertTo-DocFxJson -ResourceViewModel $private:wikiViewModel
    
  Write-Host "Wiki is ready"
}

function Add-Api
  {
  param(
    [Parameter(Mandatory)][Uri]$CloneUrl,
    [string]$PipelineId,
    [string]$ArtifactName,
    [string]$Target,
    [string]$MenuParentItemName,
    [string]$MenuDisplayName,
    [int]$MenuPosition,
    [string]$HomepageUid,
    [string[]]$Excludes,
    [string[]]$Medias,
    [string]$ParentId
    )

  Write-Information "$CloneUrl"
  $private:docFxHelperViewModel = getDocFxHelperViewModel
  
  if ($null -eq $private:docFxHelperViewModel.apis)
    {
    $private:docFxHelperViewModel.apis = @()
  }
  
  $private:a = @{
    ResourceType       = [ResourceType]::Api
    CloneUrl           = $CloneUrl
    PipelineId         = $PipelineId
    ArtifactName       = $ArtifactName
    Target             = $Target
    MenuParentItemName = $MenuParentItemName
    MenuDisplayName    = $MenuDisplayName
    MenuPosition       = $MenuPosition
    HomepageUid        = $HomepageUid
    Medias             = $Medias
    ParentId           = $ParentId
    }    
  Write-Verbose "Generate API ViewModel"
  $private:apiViewModel = getDocFxHelperResourceViewModel @private:a
  
  setDocFxHelperResourceHierarchy -DocFxHelperViewModel $private:docFxHelperViewModel -ResourceViewModel $private:apiViewModel

  $private:docFxHelperViewModel.all += $private:apiViewModel
  $private:docFxHelperViewModel.apis += $private:apiViewModel
  
  saveDocFxHelperViewModel -ViewModel $private:docFxHelperViewModel
  
  Write-Host "Merging Api with parent"
  Merge-ResourceWithParent -ResourceViewModel $private:apiViewModel
  
  FixTocItemsThatShouldPointToTheirFolderInstead -ResourceViewModel $private:docFxHelperViewModel.root

  ConvertTo-DocFxJson -ResourceViewModel $private:apiViewModel

  Write-Host "Api $($CloneUrl) is ready"
  }
  
function Add-Conceptual
{
  param(
    [Parameter(Mandatory)][Uri]$CloneUrl,
    [Parameter(Mandatory)][string]$RepoRelativePath,
    [string]$PipelineId,
    [string]$ArtifactName,
    [string]$Target,
    [string]$MenuParentItemName,
    [string]$MenuDisplayName,
    [int]$MenuPosition,
    [string]$HomepageUid,
    [string[]]$Excludes,
    [string[]]$Medias,
    [string]$ParentId
  )

  Write-Information "Conceptual [$CloneUrl]"
  $private:a = @{
    ResourceType       = [ResourceType]::Conceptual
    CloneUrl           = $CloneUrl
    RepoRelativePath   = $RepoRelativePath
    PipelineId       = $PipelineId
    ArtifactName       = $ArtifactName
    Target             = $Target
    MenuParentItemName = $MenuParentItemName
    MenuDisplayName    = $MenuDisplayName
    MenuPosition       = $MenuPosition
    HomepageUid        = $HomepageUid
    Medias             = $Medias
    ParentId           = $ParentId
}
  Write-Verbose "Generate Conceptual ViewModel"
  $private:conceptualViewModel = getDocFxHelperResourceViewModel @private:a
  
  $private:docFxHelperViewModel = getDocFxHelperViewModel

  setDocFxHelperResourceHierarchy -DocFxHelperViewModel $private:docFxHelperViewModel -ResourceViewModel $private:conceptualViewModel

  if ($null -eq $private:docFxHelperViewModel.conceptuals)
{ 
    $private:docFxHelperViewModel.conceptuals = @()
  }
  $private:docFxHelperViewModel.all += $private:conceptualViewModel
  $private:docFxHelperViewModel.conceptuals += $private:conceptualViewModel
  
  saveDocFxHelperViewModel -ViewModel $private:docFxHelperViewModel
  
  Set-ConceptualMarkDownFiles -ViewModel $private:conceptualViewModel

  Write-Host "Merging Conceptual with parent"
  Merge-ResourceWithParent -ResourceViewModel $private:conceptualViewModel

  FixTocItemsThatShouldPointToTheirFolderInstead -ResourceViewModel $private:docFxHelperViewModel.root

  ConvertTo-DocFxJson -ResourceViewModel $private:conceptualViewModel
  
  Write-Host "Conceptual $($CloneUrl) is ready"
}
  
function Add-PowerShellModule
  {
  param(
    [Parameter(Mandatory)][Uri]$CloneUrl,
    [Parameter(Mandatory)][string]$RepoRelativePath,
    [string]$PipelineId,
    [string]$ArtifactName,
    [string]$Target,
    [string]$MenuParentItemName,
    [string]$MenuDisplayName,
    [int]$MenuPosition,
    [string]$HomepageUid,
    [string[]]$Excludes,
    [string[]]$Medias,
    [string]$ParentId
  )
    
  Write-Information "PowerShell Module [$CloneUrl]"
  $private:a = @{
    ResourceType       = [ResourceType]::PowerShellModule
    CloneUrl           = $CloneUrl
    RepoRelativePath   = $RepoRelativePath
    PipelineId         = $PipelineId
    ArtifactName       = $ArtifactName
    Target             = $Target
    MenuParentItemName = $MenuParentItemName
    MenuDisplayName    = $MenuDisplayName
    MenuPosition       = $MenuPosition
    HomepageUid        = $HomepageUid
    Medias             = $Medias
    ParentId           = $ParentId
  }
  Write-Verbose "Generate PowerShell Module ViewModel"
  $private:powerShellModuleViewModel = getDocFxHelperResourceViewModel @private:a
  
  $private:docFxHelperViewModel = getDocFxHelperViewModel

  setDocFxHelperResourceHierarchy -DocFxHelperViewModel $private:docFxHelperViewModel -ResourceViewModel $private:powerShellModuleViewModel
  
  if ($null -eq $private:docFxHelperViewModel.powerShellModules)
    {
    $private:docFxHelperViewModel.powerShellModule = @()
  }
  $private:docFxHelperViewModel.all += $private:powerShellModuleViewModel
  $private:docFxHelperViewModel.powerShellModule += $private:powerShellModuleViewModel
  
  saveDocFxHelperViewModel -ViewModel $private:docFxHelperViewModel
  
  Set-ConceptualMarkDownFiles -ViewModel $private:powerShellModuleViewModel

  Write-Host "Merging Conceptual with parent"
  Merge-ResourceWithParent -ResourceViewModel $private:powerShellModuleViewModel
  
  FixTocItemsThatShouldPointToTheirFolderInstead -ResourceViewModel $private:docFxHelperViewModel.root
    
  ConvertTo-DocFxJson -ResourceViewModel $private:powerShellModuleViewModel
    
  Write-Host "Conceptual $($CloneUrl) is ready"
    }

function Set-Template
{
  param([Parameter(Mandatory)]$Template, [Parameter(Mandatory)]$Target)

  $private:saveYamlHeader = (split-path $Target -Extension) -eq ".md"
    
  if ($private:saveYamlHeader)
  {
    if (Test-Path -Path $Target)
    {
      $private:mdMetadata = Get-MdYamlHeader -file $Target
    }
    else
    {
      $private:mdMetadata = [ordered]@{}
    }
    $private:mdMetadata.generatedFrom = $Template
    $private:mdMetadata.generatedAt = (Get-Date).DateTime
    $private:mdMetadata.generatedOn = "$($ENV:COMPUTERNAME)"
    $private:mdMetadata.generatedBuildNumber = "$($ENV:BUILD_BUILDNUMBER)"
  }

  $private:resultFolder = (Split-path $Target)

  if (!(test-Path $private:resultFolder))
  {
    new-item -path $private:resultFolder -Force -ItemType Directory
  }
  Write-Debug "  Template: [$($Template)]"
  Write-Debug "    Result: [$($Target)]"      
  $private:docFxHelperViewModel = getDocFxHelperViewModel
  $private:docFxHelperViewModelJson = $private:docFxHelperViewModel | ConvertTo-Json -Depth 4
  $private:result = ConvertTo-PoshstacheTemplate -InputFile $Template -ParametersObject $private:docFxHelperViewModelJson -Verbose
  $private:result | Set-Content $Target -Force

  if ($private:saveYamlHeader)
  {
    Set-MdYamlHeader -file $Target -data $private:mdMetadata
  }
  
}
