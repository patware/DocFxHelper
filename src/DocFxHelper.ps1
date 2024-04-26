#Requires -Version 7
#Requires -Modules 'Posh-git', 'yayaml', 'Poshstache'
<#
  .SYNOPSIS
  Helps teams merge various document sources into one site.
  
  .DESCRIPTION
  Script that helps in the integration of ADO Wikis, APIs, Conceptual Documentations and PowerShell modules into DocFx

#>

$script:DocFxHelperVersions = @(
    [ordered]@{version=[Version]"0.3.1"; title="Get-DocFxHelperResourcePageUidPrefix"}
    [ordered]@{version=[Version]"0.3.2"; title="ConvertTo-DocFxAdoWiki -IsRootWiki instead of -IsChildWiki"}
    [ordered]@{version=[Version]"0.3.3"; title="DocFxHelper is now global, and not mandatory param"}
    [ordered]@{version=[Version]"0.3.4"; title="Re-added missing Add-Api"}
    [ordered]@{version=[Version]"0.3.5"; title="Using PowerShell Module YaYaml instead of PowerShell-Yaml"}
    [ordered]@{version=[Version]"0.3.5.1"; title="Adjust Differences between PowerShell-Yaml and YaYaml"}
    [ordered]@{version=[Version]"0.3.5.2"; title="Fixed Convert AdoWiki step 1 conversion of .orders"}
    [ordered]@{version=[Version]"0.3.6"; title="Re-worked ConvertTo-DocFxAdoWiki"}
    [ordered]@{version=[Version]"0.3.6.1"; title="Renamed New-DocFx parameters"}
    [ordered]@{version=[Version]"0.3.7"; title="Refactor of ConvertTo-DocFxAdoWiki - .order conversion at end of steps"}
    [ordered]@{version=[Version]"0.3.8"; title="Copy-Robo"}
    [ordered]@{version=[Version]"0.3.8.1"; title="Copy-Robo -ShowVerbose because of parameter with name duplicate"}
    [ordered]@{version=[Version]"0.3.8.2"; title="Copy-Robo platform is Unix not linux"}
    [ordered]@{version=[Version]"0.3.9"; title="Get-AdoWikiTocItem fix typo with trailing slash"}
    [ordered]@{version=[Version]"0.3.10"; title="ConvertTo-DocFx* - yamlheader with _docfxHelper.remote instead of adoWikiAbsolutePath and _gitContribute"}
    [ordered]@{version=[Version]"0.3.10.1"; title="Fix: Docfx.json ADOwiki attachments wrong dest"}
    [ordered]@{version=[Version]"0.3.10.2"; title="Fix: ADOWiki moved the _adoWikiUri"}
    [ordered]@{version=[Version]"0.3.10.3"; title="Multiple ADOWiki fixes stabilization phase"}
    [ordered]@{version=[Version]"0.3.11"; title="Test-Different"}
)

$script:DocFxHelperVersion = $DocFxHelperVersions[-1]
Write-Host "DocFxHelper.ps1 Version [$($DocFxHelperVersion.Version)] $($DocFxHelperVersion.title)"

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

enum ResourceType
{
  Unknown = 0
  Wiki = 1
  Api = 2
  Conceptual = 3
  PowerShellModule = 4
}

$requiredModules = @("Posh-git", "yayaml", "Poshstache")

foreach ($requiredModule in $requiredModules)
{
  if (Get-Module $requiredModule)
  {
    Write-Verbose "Module $($requiredModule) already loaded"
  }
  else
  {
    Write-Verbose "Loading module $($requiredModule)"
    import-module $requiredModule -Verbose
  }

}

#region Utilities

<#
.SYNOPSIS
Retries a powershell command n-times. 

.DESCRIPTION
The cmdlet is capable of retrying a PowerShell command passed as a [ScriptBlock] according to the user defined number of retries and timeout (In Seconds)

From Prateek Kumar Singh https://gist.github.com/PrateekKumarSingh/65afe12a3fda5ef9ba42bf0673026728

.PARAMETER TimeoutInSecs
Timeout in secods for each retry.

.PARAMETER RetryCount
Number of times to retry the command. Default value is '3'

.PARAMETER ScriptBlock
PoweShell command as a ScriptBlock that will be executed and retried in case of Errors. Make sure the script block throws an error when it fails, otherwise the cmdlet won't run the retry logic.

.PARAMETER SuccessMessage
Message displayed when the command was executed successfuly.

.PARAMETER FailureMessage
Message displayed when the command was failed to execute.

.EXAMPLE

 Invoke-CommandWithRetry -ScriptBlock {Test-Connection 'test.com'} -Verbose

VERBOSE: [1/3] Failed to Complete the task. Retrying in 30 seconds...
VERBOSE: [2/3] Failed to Complete the task. Retrying in 30 seconds...
VERBOSE: [3/3] Failed to Complete the task. Retrying in 30 seconds...
VERBOSE: Failed to Complete the task! Total retry attempts: 3
VERBOSE: [Error Message] Testing connection to computer 'test.com' failed: Error due to lack of resources

Try test connection to the website that doesn't exists, which will throw host not found error. Any error is caught by the Invoke-CommandWithRetry cmdlet and it will retry to execute test connection 3 more times. By default 3 retry attempts are made at every 30 seconds and you have to explicitly define the 'Verbose' switch to see the retry logic in action.

.EXAMPLE

 Invoke-CommandWithRetry -ScriptBlock {Get-Service bits | Stop-Service} -TimeoutInSecs 2 -RetryCount 5 -Verbose

VERBOSE: [1/5] Failed to Complete the task. Retrying in 2 seconds...
VERBOSE: [2/5] Failed to Complete the task. Retrying in 2 seconds...
VERBOSE: [3/5] Failed to Complete the task. Retrying in 2 seconds...
VERBOSE: [4/5] Failed to Complete the task. Retrying in 2 seconds...
VERBOSE: [5/5] Failed to Complete the task. Retrying in 2 seconds...
VERBOSE: Failed to Complete the task! Total retry attempts: 5
VERBOSE: [Error Message] Service 'Background Intelligent Transfer Service (bits)' cannot be stopped due to the following error: Cannot open bits service on computer '.'.

We can customize the number of retry attempts and timeout times using the parameters: '-RetryCount' and '-TimeoutInSecs' respectively.

.EXAMPLE

 Invoke-CommandWithRetry -ScriptBlock {Write-Error -Message 'something went wrong!'} -TimeoutInSecs 2 -Verbose

VERBOSE: [1/3] Failed to Complete the task. Retrying in 2 seconds...
VERBOSE: [2/3] Failed to Complete the task. Retrying in 2 seconds...
VERBOSE: [3/3] Failed to Complete the task. Retrying in 2 seconds...
VERBOSE: Failed to Complete the task! Total retry attempts: 3
VERBOSE: [Error Message] something went wrong!

In some scenarios you would want the retry logic when something fails or you don't get a desired output. In such cases to implement the retry logic, make sure to throw and error in you script block that would be executed

.EXAMPLE

Invoke-CommandWithRetry -ScriptBlock {
    if(2 -eq 2){
        throw('Exception occured!')
    }
} -TimeoutInSecs 2 -Verbose

VERBOSE: [1/3] Failed to execute the command. Retrying in 2 seconds...
VERBOSE: [2/3] Failed to execute the command. Retrying in 2 seconds...
VERBOSE: [3/3] Failed to execute the command. Retrying in 2 seconds...
VERBOSE: Failed to execute the command! Total retry attempts: 3
VERBOSE: [Error Message] Exception occured!

You can even define some conditional statements and throw errors to trigger the retry statments in your program.

.EXAMPLE

{Test-Connection 'prateeks.cim'},{Write-Host 'hello'} ,{1/0} | Invoke-CommandWithRetry -TimeoutInSecs 2 -Verbose

VERBOSE: [1/3] Failed to execute the command. Retrying in 2 seconds...
VERBOSE: [2/3] Failed to execute the command. Retrying in 2 seconds...
VERBOSE: [3/3] Failed to execute the command. Retrying in 2 seconds...
VERBOSE: Failed to execute the command! Total retry attempts: 3
VERBOSE: [Error Message] Testing connection to computer 'prateeks.cim' failed: No such host is known

hello
VERBOSE: Command executed successfuly!

VERBOSE: [1/3] Failed to execute the command. Retrying in 2 seconds...
VERBOSE: [2/3] Failed to execute the command. Retrying in 2 seconds...
VERBOSE: [3/3] Failed to execute the command. Retrying in 2 seconds...
VERBOSE: Failed to execute the command! Total retry attempts: 3
VERBOSE: [Error Message] Attempted to divide by zero.

Capable of handling scriptblock's as input through the pipeline.

.NOTES
General notes
#>

function Invoke-CommandWithRetry {
  [CmdletBinding()]
  param (
      [parameter(Mandatory, ValueFromPipeline)] 
      [ValidateNotNullOrEmpty()]
      [scriptblock] $ScriptBlock,
      [int] $RetryCount = 3,
      [int] $TimeoutInSecs = 30,
      [string] $SuccessMessage = "Command executed successfuly!",
      [string] $FailureMessage = "Failed to execute the command"
      )
      
  process {
      $Attempt = 1
      $Flag = $true
      
      do {
          try {
              $PreviousPreference = $ErrorActionPreference
              $ErrorActionPreference = 'Stop'
              Invoke-Command -ScriptBlock $ScriptBlock -OutVariable Result              
              $ErrorActionPreference = $PreviousPreference

              # flow control will execute the next line only if the command in the scriptblock executed without any errors
              # if an error is thrown, flow control will go to the 'catch' block
              Write-Verbose "$SuccessMessage `n"
              $Flag = $false
          }
          catch {
              if ($Attempt -gt $RetryCount) {
                  Write-Verbose "$FailureMessage! Total retry attempts: $RetryCount"
                  Write-Verbose "[Error Message] $($_.exception.message) `n"
                  $Flag = $false
              }
              else {
                  Write-Verbose "[$Attempt/$RetryCount] $FailureMessage. Retrying in $TimeoutInSecs seconds..."
                  Start-Sleep -Seconds $TimeoutInSecs
                  $Attempt = $Attempt + 1
              }
          }
      }
      While ($Flag)
      
  }
}

function Copy-Robo
{
  param(
    [Parameter(Mandatory)]$source, 
    [Parameter(Mandatory)]$destination, 
    [switch]$Mirror, 
    [switch]$ShowFullpath, 
    [switch]$ShowVerbose
  )

  $cmd = $null
  $a = @()
  
  Write-Debug "Platform: [$($PSVersionTable.Platform)]"

  if ("$($PSVersionTable.Platform)" -eq "Unix")
  {
    $cmd = "rsync"
    # --exclude=PATTERN    
    if ($Mirror){
      $a += "--archive"
      $a += "--delete"
    }

    if ($ShowFullpath) { $a += "-vv" }
    elseif ($ShowVerbose) { $a += "-v" }

    $sourceItem = Get-Item $source
    if ($sourceItem.PSIsContainer)
    {
      if (!"$($source)".EndsWith("/"))
      {
        $source = "$($source)/"
      }
      if (!"$destination".EndsWith("/"))
      {
        $destination = "$($destination)/"
      }
    }
    $a += $source
    $a += $destination

  }
  else
  {
    $cmd = "robocopy"    
    $a = @()
    $a += "$source"
    $a += "$destination"

    if ($Mirror) { $a += "/MIR" }
    if ($ShowFullPath) { $a += "/FP" }
    if ($ShowVerbose) { $a += "/V" }
  }

  $destinationParentFolder = (Split-Path $destination)

  if (Test-Path $destinationParentFolder)
  {
    Write-Debug "Parent folder $destinationParentFolder already exists"
  }
  else
  {
    Write-Debug "Parent folder $destinationParentFolder not found, creating"
    New-Item $destinationParentFolder -ItemType Directory -Force
  }

  Write-Host "Running $cmd $($a -join " ")"
  $res = & $cmd @a
  if ($cmd -eq "robocopy")
  {
    if ($LastExitCode -gt 7)
    {
      Write-Error ($res | out-string)
    }
  }elseif ($cmd -eq "rsync")
  {
    if ($LastExitCode -ne 0)
    {
      Write-Error ($res | out-string)
    }
  }
  Write-Host "Finished running $cmd $($a -join " "): result code [$LastExitCode]"
  $LastExitCode = 0

}

function Test-Different
{
  param(
    [Parameter(Mandatory)]$source,
    [Parameter(Mandatory)]$destination
  )

  $cmd = $null
  $a = @()

  $destinationParentFolder = (Split-Path $destination)
  if (Test-Path $destinationParentFolder)
  {
    Write-Debug "Parent folder $destinationParentFolder already exists"
  }
  else
  {
    Write-Debug "Parent folder $destinationParentFolder not found, creating"
    New-Item $destinationParentFolder -ItemType Directory -Force
  }
  
  Write-Debug "Platform: [$($PSVersionTable.Platform)]"

  if ("$($PSVersionTable.Platform)" -eq "Unix")
  {
    $cmd = "diff"
    # --exclude=PATTERN    
    
    $a += "--recursive"
    
    $sourceItem = Get-Item $source
    if ($sourceItem.PSIsContainer)
    {
      if (!"$($source)".EndsWith("/"))
      {
        $source = "$($source)/"
      }
      if (!"$destination".EndsWith("/"))
      {
        $destination = "$($destination)/"
      }
    }
    $a += $source
    $a += $destination

  }
  else
  {
    $cmd = "robocopy"
    $a = @("$source", "$destination", "/MIR", "/L", "/NS", "/NC", "/NFL", "/NDL", "/NP", "/NJH")
  }

  Write-Host "Running $cmd $($a -join " ")"

  $res = & $cmd @a

  $res = $null
  if ($cmd -eq "robocopy")
  {
    if ($LASTEXITCODE -eq 0)
    {
      $res = $false
    }elseif ($LASTEXITCODE -lt 8)
    {
      $res = $true
    }

  }elseif ($cmd -eq "diff")
  {
    if ($LastExitCode -eq 0)
    {
      $res = $false
    }elseif ($LASTEXITCODE -eq 1)
    {
      $res = $true
    }

  }
  Write-Host "Finished running $cmd $($a -join " "): Exit code $($LASTEXITCODE)"
  Write-Host "Source different? $($res)"
  $LastExitCode = 0
  return $res
}

function script:Get-DocFxHelperResourcePageUidPrefix
{
  param($Target)

  $fixedTarget = Util_Get_FixedTargetUri -Target $Target  
  $siteUri = [Uri]::new($baseUri, $fixedTarget)

  Write-Debug "Relative Path [$fixedTarget] has siteUri [$($siteUri)]"
  $sitePath = $siteUri.AbsolutePath

  $pagesUidPrefix = "$($sitePath)".Replace("\", "/").Replace("/", "_")
  $pagesUidPrefix = "$($pagesUidPrefix)" -replace '(_*)(.*)', '$2'
  $pagesUidPrefixSegments = $pagesUidPrefix.Split("_")
  
  $pagesUidPrefix = ($pagesUidPrefixSegments | where-object { $_ }) -join "_"
  
  if ("$pagesUidPrefix" -ne "")
  {
    $pagesUidPrefix = "$($pagesUidPrefix)_"
  }
  
  Write-Debug "Pages UID Prefix for [$($fixedTarget)] is [$($pagesUidPrefix)]"
  return $pagesUidPrefix
}

function script:Util_Get_MdYamlHeader
{
  param([System.IO.FileInfo]$file)
  
  Write-Debug "Util_Get_MdYamlHeader"
  Write-Debug "  file: [$file]"
  $md = Util_Convert_FromMdFile -file $file

  return $md.data
 
}

function script:Util_Convert_FromMdFile
{
  param([System.IO.FileInfo]$file)

  Write-Debug "Util_Convert_FromMdFile"
  Write-Debug "  file: [$file]"

  $content = get-content -LiteralPath $file.FullName

  $yamlHeaderMarkers = $content | select-string -pattern '^---\s*$'

  $ret = @{
    data       = [ordered]@{}
    conceptual = $content
  }

  if ($yamlHeaderMarkers.count -ge 2 -and $yamlHeaderMarkers[0].LineNumber -eq 1)
  {
    Write-Debug "Markdown file has Yaml Header Markers"
    $yaml = $content[1 .. ($yamlHeaderMarkers[1].LineNumber - 2)]
    
    $ret.data = $yaml | convertfrom-Yaml
    $ret.conceptual = $content | select-object -skip $yamlHeaderMarkers[1].LineNumber
  }

  return $ret

}


function script:Util_Set_MdYamlHeader
{
  param([System.IO.FileInfo]$file, $data, $key, $value)
  
  Write-Debug "Util_Set_MdYamlHeader"
  Write-Debug "  file: [$file]"
  Write-Debug "   key: [$key]"
  Write-Debug " value: [$($value | ConvertTo-Json -Compress -WarningAction SilentlyContinue)]"
  
  $mdFile = Util_Convert_FromMdFile -file $file

  if ($data)
  {
    $mdFile.data = $data
  }

  if ($key)
  {
    $mdFile.data[$key] = $value
  }

  $dataSection = $mdFile.data | ConvertTo-Yaml -Depth 10
  $conceptualSection = $mdFile.conceptual -join "`n"

  $content = @"
---
$dataSection
---
$conceptualSection
"@

  $content | set-content -LiteralPath $file.FullName

}

function script:Util_Get_PageUid
{
  param($pagesUidPrefix, $mdFile)

  $mdFileDirectoryFullname = (split-path $mdFile)
  $mdFileBasename = (split-path $mdFile -LeafBase)

  $mdMetadata = Util_Get_MdYamlHeader -file $mdFile

  if ($mdMetadata.uid)
  {
    Write-Verbose "Using Yaml Metadata uid: $($mdMetadata.uid)"
    return $mdMetadata.uid
  }
  else
  {
    Write-Verbose "Generating uid from md file path"
    $workingDirectory = (Get-Location)
  
    $relative = (join-Path $mdFileDirectoryFullname -ChildPath $mdFileBasename).Substring($workingDirectory.Path.Length)
    
    $pageSegments = $relative.Replace(" ", "_").Split("$([IO.Path]::DirectorySeparatorChar)", [System.StringSplitOptions]::RemoveEmptyEntries)
    
    $pageUid = "$($pagesUidPrefix)$($pageSegments -join "_")"
    Write-Verbose "File: $(Resolve-Path -path $mdfile -Relative) UID: $pageUid"

  }


  return $pageUid

}

function Get-NormalizedTocItem
{
  [cmdletbinding()]
  param($Href, $Homepage, $uid)

  process
  {
    $relativePath = $null
    $foldername = $null
    $filename = $null


    if ($homepage)
    {
      $segments = $homepage.replace("\", "/") -split "/"

      $filename = $segments | select-object -last 1

      $foldername = $segments | select-object -skiplast 1 | select-object -last 1
      $relativePath = ($segments | select-object -SkipLast 2) -join "/"

    }

    if ($href)
    {
      $segments = $href.replace("\", "/") -split "/" | where-object {$_}

      if ($href.EndsWith("/"))
      {
        $foldername = $segments | select-object -last 1
        $relativePath = ($segments | select-object -SkipLast 1) -join "/"
      }
      elseif ($href.EndsWith("/toc.yml"))
      {
        $foldername = $segments | select-object -skiplast 1 | select-object -last 1
        $relativePath = ($segments | select-object -SkipLast 2) -join "/"
      }
      else
      {
        if ($href.EndsWith(".md"))
        {
          if ($null -ne $filename)
          {
            Write-Warning "href ends with .md, but homepage is also provided, href wins over homepage."
          }
          $filename = $segments | select-object -last 1
          $foldername = $segments | select-object -skiplast 1 | select-object -last 1
          $relativePath = ($segments | select-object -SkipLast 2) -join "/"

        }
        else
        {
          if ($null -ne $filename)
          {
            $foldername = $segments | select-object -last 1
            $relativePath = ($segments | select-object -SkipLast 1) -join "/"
          }
          else
          {
            $filename = "$($segments | select-object -last 1).md"
            $foldername = $segments | select-object -skiplast 1 | select-object -last 1
            $relativePath = ($segments | select-object -SkipLast 2) -join "/"

          }
          
        }
      }
    }

    if ($null -eq $filename)
    {
      $filename = "$($foldername).md"
    }

    if ($null -eq $foldername)
    {
      $foldername = $filename.Replace(".md", "")
    }

    $relativePath = "$($relativePath)"
    

    return [PSCustomObject][ordered]@{
      href = $href
      homepage = $homepage
      uid = $Uid
      relativePath = $relativePath
      foldername = $foldername
      filename = $filename
    }
  }

}

function script:Util_RoboCopy
{
  param($Title, $Source, $Destination)

  $robocopy = [ordered]@{
    Source      = $Source
    Destination = $Destination
  }
  
  Write-Information "Copying [$($Title)]"
  Write-Information "  From: [$($robocopy.Source)]"
  Write-Information "    To: [$($robocopy.Destination)]"
  
  $robocopyResult = Robocopy.exe $robocopy.Source $robocopy.Destination /MIR /NS /NC /NFL /NDL /NP

  if ($LastExitCode -gt 7)
  {
    Write-Error ($robocopyResult | out-string)
    # an error occurred
    exit $LastExitCode
  }

  $LastExitCode = 0
}

function script:Util_FindTocItemRecursive
{
  param([HashTable]$InputObject, [string]$Key, $Value)

  $found = $InputObject | where-object {$_."$Key" -eq $Value}

  if ($found)
  {
    return $found
  }
  else
  {
    foreach($child in $InputObject.items)
    {
      $found = Util_FindTocItemRecursive -InputObject $child -Key $Key -Value $Value

      if ($found)
      {
        return $found
      }
    }
  }
  
}

function script:Util_Get_FixedTargetUri
{
  param($Target)
 
  Write-Debug "Target: [$Target]"
  $fixedTarget = (@("") + ("$($Target)".Trim().Replace("\","/") -split "/" | where-object {$_}) + @("")) -join "/"
 
  Write-Debug "Target: [$FixedTarget] (fixed)"
  $fixedTargetUri = [Uri]::new($baseUri, $fixedTarget)
 
  return $fixedTargetUri
}

<#
.EXAMPLE 
Util_Merge_HashTable | Convertto-json
Returns empty hashtable
```json
{}
```

.EXAMPLE
Util_Merge_HashTable -Default @{} | Convertto-json
Returns the Default, ignoring existing
```json
{}
```

.EXAMPLE
Util_Merge_HashTable -Default @{foo="bar"} | Convertto-json
Returns the Default, ignoring existing
```json
{
  "foo": "bar"
}
```

.EXAMPLE
Util_Merge_HashTable -Existing @{} | Convertto-json
Returns the Existing, ignoring default
```json
{}
```

.EXAMPLE
Util_Merge_HashTable -Existing @{foo="existing"} | Convertto-json
Returns the Existing, ignoring default
```json
{
  "foo": "existing"
}
```

.EXAMPLE
Util_Merge_HashTable -Default @{} -Existing @{foo="existing"} | Convertto-json
Returns the Existing, default doesn't have a key that existing doesn't
```json
{
  "foo": "existing"
}
```

.EXAMPLE
Util_Merge_HashTable -Default @{foo="default"} -Existing @{foo="existing"} | Convertto-json
Returns the Existing, default doesn't have a key that existing doesn't
```json
{
  "foo": "existing"
}
```

.EXAMPLE
Util_Merge_HashTable -Default @{foo="default"} -Existing @{} | Convertto-json
Returns default, because existing doesn't have the key foo
```json
{
  "foo": "default"
}
```

.EXAMPLE
Util_Merge_HashTable -Default @{foo="default"} -Existing @{foo=$null} | Convertto-json
Returns default, because existing foo is null
```json
{
  "foo": "default"
}
```

.EXAMPLE
Util_Merge_HashTable -Default @{bar="default bar"} -Existing @{foo="existing foo"} | Convertto-json
Returns merged hashTable...  @{foo="existing foo";bar="default bar"}
```json
{
  "bar": "default bar",
  "foo": "existing foo"
}
```

.EXAMPLE
Util_Merge_HashTable -Default @{bar="default bar";snafu=@{x="default x";y="default y"}} -Existing @{foo="existing foo"} | Convertto-json
Returns merged hashTable, including the child snafu hashtable from the default..
```json
{
  "foo": "existing foo",
  "bar": "default bar",
  "snafu": {
    "x": "default x",
    "y": "default y"
  }
}
```

.EXAMPLE
Util_Merge_HashTable -Default @{bar="default bar";snafu=@{x="default x";y="default y"}} -Existing @{foo="existing foo";snafu=@{x="existing x";y="existing y"}}  | Convertto-json
Returns the existing hashtable, plus default's bar
```json
{
  "foo": "existing foo",
  "snafu": {
    "x": "existing x",
    "y": "existing y"
  },
  "bar": "default bar"
}
```

.EXAMPLE
Util_Merge_HashTable -Default @{bar="default bar";snafu=@{x="default x";y="default y"}} -Existing @{foo="existing foo";snafu=@{y="existing y"}} | Convertto-json
Returns the existing hashtable, plus default's bar and snafu's x from the default
```json
{
  "foo": "existing foo",
  "snafu": {
    "y": "existing y",
    "x": "default x"
  },
  "bar": "default bar"
}
```

.EXAMPLE
$d = [ordered]@{bar="default bar";snafu=[ordered]@{x="default x";y="default y"}}
$x = [ordered]@{foo="existing foo";snafu=[ordered]@{y="existing y"}}

Util_Merge_HashTable -Default $d -Existing $x | Convertto-json
Returns the existing hashtable, plus default's bar and snafu's x from the default
```json
{
  "foo": "existing foo",
  "snafu": {
    "y": "existing y",
    "x": "default x"
  },
  "bar": "default bar"
}
```
#>

function script:Util_Merge_HashTable
{
  param([System.Collections.IDictionary]$Default, [System.Collections.IDictionary]$Existing)


  Write-Debug "[Util_Merge_HashTable]"
  if ($null -eq $Default -and $null -eq $Existing)
  {
    Write-Debug "Both Default and Existing are null, returning empty hashtable"
    return @{}
  }

  if ($Existing -and $null -eq $Default)
  {
    Write-Debug "Default is null, returning Existing"
    return $Existing
  }

  if ($Default -and $null -eq $Existing)
  {
    Write-Debug "Existing is null, returning default"
    if ($Default -is [System.ICloneable])
    {
      return $Default.Clone()
    }

    Write-Debug "Default can't be cloned, returning Default"
    return $Default
  }


  Write-Debug "Looping through Default's values to find values in Existing"

  foreach ($key in $Default.Keys)
  {

    if ($Existing.Contains($key))
    {
      if ($null -eq $Existing."$key")
      {
        Write-Debug "Existing value for key $Key is null, using default's"
        $Existing."$key" = $Default."$Key"
      }
      else
      {
        if ($Existing."$Key" -is [System.Collections.IDictionary])
        {
          Write-Debug "Calling [Util_Merge_HashTable] to merging values from $Key"
          $Existing."$Key" = Util_Merge_HashTable -Default $Default."$Key" -Existing $Existing."$Key"
        }
        else
        {
          Write-Debug "Existing already has key $Key"
        }
      }
    }
    else
    {

      Write-Debug "Existing does not have the $Key, using default's"
      $Existing."$key" = $Default."$Key"
    }
  }

  Write-Debug "Returning Existing with merged values from Default"
  
  return $Existing
}

#endregion

#region ViewModel

function Add-DocFxHelperResource
{
  param(
    [Parameter(Mandatory)]$Resource
  )
  
  Write-Debug "----------------------------------------------"
  Write-Debug "Add Resource ViewModel to ViewModel"

  if ($null -eq $DocFxHelper.all)
  {
    $DocFxHelper.all = @()
  }

  $DocFxHelper.all += $resource

  if ($Resource.ResourceType -eq [ResourceType]::Wiki)
  {
    if ($null -eq $DocFxHelper.wikis)
    {
      $DocFxHelper.wikis = @()
    }    
    $DocFxHelper.wikis += $resource    
  }
  elseif ($Resource.ResourceType -eq [ResourceType]::Api)
  {
    if ($null -eq $DocFxHelper.apis)
    {
      $DocFxHelper.apis = @()
    }    
    $DocFxHelper.apis += $resource
  }
  elseif ($Resource.ResourceType -eq [ResourceType]::PowerShellModule)
  {
    if ($null -eq $DocFxHelper.powershellModules)
    {
      $DocFxHelper.powershellModules = @()
    }    
    $DocFxHelper.powershellModules += $resource
  }
  elseif ($Resource.ResourceType -eq [ResourceType]::Conceptual)
  {
    if ($null -eq $DocFxHelper.conceptuals)
    {
      $DocFxHelper.conceptuals = @()
    }    
    $DocFxHelper.conceptuals += $resource
    
  }
  else
  {
    Write-Warning "Resource type $($Resource.ResourceType) not recognized"
  }
  
  ViewModel_setDocFxHelperResourceHierarchy -ResourceViewModel $resource

}

function script:ViewModel_getGenericResourceViewModel
{
  param(
    [Parameter(Mandatory)][ResourceType]$ResourceType
    , [Parameter(Mandatory)]$Id
    , [Parameter(Mandatory)][System.IO.DirectoryInfo]$Path    
    , [Uri]$CloneUrl
    , $RepoBranch
    , $RepoRelativePath
    , $SubFolder
    , $Target
    , $MenuParentItemName
    , $MenuDisplayName
    , [int]$MenuPosition = -1
    , $Excludes
    , $Homepage
    , $MenuUid
    , $ParentId
    , $Medias
    , $Templates
  )
  
  $fixedTargetUri = Util_Get_FixedTargetUri -Target $Target

  $vm = [ordered]@{
    id                      = $Id
    resourceType            = $ResourceType                # wiki, api, conceptual or powerShellModule
    resourceIdPrefix        = "$($ResourceType)"           # wiki, api, conceptual or powerShellModule
    path                    = $Path.FullName               # resource path
    cloneUrl                = $CloneUrl
    repoBranch              = $RepoBranch                  # 
    repoRelativePath        = $RepoRelativePath
    target                  = $fixedTargetUri.AbsolutePath
    targetUri               = $fixedTargetUri
    menuParentItemName      = $MenuParentItemName
    menuDisplayName         = $MenuDisplayName
    menuPosition            = $MenuPosition
    excludes                = $Excludes
    medias                  = @()
    docsSubfolder           = $SubFolder                   
    homepage                = $Homepage         
    menuUid                 = $MenuUid
    parentId                = $ParentId
    parentToc_yml           = $null                        # full path to parent's toc.yml - will be set in ViewModel_setDocFxHelperResourceHierarchy
    parentToc_yml_isRoot    = $false                       # true if the parent's toc.yml is the root toc - will be set in ViewModel_setDocFxHelperResourceHierarchy
    templates               = @()
    metadata                = $null                        # not implemented yet
  }

  if ("$($vm.repoBranch)" -eq "")
  {
    $vm.repoBranch = "main"
  }
  if ("$($vm.repoRelativePath)" -eq "")
  {
    $vm.repoRelativePath = "/"
  }    

  $vm.pagesUidPrefix = Get-DocFxHelperResourcePageUidPrefix -Target $vm.target

  # if ($vm.homepage -and "$($vm.TopicUid)".Trim() -eq "")
  # {
  #   $homepagePath = Join-Path -Path $vm.Path -ChildPath $vm.homepage
  #   Write-Debug "homepage provided, but not the TopicUid, reading the yaml header from the homepage [$($homepagePath)]"

  #   $homepageMeta = Util_Get_MdYamlHeader -file $homepagePath

  #   $vm.TopicUid = $homepageMeta.uid
  #   Write-Debug "TopicUid: [$($vm.TopicUid)]"    
  # }


  if ($Medias)
  {
    Write-Debug "adding [$($Medias.count)] media to item"
  
    foreach ($media in $Medias)
    {
      if (!($vm.media | where-object { $_ -eq $media }))
      {
        Write-Debug " media: adding [$($media)] from DocFxHelper"
        $vm.medias += $media
      }
    }
  }

  return $vm
}


function script:ViewModel_setDocFxHelperResourceHierarchy
{
  param([Parameter(Mandatory)]$ResourceViewModel)

  if ($null -eq $DocFxHelper.root)
  {
    $docFxHelper.root = $ResourceViewModel
  }

  if ("$($ResourceViewModel.parentId)" -eq "")
  {
    Write-Verbose "Set a parentId to items that have none defined: $($docFxHelper.root.id)"
    $ResourceViewModel.parentId = $docFxHelper.root.id
  }

  if ($ResourceViewModel.id -ne $docFxHelper.root.id)
  {
    Write-Information "Identify resource's parent toc.yml"
    <#
      $docFxHelper.all | select-object id, parentid
    #>
    $parent = $docFxHelper.all | where-object { $_.id -eq $ResourceViewModel.parentId }

    if ($parent)
    {
      # if parent targetUri is /a/b
      # and resource targetUri is /a/b/c/d/e
      # then adjustedSegments is c/d (remove parent, then skip last)
      $adjustedSegments = $ResourceViewModel.targetUri.Segments | select-object -skip $Parent.targetUri.Segments.Count | select-object -skiplast 1
      #$itemTargetSegments = "$($ResourceViewModel.target)".replace("\", "/") -split "/" | where-object { $_ }
      #$parentTargetSegments = "$($parent.target)".replace("\", "/") -split "/" | where-object { $_ }
      #$adjustedSegments = $itemTargetSegments | select-object -skip $parentTargetSegments.count
      $ResourceViewModel.parentToc_yml = Join-Path -Path $parent.path -ChildPath ($adjustedSegments -join "\") -AdditionalChildPath "toc.yml"
      if (!(Test-Path $ResourceViewModel.parentToc_yml))
      {
        Write-Verbose "Creating empty toc.yml [$($ResourceViewModel.parentToc_yml)]"
        New-Item $ResourceViewModel.parentToc_yml -ItemType File -Value "items: []" -Force | out-null
      }
      $ResourceViewModel.parentToc_yml_isRoot = (Get-Item -Path (split-Path $ResourceViewModel.parentToc_yml)).FullName -eq (Get-Item $docFxHelper.root.path).FullName
      Write-Verbose "  For resource: [$($ResourceViewModel.id)]"
      Write-Verbose "Parent toc.yml: [$($ResourceViewModel.parentToc_yml)]"
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

  $docfxhelper_json=$null
  if ($DocFxHelperFiles.docfxhelper_json)
  {
    $docfxhelper_json = $DocFxHelperFiles.docfxhelper_json
  }
  else
  {
    $docfxhelper_json = (join-path (split-Path $DocFxHelper.docFx.Path) -ChildPath "docfxhelper.json")
  }
  
  $DocFxHelper | ConvertTo-Json -Depth 4 | Set-Content $docfxhelper_json
}

function script:AddResource_ToParent
{
  param(
    [Parameter(Mandatory)][System.IO.FileInfo]$ParentTocYml,
    [Parameter(Mandatory)][bool]$ParentTocYmlIsRoot,
    [Parameter(Mandatory)][string]$ResourcePath,
    [Parameter(Mandatory)][string]$MenuDisplayName,
    [string]$MenuParentItemName,
    [int]$MenuPosition = -1,
    [string]$Homepage,
    [string]$MenuUid,
    [switch]$PassThru
  )

  Write-Information "Merging [$($MenuDisplayName)] into [$($ParentTocYml)]"
  Write-Debug "ParentTocYml       = [$($ParentTocYml)]"
  Write-Debug "ParentTocYmlIsRoot = [$($ParentTocYmlIsRoot)]"
  Write-Debug "ResourcePath       = [$($ResourcePath)]"
  Write-Debug "MenuDisplayName    = [$($MenuDisplayName)]"
  Write-Debug "MenuParentItemName = [$($MenuParentItemName)]"
  Write-Debug "MenuPosition       = [$($MenuPosition)]"
  Write-Debug "Homepage           = [$($Homepage)]"
  Write-Debug "MenuUid            = [$($MenuUid)]"
  Write-Debug "PassThru           = [$($PassThru)]"

  $SafeMenuDisplayName = [System.Web.HttpUtility]::UrlDecode("$MenuDisplayName".Replace("\(", "(").Replace("\)", ")").Replace("-", " "))
  $SafeMenuParentItemName = [System.Web.HttpUtility]::UrlDecode("$MenuParentItemName".Replace("\(", "(").Replace("\)", ")").Replace("-", " "))

  if (!(Test-Path -LiteralPath $ParentTocYml.FullName))
  {
    Write-Debug "Creating empty toc.yml $($ParentTocYml) for the parent"
    if (!(Test-Path -LiteralPath $ParentTocYml.Directory.FullName))
    {
      Write-Debug "Creating new folder $($ParentTocYml.Directory.FullName) for the toc.yml"
      New-Item $ParentTocYml.Directory.FullName -itemtype Directory -Force | out-null
    }

    [PSCustomObject][ordered]@{items = [System.Collections.ArrayList]::new() } | ConvertTo-Yaml -Depth 10 | Set-Content $ParentTocYml
  }

  Write-Debug "Loading content of [$($ParentTocYml.FullName)]"
  $toc = get-content -LiteralPath $ParentTocYml.FullName | ConvertFrom-Yaml
  <#

  [PSCustomObject][ordered]@{
    ParentTocYml           = $ParentTocYml.FullName
    ResourcePath           = $ResourcePath
    MenuDisplayName        = $MenuDisplayName
    SafeMenuDisplayName    = $SafeMenuDisplayName
    MenuParentItemName     = $MenuParentItemName
    SafeMenuParentItemName = $SafeMenuParentItemName
    MenuPosition           = $MenuPosition
    Homepage               = $Homepage
    MenuUid                = $MenuUid
  }
    
    $toc | ConvertTo-Yaml -depth 10
  #>  
  if ($null -eq $toc.items)
  {
    Write-Debug "toc doesn't have an items collection, creating a new one..."
    $toc = @{
      items = [System.Collections.ArrayList]::new()
    }
  }
  else
  {
    $items = [System.Collections.ArrayList]::new()
    foreach($ti in $toc.items)
    {
      [void]$items.Add($ti)
    }
    $toc.items = $items
  }
  
  <#
    $toc | ConvertTo-Yaml -depth 10
    $toc | ConvertTo-Yaml -depth 10 | set-content $ParentTocYml.FullName
  #>

  $parent = $null

  if ($SafeMenuParentItemName)
  {
    foreach($item in $toc.items)
    {
      if ($item.name -eq $SafeMenuParentItemName)
      {
        $parent = $item
      }
    }

    if ($null -eq $parent)
    {
      $parent = [ordered]@{
        name = $SafeMenuParentItemName
        items = [System.Collections.ArrayList]::new()
      }

      [void]$toc.items.Add($parent)
    }
  }
  else
  {
    $parent = $toc
  }

  <#
    $toc | ConvertTo-Yaml -depth 10
    $parent | ConvertTo-Yaml -depth 10
  #>

  if ($null -eq $parent.items)
  {
    $parent.items = [System.Collections.ArrayList]::new()
  }

  if ($parent.items -isnot [System.Collections.ArrayList])
  {
    $items = [System.Collections.ArrayList]::new()
    foreach($ti in $parent.items)
    {
      $items.Add($ti)
    }
    $parent.items = $items
  }

  Write-Debug "Looking for a [$($SafeMenuDisplayName)] in toc"
  $tocItem = $null
  foreach($ti in $parent.items)
  {
    if ($ti.name -eq $SafeMenuDisplayName)
    {
      $tocItem = $ti
    }
  }

  if ($null -eq $tocItem)
  {
    Write-Debug "[$($SafeMenuDisplayName)] not found, creating a new toc item"

    $tocItem = [ordered]@{
      name = $SafeMenuDisplayName
    }

    $position = $MenuPosition

    if ($position -lt 0)
    {
      $position = $parent.items.count
    }

    if ($position -gt $parent.items.count)
    {
      $position = $parent.items.count
    }

    $parent.items.Insert($position, $tocItem)

  }
  else
  {
    Write-Debug "a toc item already exists in the parent's toc.yml, no need to create a new one."
  }

  <#
    $toc | ConvertTo-Yaml -depth 10
    $parent | ConvertTo-Yaml -depth 10
    $tocItem  | ConvertTo-Yaml -depth 10
  #>
  
  Push-Location (Split-Path $ParentTocYml)
  $ResourceRelativePath = (Resolve-Path $ResourcePath -relative)
  Pop-location
  if ($ParentTocYmlIsRoot)
  {
    Write-Debug "Parent toc.yml is at the root, the href of the tocItem will be the folder/"
    $tocItem.href = join-path $ResourceRelativePath -childPath ""
  }
  else
  {
    Write-Debug "Parent toc.yml is at the root, the href of the tocItem will be the folder/toc.yml"
    $tocItem.href = join-path $ResourceRelativePath -childPath "toc.yml"
  }

  <#
    $toc | ConvertTo-Yaml -depth 10
    $parent | ConvertTo-Yaml -depth 10
    $tocItem  | ConvertTo-Yaml -depth 10
  #>

  if ($Homepage)
  {
    $tocItem.homepage = Join-Path $ResourceRelativePath -ChildPath $Homepage
  }
  elseif ($MenuUid)
  {
    $tocItem.uid = $MenuUid
  }
  else
  {
    Write-Warning "Missing homepage or Uid for [$($SafeMenuDisplayName)]"
  }

  <#
    $toc | ConvertTo-Yaml -depth 10
    $parent | ConvertTo-Yaml -depth 10
    $tocItem  | ConvertTo-Yaml -depth 10
  #>

  if ($null -eq $HomePage -and $tocItem.Keys.Contains("homepage"))
  {
    $tocItem.Remove("homepage")
  }

  if ($null -eq $MenuUid -and $tocItem.Keys.Contains("uid"))
  {
    $tocItem.Remove("uid")
  }

  <#
    $parentTocYml.Fullname
    $toc | ConvertTo-Yaml -depth 10
    $parent | ConvertTo-Yaml -depth 10
    $tocItem  | ConvertTo-Yaml -depth 10
  #>

  Write-Debug "Toc Item: `r`n$($tocItem | ConvertTo-Yaml -Depth 3)"
  
  $toc | ConvertTo-Yaml -depth 10 | Set-Content $ParentTocYml

  if ($Passthru)
  {
    return [PSCustomObject][ordered]@{
      ParentToc = ($toc | ConvertTo-Yaml -Depth 4)
      ParentToc_Yml = $ParentTocYml.FullName
      Parent_Directory = $ParentTocYml.Directory.FullName
      ResourcePath = "$($ResourcePath)"
      TocItem = ($tocItem | ConvertTo-Yaml)
      TocItem_Yml = (Join-Path $ResourcePath -ChildPath "toc.yml")
      TocItem_RelativePath = $ResourceRelativePath
      MenuParentItemName = $MenuParentItemName
      SafeMenuParentItemName = $SafeMenuParentItemName
      MenuDisplayName = $MenuDisplayName
      SafeMenuDisplayName = $SafeMenuDisplayName
      MenuPosition = $MenuPosition
      HomePage = $HomePage
      MenuUid  = $MenuUid
      ParentTocYmlIsRoot = $ParentTocYmlIsRoot
    }
  }
}


#endregion

#region DocFx

function script:DocFx_AddViewModel
{
  param(
    [Parameter(Mandatory)][System.IO.FileInfo]$Path,
    [Parameter(Mandatory)]$Meta)
  
  Write-Information "Adding resource to $($Path.Name)"

  Write-Verbose "Loading docFx.json [$($Path)]"
  $docfx = get-content -Path $Path | ConvertFrom-Json -AsHashtable
    
  <#
  
  $docfx.metadata = @()
  $docfx.build.content = @()
  $docfx.build.resource = @()
  
  #>
 
  if ($meta.build.Content)
  {
    $docfx.build.content += $meta.build.Content
  }

  if ($meta.build.Resource)
  {
    $docfx.build.resource += $meta.build.Resource
  }

  if ($meta.build.FileMetadata)
  {
    if ($null -eq $docfx.build.fileMetadata)
    {
      $docfx.build.fileMetadata = [ordered]@{}
    }

    foreach($key in $meta.build.FileMetadata.Keys)
    {
      $v = $meta.build.FileMetadata."$key"
      Write-Host "build.FileMetadata.$Key"
      if ($null -eq $docfx.build.fileMetadata."$Key")
      {
        $docfx.build.fileMetadata."$Key" = [ordered]@{}
      }
      $docfx.build.fileMetadata."$Key"."$($v.Pattern)" = $v.Value
    }
  }
  
  <#

  TODO: Missing:

  ALL:
    if ($ResourceViewModel.excludes)
    {
      $docfx_build_content_item.exclude = $ResourceViewModel.excludes
    }

  API:

    METADATA

    if ($ResourceViewModel.metadata)
    {
      $apiPathRelative = Resolve-Path $ResourceViewModel.metadata.srcFolder -Relative
  
      $docfx_metadata_content_item = [ordered]@{
        src                  = @(
          [ordered]@{
            files   = @("**.csproj", "**.vbproj")
            src     = $apiPathRelative
            exclude = @(
              "**.Test.csproj"
              , "**.Test.vbproj"
              , "**.Tests.csproj"
              , "**.Tests.vbproj"
              , "**.Testing.csproj"
              , "**.Testing.vbproj"
              , "**.UnitTests.csproj"
              , "**.UnitTests.vbproj"
            )
          }
        )
        comment              = "Api name: $($ResourceViewModel.id)"
        dest                 = $ResourceViewModel.metadata.apiYamlPath
        disableGitFeatures   = $false
        disableDefaultFilter = $false
        shouldSkipMarkup     = $true
        #properties = @{}   
      }
  
      $docfx.metadata += $docfx_metadata_content_item
    }

  #>

  $docfx | ConvertTo-Json -Depth 4 | Set-Content -Path $Path -Force
  Write-Host "Resource [$($Path.Name)] added to docfx"
}

# function script:DocFx_Get_TocDepth
# {
#   param($resourceTarget, $resourcePath, $tocPath)

#   $resourceDepth = 0
#   $resourceDepth += (("$resourceTarget".replace("\", "/").split("/") | where-object { $_ }).count)
#   $resourceDepth += ((get-item $tocPath).Directory.FullName.Split("\") | where-object { $_ }).Count
#   $resourceDepth -= ((get-item $resourcePath).FullName.Split("\") | where-object { $_ }).Count

#   return $resourceDepth
# }
function script:Util_MoveMdFile
{
  param(
    [Parameter(Mandatory)]$Source,
    [Parameter(Mandatory)]$Destination, 
    [Parameter(Mandatory)]$NewAbsolutePath)

  Write-Verbose "Moving md file"
  Write-Verbose "  source: [$Source]"
  Write-Verbose "  destination: [$Destination]"
  Write-Verbose "  new absolute path: [$Destination]"

  $mdFile = Move-Item $Source -Destination $Destination -PassThru

  return $mdFile
}

function script:DocFx_FixTocItemsThatShouldPointToTheirFolderInstead
{
  param([Parameter(Mandatory)][System.IO.DirectoryInfo]$Path)

  Write-Information "Fixing toc items with an href pointing to an .md file when in fact it should point to their subfolder"
  
  $tableOfContents = get-childitem -path $Path.FullName -filter "toc.yml" -Recurse -Force

  foreach ($tableOfContent_yml in $tableOfContents)
  {
    <#
      $tableOfContent_yml = $tableOfContents | select-object -first 1

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

    $tocItems = Get-Content -LiteralPath $tableOfContent_yml.FullName | ConvertFrom-yaml

    push-location (split-Path $tableOfContent_yml)

    $tocItemsQueue = [System.Collections.Queue]::new()

    $tocItemsQueue.Enqueue($tocItems)

    while ($tocItemsQueue.count -gt 0)
    {
      $tocItem = $tocItemsQueue.Dequeue()

      foreach ($childTocItem in $tocItem.items)
      {        
        $tocItemsQueue.Enqueue($childTocItem)
      }

      Write-Debug "tocItem: $($tocItem | ConvertTo-Json -Compress -WarningAction SilentlyContinue)"

      if ($tocItem.href)
      {
        
        if (Test-Path $tocItem.href)
        {
          $tocItemHrefItem = get-item $tocItem.href
          
          if ($tocItemHrefItem.PSIsContainer)
          {
            Write-Debug "href $($tocItem.href) points to a folder.  Nothing to do (Point #2 href to a folder: nothing to do)"
          }
          else
          {
            if ($tocItem.uid)
            {
              Write-Debug "href $($tocItem.href) points to a file, and tocItem has a uid [$($tocitem.uid)].  Nothing to do"
            }
            elseif ($tocItem.homepage)
            {
              Write-Debug "href $($tocItem.href) points to a file, and tocItem has a homepage [$($tocitem.homepage)].  Nothing to do"
            }
            elseif ($tocItemHrefItem.name -eq "toc.yml")
            {
              Write-Debug "href $($tocItem.href) points to a toc.yml.  Nothing to do (Point #3 href to a toc.yml in a subfolder: nothing to do)"
            }
            else
            {
              if ((Test-Path $tocItemHrefItem) -and $tocItemHrefItem.Directory.FullName -eq $tableOfContent_yml.Directory.FullName)
              {
                Write-Debug "href $($tocItem.href) points to a file in the current folder."
                if (Test-Path (join-Path $tocItemHrefItem.Basename -childPath "toc.yml"))
                {
                  Write-Information "href $($tocItem.href) points to a file in the current folder, and a toc.yml found in a sub folder with the file's base name.  Update required"
                  Write-Debug "TocItem Before:`r`n$($tocItem | ConvertTo-yaml -depth 3)"
                  $tocItem.homepage = $tocItem.href
                  $tocItem.href = "$(split-Path $tocItem.href -LeafBase)/toc.yml"  
                  Write-Debug "TocItem After:`r`n$($tocItem | ConvertTo-yaml -depth 3)"
                }
                else
                {
                  Write-Debug "href $($tocItem.href) points to a file in the current folder, but a toc.yml wasn't found a sub folder with the file's base name.  Nothing to do"
                }
              }
              else
              {
                Write-Debug "href $($tocItem.href) points to a file in a sub folder.  Nothing to do"
              }
            }
          }
        }
        else
        {
          Write-Warning "File $($tocItem.href), referenced from toc, not found."
        }
      }
      else
      {
        Write-Debug "no href.  Nothing to do (point #1)"
      }
    }

    $tocItems | ConvertTo-yaml -Depth 10 | Set-Content $tableOfContent_yml

    pop-location

  }

}

function script:DocFx_FixRootTocItemsToReferenceTOCs
{
  param([Parameter(Mandatory)][System.IO.DirectoryInfo]$Path)

  Write-Information "Fixing root Toc items so that the Navigation Bar uses [Reference TOCs.](https://dotnet.github.io/docfx/docs/table-of-contents.html#navigation-bar)"
  
  $tableOfContent_yml = join-path -path $Path.FullName -ChildPath "toc.yml"

  $tocItems = Get-Content -LiteralPath $tableOfContent_yml | ConvertFrom-yaml

  $tocItemsQueue = [System.Collections.Queue]::new()

  $tocItemsQueue.Enqueue($tocItems)

  while ($tocItemsQueue.count -gt 0)
  {
    $tocItem = $tocItemsQueue.Dequeue()

    foreach ($childTocItem in $tocItem.items)
    {        
      $tocItemsQueue.Enqueue($childTocItem)
    }

    Write-Debug "tocItem: $($tocItem | ConvertTo-Json -Compress -WarningAction SilentlyContinue)"

    if ($tocItem.href -and $tocItem.href.replace("\","/").endsWith("/toc.yml"))
    {
      $tocItem.href = $tocItem.href.substring(0, $tocItem.href.Length - 7)
    }
  }

  $tocItems | ConvertTo-yaml -Depth 10 | Set-Content $tableOfContent_yml

}
function script:DocFx_GetTocItem
{
  param($Items, $Name, [switch]$Recurse)

  Write-Verbose "Trying to find [$Name] in a toc of $($Items.count) items.  Recursive ? $($Recurse)"
  foreach ($item in $Items)
  {
    if ($item.name -eq $Name)
    {
      Write-Verbose "Found $Name"
      return $item
    }
  }

  if ($Recurse)
  {
    foreach ($item in $Items)
    {
      $childFound = DocFx_GetTocItem -Items $item.Items -Name $Name -Recurse $Recurse
      if ($childFound)
      {
        return $childFound
      }
    }
  }

  return $null

}
#endregion

#region AdoWikis

function script:AdoWiki_GetWikiMarkdowns
{
  [cmdletbinding()]
  param([Parameter(ValueFromPipeline)]$Folder)

  process
  {
    foreach($f in $Folder)
    {
      return Get-ChildItem -path $f -File -Filter "*.md" -Force
    }  
  }
}

function script:AdoWiki_GetDocFxSafeItemMetadata
{
  param([System.IO.FileInfo]$mdFile)

  Write-Debug "[AdoWiki_GetDocFxSafeItemMetadata] $($mdFile.FullName)"
  $pageUri = [Uri]::new($baseUri, (Resolve-Path -LiteralPath $mdFile.FullName -Relative))
  $dotOrderUri = [Uri]::new($baseUri, (Join-Path (Resolve-Path -LiteralPath $mdFile.FullName -Relative | split-path) -ChildPath ".order"))
  $orderItemUri = [Uri]::new($baseUri, (Join-Path (Resolve-Path -LiteralPath $mdFile.FullName -Relative | split-path) -ChildPath $mdFile.BaseName))
  $folder = (Get-ChildItem -LiteralPath $mdFile.Directory.FullName -Directory -Force | where-object { $_.Name -eq $mdFile.BaseName })

  [ordered]@{
    File              = $mdFile                                                                                                       # c:\agent\_work\1\s\foo.md   c:\agent\_work\1\s\Help\A-%2D-b%2Dc(d)-(e)-%2D-(f)-%2D-(-h-).md
    FileName          = [System.Web.HttpUtility]::UrlDecode($mdFile.Name)                                                             # foo.md                      A---b-c(d)-(e)---(f)---(-h-).md
    FileAbsolute      = [System.Web.HttpUtility]::UrlDecode($mdFile.FullName)                                                         # c:\agent\_work\1\s\foo.md   c:\agent\_work\1\s\Help\A---b-c(d)-(e)---(f)---(-h-).md
    FileRelative      = [System.Web.HttpUtility]::UrlDecode((Resolve-Path -LiteralPath $mdFile.FullName -Relative))                   # .\foo.md                    .\Help\A---b-c(d)-(e)---(f)---(-h-).md
    FileRelativeUri   = [System.Web.HttpUtility]::UrlDecode((Resolve-Path -LiteralPath $mdFile.FullName -Relative).replace("\", "/")) # ./foo.md                    ./Help/A---b-c(d)-(e)---(f)---(-h-).md
    LinkAbsolute      = $pageUri.AbsolutePath                                                                                         # /foo.md                     /Help/A---b-c(d)-(e)---(f)---(-h-).md
    LinkMarkdown      = $pageUri.Segments[-1]                                                                                         # foo.md                      A---b-c(d)-(e)---(f)---(-h-).md
    LinkDisplay       = [System.Web.HttpUtility]::UrlDecode($mdfile.BaseName.Replace("\(", "(").Replace("\)", ")").Replace("-", " ")) # foo                         A - b-c(d) (e) - (f) - ( h )
    DotOrderAbsolute  = $dotOrderUri.AbsolutePath
    OrderItemAbsolute = $orderItemUri.AbsolutePath                                                                                    # /foo                        /Help/A---b-c(d)-(e)---(f)---(-h-)
    FolderName        = [System.Web.HttpUtility]::UrlDecode($folder.Name)                                                             # foo (if folder exists)      A---b-c(d)-(e)---(f)---(-h-) (if folder exists)
  }
  
}

function script:AdoWiki_GetDocfxItemMetadata
{
  param([System.IO.FileInfo]$mdFile)

  Write-Debug "[AdoWiki_GetDocfxItemMetadata] $($mdFile.FullName)"
  $workingDirectory = (Get-Location)

  $item = [ordered]@{
    Guid = (New-Guid).Guid
    AdoWiki   = [ordered]@{
      File             = $mdFile                 # A-%2D-b%2Dc(d)-(e)-%2D-(f)-%2D-(-h-).md [FileInfo]
      FileName         = $mdFile.Name            # A-%2D-b%2Dc(d)-(e)-%2D-(f)-%2D-(-h-).md
      FileAbsolute     = $mdFile.FullName        # c:\x\y\A-%2D-b%2Dc(d)-(e)-%2D-(f)-%2D-(-h-).md
      FileRelative     = $null                   # .\A-%2D-b%2Dc(d)-(e)-%2D-(f)-%2D-(-h-).md
      FileRelativeUri  = $null                   # ./A-%2D-b%2Dc(d)-(e)-%2D-(f)-%2D-(-h-).md
      LinkOrderItem    = $mdFile.BaseName        # A-%2D-b%2Dc(d)-(e)-%2D-(f)-%2D-(-h-)      
      LinkAbsolute     = $null                   # /A-%2D-b%2Dc(d)-(e)-%2D-(f)-%2D-(-h-)
      LinkMarkdown     = $null                   # /A-%2D-b%2Dc\(d\)-\(e\)-%2D-\(f\)-%2D-\(-h-\)
      LinkDisplay      = $null                   # A - b-c(d) (e) - (f) - ( h )
      DotOrderRelative = $null                   # .order
      Folder           = $null
      FolderName       = $null                   # A-%2D-b%2Dc(d)-(e)-%2D-(f)-%2D-(-h-)
      WikiAbsolutePath = $null                   # /A - b-c(d) (e) - (f) - ( h )
    }
    DocFxSafe = [ordered]@{
    }
  }
  $item.AdoWiki.FileRelative = ".$($item.AdoWiki.FileAbsolute.Substring($workingDirectory.Path.Length))"
  $item.AdoWiki.FileRelativeUri = ".$($item.AdoWiki.FileAbsolute.Substring($workingDirectory.Path.Length))".Replace("$([IO.Path]::DirectorySeparatorChar)", "/")
  $item.AdoWiki.LinkAbsolute = $item.AdoWiki.FileRelativeUri.Substring(1).Replace(".md", "")
  $item.AdoWiki.LinkAbsoluteMd = $item.AdoWiki.FileRelativeUri.Substring(1)
  $item.AdoWiki.LinkMarkdown = $item.AdoWiki.LinkAbsolute.Replace("\(", "(").Replace("\)", ")")
  $item.AdoWiki.LinkDisplay = [System.Web.HttpUtility]::UrlDecode($item.AdoWiki.LinkOrderItem.Replace("\(", "(").Replace("\)", ")").Replace("-", " "))
  $item.AdoWiki.Folder = (Get-ChildItem -Path $mdFile.Directory -Directory -Force | where-object { $_.Name -eq $item.AdoWiki.LinkOrderItem })
  if ($item.AdoWiki.Folder)
  {
    $item.AdoWiki.FolderName = $item.AdoWiki.Folder.Name
  }
  $item.AdoWiki.WikiAbsolutePath = [System.Web.HttpUtility]::UrlDecode($item.AdoWiki.LinkMarkdown.Replace("-", " "))

  $dotOrder = Join-Path $mdFile.Directory.FullName -childpath ".order"
  if (Test-Path $dotOrder)
  {
    $item.AdoWiki.DotOrderRelative = Resolve-Path $dotOrder -relative
  }

  $item.DocFxSafe = AdoWiki_GetDocFxSafeItemMetadata -mdFile $mdFile
  $item.RenameRequired = $item.DocFxSafe.FileName -ne $item.AdoWiki.FileName        # TODO: Confirm still needed or not.  For: filter files that are part of the rename processes
  $item.FileIsRenamed  = $null                                                      # TODO: Confirm still needed or not.  For: filtering of files that have been part of a renaming, moving (file and/or folder)
  $item.File = $mdFile                                                              # [SystemInfo] Used as DocFxHelper unique identifier, should be updated when part of file/folder move/rename

  return [PSCustomObject]$item
}

function script:AdoWiki_GetAdoWikiMetadata
{
  [cmdletbinding()]  
  param([Parameter(ValueFromPipeline)]$InputObject)

  begin{}
  process{

    Write-Debug "[AdoWiki_GetAdoWikiMetadata] [$($InputObject.Fullname)]"
    
    foreach ($mdFile in $InputObject)
    {
      AdoWiki_GetDocfxItemMetadata -mdFile $mdFile
    }
  
  }
  end{}

}

function script:AdoWiki_GetAdoWikiFolders
{
  param($Path, [string[]]$Exclude)

  $workingDirectory = (Get-Location)
  $folders = [System.Collections.ArrayList]::new()

  $folders.Add((Get-Item $Path)) | Out-null

  $subFolders = Get-ChildItem -path $Path -Recurse -Directory -Force

  foreach ($subFolder in $subFolders)
  {
    <#
      $subFolder = $subFolders | select-object -first 1
    #>
    $relative = $subFolder.FullName.Substring($workingDirectory.Path.Length)
    
    $segments = $relative.Split("$([IO.Path]::DirectorySeparatorChar)", [System.StringSplitOptions]::RemoveEmptyEntries)

    if (!$segments.Where({ $_ -in $Exclude }))
    {
      $folders.Add($subFolder) | out-null
    }
  }
  
  return $folders
}

function script:AdoWiki_ConvertFromWikiOrderFOOFOO
{
  param([System.IO.FileInfo]$Order)

  $workingDirectory = (Get-Location)
  
  $o = [ordered]@{
    orderFile      = $Order
    content        = @() + (Get-Content -LiteralPath $Order.FullName)
    folderAbsolute = $Order.Directory.FullName
    folderName     = $Order.Directory.Name
    folderRelative = $null
    folderUri      = $null
    depth          = $null
    orderItems     = [System.Collections.ArrayList]::new()
  }
  $o.folderRelative = $o.folderAbsolute.Substring($workingDirectory.Path.Length)
  $o.folderUri = [Uri]::new($baseUri, $o.folderRelative.replace("$([IO.Path]::DirectorySeparatorChar)", "/"))
  $o.depth = $o.folderRelative.Split("$([IO.Path]::DirectorySeparatorChar)").Count - 1
      
  foreach ($orderItem in $o.content)
  {
    <#
      $orderItems

      $orderItem = $o.content | select-object -first 1
      $orderItem = $o.content | select-object -first 1 -skip 1
      $orderItem = $o.content | select-object -first 1 -skip 2
      $orderItem = $o.content | select-object -last 1

      $orderItem = "Foo"
      $orderItem = "Foo-Bar"
      $orderItem = "Foo-Bar-(Snafu)"
    #>

    if ("$orderItem" -ne "")
    {
    
      Write-Debug "OrderItem: $orderItem"
      
      $oi = [ordered]@{
        orderItem           = $orderItem
        display             = [System.Web.HttpUtility]::UrlDecode($orderItem.Replace("-", " "))
        orderItemMd         = "$($orderItem).md"
      }

      $o.orderItems.Add([PSCustomObject]$oi) | Out-Null
    }
  }

  return [PSCustomObject]$o

}

<#
  .SYNOPSIS
  Converts ADO Wiki .Order items
#>
function ConvertFrom-AdoWikiOrderItem
{
  [CmdletBinding()]
  param(
    [System.IO.FileInfo]$Path
  )

  begin {
    $ret = [System.Collections.ArrayList]::new()
  }

  process {    
    
    $OrderItems = Get-Content $Path

    foreach($orderItem in $OrderItems)
    {
      <#
        $orderItem = $OrderItems | select-object -first 1
        $orderItem
      #>

      $item = [ordered]@{
        orderItem = $orderItem
        orderItem_folder_path = Join-Path $Path.Directory.FullName -ChildPath "$($orderItem)/"
        orderItem_mdFile_path = Join-Path $Path.Directory.FullName -ChildPath "$($orderItem).md"
      }

      [void]$ret.Add([PSCustomObject]$item)
    }
  }

  end {
    return $ret.ToArray()  
  }
}

function script:ConvertTo-DocFxTocItem
{
  [CmdletBinding()]
  param(
    [Parameter(Mandatory, ValueFromPipeline)][PSCustomObject[]]$Items,
    [Parameter(Mandatory)]$Metadata,
    [Parameter(Mandatory)][Uri]$RelativeDotOrderUri
  )

  begin{
    $ret = [System.Collections.ArrayList]::new()
  }

  process{

    foreach($item in $Items)
    {
      <#
        $item = $Items | select-object -first 1
        $item
      #>

      $toc_item = [ordered]@{
        name = [System.Web.HttpUtility]::UrlDecode("$($item.orderItem)".Replace("\(", "(").Replace("\)", ")").Replace("-", " "))
        href = "$((split-path $item.orderItem_mdFile_path -leaf))"
      }

      [void]$ret.Add($toc_item)
    }

  }

  end{
    return $ret.ToArray()
  }

}

function script:Join-DocFxTocItems
{
  param(
    [Parameter(Mandatory, Position=0)]$tocItems, 
    [Parameter(Mandatory, Position=1)]$otherTocItems
  )

  $ret = [System.Collections.ArrayList]::new()
 
  if ($tocItems)
  {
    $ret.AddRange($tocItems)
  }

  foreach($otherTocItem in $otherTocItems)
  {
    if ($ret | where-object {$_.name -eq $otherTocItem.name})
    {
      Write-Warning "Duplicate toc item name found: $($otherTocItem.name).  href=[$($otherTocItem.href)] Last one wins."
      $dup = $ret | where-object {$_.name -eq $otherTocItem.name} | select-object -first 1
      $dup_index = $ret.IndexOf($dup)      
      $ret.RemoveAt($dup_index)
      $ret.Insert($dup_index, $otherTocItem)
    }
    else
    {
      [void]$ret.Add($otherTocItem)
    }
  }
  
  return $ret.ToArray()
}

function script:Set-DocFxToc
{
  param($tocItems)
  {

  }
}

# function script:AdoWiki_ConvertOrderItemsTo_DocFxToc
# {
#   <#
#     SYNOPSIS
#     Converts an imported .order orderItems to DocFx toc.yml

#     DESCRIPTION 

#     The .order orderItems are of format

#       orderItem           = $orderItem
#       display             = [System.Web.HttpUtility]::UrlDecode($orderItem.Replace("-", " "))
#       orderItemMd         = "$($orderItem).md"

#   #>
#   param(
#     [Parameter(Mandatory)][String]$tocYmlPath,
#     [Parameter(Mandatory)][Uri]$TocUri,
#     $OrderItems
#   )

#   Write-Debug "[AdoWiki_ConvertOrderItemsTo_DocFxToc] Number of toc items: $($OrderItems.Count)"
  
#   $tocItems = [System.Collections.ArrayList]::new()
  
#   foreach ($orderItem in $OrderItems)
#   {
#     <#
#       $orderItem = $OrderItems | select-object -first 1
#       $orderItem = $OrderItems | select-object -first 1 -skip 3
#     #>

#     Write-Debug "OrderItem: $($orderItem.display)"

#     $tocItem = [ordered]@{
#       name = $orderItem.display
#       href = $orderItem.orderItemMd
#     }

#     <#
#       Resolve-TocItem 
#       $tocYmlPath = $tocYmlPath 
#       $TocUri = $TocUri 
#       $TocItem = $tocItem
#     #>

#     $resolved = Resolve-TocItem -tocYmlPath $tocYmlPath -TocUri $TocUri -TocItem $tocItem

#     if ($null -eq $resolved.toc_yml_path -and $null -eq $resolved.file_md_subFolder_path)
#     {
#       $tocItem.href = $resolved.file_md_path
#     }
#     else
#     {
#       if ($null -eq $resolved.toc_yml_path)
#       {
#         $tocItem.href = "$($resolved.file_md_subFolder_path)\"
#       }
#       else
#       {
#         $tocItem.href = $resolved.toc_yml_path
#       }

#       if ($resolved.file_md_path)
#       {
#         $tocItem.homepage = $resolved.file_md_path
#       }
#     }
#     Write-Debug "$($orderItem.display) becomes $($tocItem | convertto-json -compress)"

#     $tocItems.Add([PSCustomObject]$tocItem) | out-null

#   }

#   return @{
#     items = $tocItems
#   }

# }


function script:AdoWiki_Get_MdSections
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
    for ($i = 0; $i -lt $codeSections.count / 2; $i++)
    {
      $codeBlock = $i * 2
      if ($codeSections[$codeBlock].LineNumber - 1 -gt $lineStart)
      {
        $sections.Add([PSCustomObject]@{type = "Conceptual"; content = $content[$lineStart..($codeSections[$codeBlock].LineNumber - 2)] }) | out-null
      }
      $sections.Add([PSCustomObject]@{type = "Code"; content = $content[($codeSections[$codeBlock].LineNumber - 1)..($codeSections[$codeBlock + 1].LineNumber - 1)] }) | out-null
      $lineStart = $codeSections[$codeBlock + 1].LineNumber
    }
    if ($lineStart -lt $content.count)
    {
      $sections.Add([PSCustomObject]@{type = "Conceptual"; content = $content[$lineStart..($content.count - 1)] }) | out-null
    }
  }
  else 
  {
    $sections.Add([PSCustomObject]@{type = "Conceptual"; content = $content }) | out-null
  }

  return $sections

}

function script:AdoWiki_Update_Links
{
  param($Content, $ReplaceCode)

  $findRegex = "(?<include>\[!include)?\[(?'display'(?:[^\[\]]|(?<Open>\[)|(?<Content-Open>\]))+(?(Open)(?!)))\]\((?'link'(?:[^\(\)]|(?<Open>\()|(?<Content-Open>\)))+(?(Open)(?!)))\)"

  if ("$content" -ne "" -and $content -match $findRegex)
  {
    $sections = AdoWiki_Get_MdSections -Content $content
    
    $conceptualSectionNumber = 0
  
    foreach ($conceptual in $sections | where-object type -eq "Conceptual")
    {
      <#
        $conceptual = $sections | where-object type -eq "Conceptual" | select-object -first 1
      #>
      $conceptualSectionNumber++
      if ($conceptual.content -match $findRegex)
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

function script:AdoWiki_FixAdoWikiEscapes
{
  param($Content)

  $r = {
    if ($_.Groups["include"].Value)    
    {
      return $_.Groups[0]
    }

    $in = @{
      display = $_.Groups["display"].Value
      link    = $_.Groups["link"].Value  
    }
    <#
    $in = @{}
      $in.display = "This is the display"
      $in.link = "https://user:password@www.contoso.com:80/Home/Index.htm?q1=v1&q2=v2#FragmentName"
      $in.link = "xfer:Home_Index#FragmentName"
      $in.link = "/Home \(escaped folder\)/Index.md?q1=v1&q2=v2#FragmentName"
      $in.link = "/Home/Index\(escaped folder\).md?q1=v1&q2=v2#FragmentName"
    #>
    $out = @{
      display = $in.display
      link    = $in.link
    }
    if ($out.link.Contains("\(") -or $out.link.Contains("\)"))
    {
      Write-Debug "link [$($out.link)] contains ado wiki \(, \) escapes, removing escapes"
      $out.link = $out.link.replace("\(", "(").replace("\)", ")")
    }

    $ret = "[$($out.display)]($($out.link))"
    return $ret

  }
  
  Write-Verbose "[AdoWiki_FixAdoWikiEscapes] Fix Ado Wiki Escapes"
  $UpdatedContent = AdoWiki_Update_Links -Content $Content -ReplaceCode $r

  return $UpdatedContent
}

function script:AdoWiki_UpdateLinksToMdLinks
{
  param($Content, $AllMdFiles, $MdFileMetadata)

  $r = {

    if ($_.Groups["include"].Value)    
    {
      return $_.Groups[0]
    }

    $in = @{
      display = $_.Groups["display"].Value
      link    = $_.Groups["link"].Value
    }
    
    <#
    $in = @{}
      $in.display = "This is the display"
      # Ignored
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
    $out = @{
      display = $in.display
      link    = $in.link
    }

    if ($out.link.StartsWith("#tab/"))
    {
      Write-Debug "    link ($($out.link)) is a DocFx tab header, leaving as is"
    }
    else
    {
      $testUri = [Uri]::new($baseUri, $out.link)

      if ($testUri.Host -ne $baseUri.Host)
      {
        Write-Debug "    ignored ($($out.link)) - is external"
      }
      else
      {
        if ($testUri.Segments -contains ".attachments/")
        {
          Write-Debug "    ignored ($($out.link)) - links to an image"
        }
        else
        {
          if ($testUri.LocalPath.EndsWith(".md"))
          {
            Write-Debug "    ignored ($($out.link)) already points to a .md file"
          }
          elseif ($AllMdFiles -contains $testUri.AbsolutePath)
          {
            Write-Debug "    link ($($out.link)), found an .md file, appending .md"
            $out.link = "$($testUri.AbsolutePath).md$($testUri.Query)$($testUri.Fragment)"
          }
          else
          {          
            $PageUri = [Uri]::new($baseUri, $MdFileMetadata.DocFxSafe.LinkAbsolute)
            $pageRelativeLink = [Uri]::new($pageUri, $out.link)
            
            if ($AllMdFiles -contains $pageRelativeLink.AbsolutePath -or $AllMdFiles -contains "$($pageRelativeLink.AbsolutePath).md")
            {
              Write-Debug "    link ($($out.link)) is relative to an existing .md, using [$($pageRelativeLink.AbsolutePath).md]"
              $out.link = "$($pageRelativeLink.AbsolutePath).md$($pageRelativeLink.Query)$($pageRelativeLink.Fragment)"
            }
            else
            {
              Write-Debug "    link ($($out.link)) doesn't seem to correspond to an existing .md file, leaving as is"
            }
          }
        }
      }
    }
  
    $ret = "[$($out.display)]($($out.link))"
    return $ret

  }
    
  Write-Verbose "[AdoWiki_UpdateLinksToMdLinks] Update Ado Links to their MD file names"
  $updatedContent = AdoWiki_Update_Links -Content $content -ReplaceCode $r

  return $updatedContent
 
}

function script:AdoWiki_UpdateRenamedLinks
{
  param($Content, $Map)

  $r = {
    if ($_.Groups["include"].Value)    
    {
      return $_.Groups[0]
    }

    $in = @{
      display = $_.Groups["display"].Value
      link    = $_.Groups["link"].Value
    }
    <#
    $in = @{}
      $in.display = "This is the display"      
      $in.link = "/With Space/With Space.md?q1=v1&q2=v2#FragmentName"
      $in.link = "/With Space/With Space?q1=v1&q2=v2#FragmentName"
      $in.display = Read-Host "Display"
      $in.link = Read-Host "Link"
    #>
    $out = @{
      display = $in.display
      link    = $in.link
    }

    if ($out.link.StartsWith("#tab/"))
    {
      Write-Debug "ignored $($out.link) - is DocFx Tab header"
    }
    else
    {
      $testUri = [Uri]::new($baseUri, $out.link)

      if ($testUri.Host -ne $baseUri.Host)
      {
        Write-Debug "ignored $($out.link) - is external"
      }
      else
      {
        if ($testUri.Segments -contains ".attachments/")
        {
          Write-Debug "ignored $($out.link) - links to an image"
        }
        elseif ($testUri.LocalPath -eq "/" -and "$($testUri.Anchor)" -ne "")
        {
          Write-Debug "ignored $($out.link) - links to anchor"
        }
        else
        {
          $matchedMap = $Map | where-object { $_.from.LinkAbsoluteMd -eq $testUri.AbsolutePath -or $_.from.LinkAbsoluteMd -eq "$($testUri.AbsolutePath).md" }
          if ($matchedMap)
          {
            Write-Debug "Found a link to a renamed map item From: [$($matchedMap.from.LinkAbsoluteMd)] To: [$($matchedMap.to.LinkAbsoluteMd)].  Updating link"
            $newUri = $matchedMap.to.LinkAbsoluteMd

            $out.link = "$($newUri)$($testUri.Query)$($testUri.Fragment)"
          }
          else
          {
            Write-Debug "Leaving $($out.link) as is"
          }
        }
      }
    }

    $ret = "[$($out.display)]($($out.link))"
    return $ret
  }
  
  Write-Verbose "[AdoWiki_UpdateRenamedLinks] Update links that have been renamed"
  $updatedContent = AdoWiki_Update_Links -Content $content -ReplaceCode $r

  return $updatedContent
}

function script:AdoWiki_UpdateLinksToAbsoluteLinks
{
  param($Content, [Uri]$PageUri)

  $r = {

    # if ($_.Groups["include"].Value)    
    # {
    #   return $_.Groups[0]
    # }

    $in = @{
      display = $_.Groups["display"].Value
      link    = $_.Groups["link"].Value  
      include = $_.Groups["include"].Value
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
      $in.link = "#tab/foo" --> special link anchor syntax to DocFx Tabs
      $in.display = Read-Host "Display"
      $in.link = Read-Host "Link"
    #>
    $out = @{
      display = $in.display
      link    = $in.link
    }

    Write-Debug "[$($out.display)]($($out.link))"

    if ($out.link.startsWith("#tab/"))
    {
      Write-Debug "DocFx Tab Header link #tab/foo - leaving it as is"
    }
    else
    {
      $linkUri = [Uri]::new($PageUri, $out.link)
      if ($linkUri.AbsoluteUri -ne $out.link)
      {
        $out.link = "$($linkUri.PathAndQuery)$($linkUri.Fragment)"
        Write-Debug "Converting to absolute: [$($out.link)]"
      }
      else
      {
        Write-Debug "Leaving link [$($out.link)] as is"
      }
    }

    $ret = "$($in.include)[$($out.display)]($($out.link))"
    return $ret

  }
    
  Write-Verbose "[AdoWiki_UpdateLinksToAbsoluteLinks] Update links in [$($PageUri.AbsolutePath)] from relative to absolute"
  $UpdatedContent = AdoWiki_Update_Links -Content $content -ReplaceCode $r

  return $UpdatedContent
 
}

function script:AdoWiki_UpdateLinksToRelativeLinks
{
  param($Content, [Uri]$PageUri)

  $r = {

    # if ($_.Groups["include"].Value)    
    # {
    #   return $_.Groups[0]
    # }

    $in = @{
      display = $_.Groups["display"].Value
      link    = $_.Groups["link"].Value  
      include = $_.Groups["include"].Value
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
      $in.link = "#tab/foo" --> special link anchor syntax to DocFx Tabs
      $in.display = Read-Host "Display"
      $in.link = Read-Host "Link"
    #>
    $out = @{
      display = $in.display
      link    = $in.link
    }

    Write-Debug $in.link
    if ($out.link.StartsWith("/"))
    {
      
      $linkUri = [Uri]::new($baseUri, $out.link)
      
      $relativeLink = $PageUri.MakeRelative($linkUri)
      
      if ("" -eq $relativeLink)
      {
        Write-Debug "Link [$($in.link)] actually points back to this page..."
        $out.link = $pageUri.Segments[-1]
      }
      else
      {
        Write-Debug "Link [$($in.link)] starts with a /.  For page at [$($pageUri.AbsolutePath)] the relative link is [$($relativeLink)]"
        $out.link = $relativeLink
      }
    }
    else
    {
      Write-Debug "Link [$($in.link)] is not absolute, leaving as is"
    }

    $ret = "$($in.include)[$($out.display)]($($out.link))"
    return $ret

  }
    
  Write-Verbose "[AdoWiki_UpdateLinksToRelativeLinks] Update links from absolute to relative [$($PageUri.AbsolutePath)]"
  $UpdatedContent = AdoWiki_Update_Links -Content $content -ReplaceCode $r

  return $UpdatedContent
 
}

function script:AdoWiki_UpdateMermaidCodeDelimiter
{
  param($mdfile)

  Write-Verbose "[AdoWiki_UpdateMermaidCodeDelimiter] Update MerMaid Code Delimiter for $($mdfile)"
  
  $content = get-content -LiteralPath $mdfile.FullName -raw
  if ("" -ne "$content" -and ("$content".Contains(":::mermaid") -or "$content".Contains("::: mermaid")))
  {
    Write-Verbose "Found Mermaid Code in $($mdfile.FullName). Fixing..."
    $content = $content.replace(":::mermaid", "``````mermaid")
    $content = $content.replace("::: mermaid", "``````mermaid")
    $content = $content.replace(":::", "``````")
    set-content -LiteralPath $mdfile.FullName -value $content
  }
}

function Resolve-TocItem
{
  <#
    .SYNOPSIS
    Resolves a TocItem hash to their actual files/folders and returns hash with toc_yml_Path, file_md_Path, file_md_SubFolder_Path

    .DESCRIPTION
    Given a site at c:\azagent\_work\1\s\wiki.xyz
    And an toc.yml at c:\azagent\_work\1\s\wiki.xyz\someSub\foo\toc.yml
    Each toc orderItem will have a 
      /x  => c:\azagent\_work\1\s\wiki.xyz\x
      x   => c:\azagent\_work\1\s\wiki.xyz/someSub/foo/x
      x/  => c:\azagent\_work\1\s\wiki.xyz/someSub/foo/x


  #>
  param(
    [Parameter(Mandatory)][String]$tocYmlPath,
    [Parameter(Mandatory)][Uri]$TocUri,
    [Parameter(Mandatory)][HashTable]$TocItem
  )

  <#
    href and homepage:
    $TocItem = @{name="Scenario 01 - [Bar/] [Foo.md]";            href="Bar/";         homepage="Foo.md"}
    $TocItem = @{name="Scenario 02 - [Bar/] [Bar/Foo.md]";        href="Bar/";         homepage="Bar/Foo.md"}
    $TocItem = @{name="Scenario 03 - [Bar/toc.yml] [Foo.md]";     href="Bar/toc.yml";  homepage="Foo.md"}
    $TocItem = @{name="Scenario 04 - [Bar/toc.yml] [Bar/Foo.md]"; href="Bar/toc.yml";  homepage="Bar/Foo.md"}

    href only:
    $TocItem = @{name="Scenario 05 - [Foo.md] Foo/ does not exist";               href="Foo.md";}
    $TocItem = @{name="Scenario 06 - [Foo.md] Foo/ exists, but not Foo/toc.yml";  href="Foo.md";}
    $TocItem = @{name="Scenario 07 - [Foo.md] Foo/toc.yml exists";                href="Foo.md";}
    $TocItem = @{name="Scenario 08 - [Bar/] Bar.md does not exist"; href="Bar/";}
    $TocItem = @{name="Scenario 09 - [Foo/] Foo.md exists";         href="Foo/";}
    $TocItem = @{name="Scenario 10 - [Bar/toc.yml]";  href="Foo/toc.yml";}
    $TocItem = @{name="Scenario 11 - [Bar/Foo.md]";   href="Bar/Foo.md";}}

  #>

  $tocYmlFolder = split-path $tocYmlPath

  $x = [PSCustomObject][ordered]@{
    href = $TocItem.href
    href_uri = $null
    href_relative_uri = $null
    href_path = $null
    homepage = $TocItem.homepage
    homepage_uri = $null
    homepage_relative_uri = $null
    homepage_path = $null
    menuUid = $TocItem.MenuUid
    toc_yml_Item = $null
    file_md_Item = $null
    file_md_SubFolder = $null
  }

  if ($x.href)
  {
    $x.href_uri = [Uri]::new($tocUri, $x.href)
    $x.href_relative_uri = $tocUri.MakeRelativeUri($x.href_uri)
    $x.href_path = (join-path $tocYmlFolder -ChildPath $x.href)
  }

  if ($x.homepage)
  {
    $x.homepage_uri = [Uri]::new($tocUri, $x.homepage)
    $x.homepage_relative_uri = $tocUri.MakeRelativeUri($x.homepage_uri)
    $x.homepage_path = (join-path $tocYmlFolder -ChildPath $x.homepage)
  }

  if ("$($x.href_relative_uri)".endsWith("/") -and (Test-Path $x.href_path))
  {
    Write-Debug "href ends with / and folder exists, checking if that folder contains a toc.yml"
    $refWithTocYml = (Join-Path $x.href_path -childPath "toc.yml")

    if (Test-Path $refWithTocYml)
    {
      Write-Debug "href ends with /, and that folder has a toc.yml, updating the ref to point to that toc.yml instead"
      $x.href = "$($x.href)toc.yml"
      $x.href_uri = [Uri]::new($tocUri, $x.href)
      $x.href_relative_uri = $tocUri.MakeRelativeUri($x.href_uri)
      $x.href_path = (join-path $tocYmlFolder -ChildPath $x.href)
    }
    else
    {
      Write-Debug "href ends with /, but that folder does not have a toc.yml"
    }
  }

  if ($x.href -and $x.homepage)
  {
    Write-Debug "href and homepage specified, toc_yml:href and md:homepage"

    if ($x.href_uri.AbsolutePath.endsWith("/toc.yml"))
    {
      $x.toc_yml_item = (Get-Item -Path $x.href_path)
      $x.file_md_SubFolder = $x.toc_yml_item.Directory
    }
    else
    {
      $x.file_md_SubFolder = Get-Item -Path $x.href_Path
    }

    if (Test-Path $x.homepage_path)
    {
      Write-Debug "homepage found"
      $x.file_md_Item = get-item -Path $x.homepage_path
    }
  }
  elseif ($x.href)
  {
    Write-Debug "href only"
    if ($x.href_uri.AbsolutePath.endsWith("/toc.yml"))
    {
      if (Test-Path $x.href_path)
      {
        Write-Debug "href endsWith /toc.yml and toc.yml exists.  This gives us toc and folder."
        $x.toc_yml_item = (Get-Item -Path $x.href_path)
        $x.file_md_SubFolder = $x.toc_yml_item.Directory
      }
      else
      {
        Write-Debug "href endsWith /toc.yml, but toc.yml not found.  This gives us folder only, actually"
        $x.file_md_SubFolder = (Get-Item -Path "$($x.href_relative_uri)")
      }

      Write-Debug "Now, looking for an md file with the folder's name [$($x.file_md_SubFolder.Name)]"

      $md = Join-Path $tocYmlFolder -ChildPath "$($x.file_md_SubFolder.Name).md"

      if (Test-Path $md)
      {
        Write-Debug "Found an md file with the folder's name"
        $x.file_md_Item = Get-Item $md
      }
      else
      {
        Write-Debug "An md file with the folder's name was not found"
      }

    }
    elseif ($x.href_uri.AbsolutePath.endsWith("/"))
    {
      Write-Debug "href endsWith /, so that means the folder does not contain a toc.yml"
    }
    else
    {
      Write-Debug "href does not endWith /toc.yml nor /, need to find out if it's a folder or a file"
      if ((Test-Path $x.href_path))
      {
        $item = Get-Item $x.href_path

        if ($item.PSIsContainer)
        {
          Write-Debug "It's a folder"
        }
        else
        {
          Write-Debug "It's a file.  Checking for a subFolder with that filename(without extension)"

          $x.file_md_Item = $item

          $subFolderName = Join-Path (Split-Path $item.fullName) -ChildPath (Split-Path $item.fullName -LeafBase)

          if (Test-Path $subFolderName)
          {
            Write-Debug "A subfolder with the filename found.  checking for the existence of toc.yml in there."

            $x.file_md_SubFolder = Get-Item $subFolderName

            if (Test-Path (Join-Path $subFolderName -childPath "toc.yml"))
            {
              Write-Debug "Found a toc.yml"
              $x.toc_yml_Item = Get-Item (Join-Path $subFolderName -childPath "toc.yml")
            }
            else
            {
              Write-Debug "No toc.yml"
            }
          }
          else
          {
            Write-Debug "A subfolder with the filename not found [$($subFolderName)].  href is really just that file, and there's nothing else"
          }

        }

      }
      else
      {
        Write-Warning "href does not endWith /toc.yml nor /, plus couldn't find a file with under this path [$($x.href_path)]"
      }
    }
  }


  $ret = [ordered]@{
    toc_yml_Path           = $null
    file_md_Path           = $null
    file_md_SubFolder_Path = $null
  }

  Push-Location $tocYmlFolder
  if ($x.toc_yml_Item.FullName)
  {
    $ret.toc_yml_Path = (Resolve-Path $x.toc_yml_Item.FullName -Relative)
  }

  if ($x.file_md_Item.FullName)
  {
    $ret.file_md_Path = (Resolve-Path $x.file_md_Item.FullName -Relative)
  }

  if ($x.file_md_SubFolder.FullName)
  {
    $ret.file_md_SubFolder_Path = (Resolve-Path $x.file_md_SubFolder.FullName -Relative)
  }
  pop-location

  $ret | out-string| write-debug

  return [PSCustomObject]$ret
}

#endregion

#region Conceptual

#endregion

#region PowerShellModules

#endregion

function New-DocFx
{
  [cmdletbinding()]
  param(
    [Parameter(Mandatory)][System.IO.DirectoryInfo]$Target,
    [Parameter(Mandatory, ParameterSetName="String")][string]$BaseDocFxConfig,
    [Parameter(Mandatory, ParameterSetName="File")][System.IO.FileInfo]$BaseDocFxPath
  )

  process
  {
    $docfx_json = join-path $Target -ChildPath "docfx.json"
    Write-Debug "docfx will be [$($docfx_json)]"

    if ($BaseDocFxPath)
    {
      Write-Verbose "Copying [$BaseDocFxPath] to [$Target]"      
      copy-item $BaseDocFxPath -Destination $docfx_json -Force

      $docfxInSource = Get-content $BaseDocFxPath | ConvertFrom-Json -AsHashtable

      Write-Host "Copying [$($docfxInSource.build.template.Count)] DocFx Templates (if applicable)"

      foreach($template in $docfxInSource.build.template)
      {
        <#
          $template = $docfxInSource.build.template | select-object -first 1
          $template = $docfxInSource.build.template | select-object -first 1 -skip 1
        #>
        $templatePath = Join-Path $BaseDocFxPath.Directory -ChildPath $template

        if (Test-Path $templatePath)
        {
          $Destination = Join-Path $Target.FullName -ChildPath $template
          Write-Host "DocFx Template [$template] found, copying to [$Destination]"
          #& robocopy $templatePath $Destination /MIR
          Copy-Robo -Source $templatePath -Destination $Destination -Mirror -ShowFullPath -Verbose
        }
        else
        {
          Write-Host "DocFx Template [$template] not found in [$templatePath].  Template not copied"
        }
      }
    }
    else
    {
      Write-Verbose "Saving provided Base DocFx Config string to [$docfx_json]"
      $BaseDocFxConfig | set-content $docfx_json
    }

    $global:DocFxHelper = [ordered]@{
      docFx = @{
        Path = "$((Get-Item $docfx_json).FullName)"
      }
      all = @()
    }

    if ($DebugPreference -eq 'Continue')
    {
      Write-Debug "DocFxHelper.json:"
      $DocFxHelper | ConvertTo-Json -Depth 4 | Write-Debug
    }

    $docfxhelper_json=$null
    if ($DocFxHelperFiles.docfxhelper_json)
    {
      $docfxhelper_json = $DocFxHelperFiles.docfxhelper_json
    }
    else
    {
      $docfxhelper_json = (join-path $Target -ChildPath "docfxhelper.json")
    }
    
    $DocFxHelper | ConvertTo-Json -Depth 4 | Set-Content $docfxhelper_json

  }

}

function Add-ToRenameMap
{
    param([Parameter(Mandatory)]$Map, [Parameter(Mandatory)]$metadata)

    $metadata.FileIsRenamed = $true
    $metadata.DocFxSafe = AdoWiki_GetDocFxSafeItemMetadata -mdFile $metadata.File

    $renameMapItem = $Map | where-object {$_.From.FileAbsolutePath -eq $metadata.AdoWiki.FileAbsolute}

    if ($null -eq $renameMapItem)
    {
      Write-Debug "Adding $($metadata.AdoWiki.LinkAbsoluteMd) to RenameMap list"

      $renameMapItem = [ordered]@{
        metadata = $metadata
        from = @{
          FileAbsolutePath = $metadata.AdoWiki.File.FullName
          LinkAbsoluteMd = $metadata.AdoWiki.LinkAbsoluteMd
        }
        to = @{
          FileAbsolutePath = $metadata.File.FullName
          LinkAbsoluteMd = $metadata.DocFxSafe.LinkAbsolute
        }
      }

      [void]$Map.Add([PSCustomObject]$renameMapItem)
    }
    else
    {
      Write-Debug "Updating RenameMap item"
      Write-Debug "Before:"
      Write-Debug "  File Absolute Path: $($renameMapItem.to.FileAbsolutePath)"
      Write-Debug "  Link Absolute md: $($renameMapItem.to.FileAbsolutePath)"
      $renameMapItem.to.FileAbsolutePath = $metadata.File.FullName
      $renameMapItem.to.LinkAbsoluteMd = $metadata.DocFxSafe.LinkAbsolute
      Write-Debug "After:"
      Write-Debug "  File Absolute Path: $($renameMapItem.to.FileAbsolutePath)"
      Write-Debug "  Link Absolute md: $($renameMapItem.to.FileAbsolutePath)"
    }
}
function Move-MdFile
{
    param([Parameter(Mandatory)]$metadata, [Parameter(Mandatory)][System.IO.FileInfo]$ToPath)

    # $metadata.File = Rename-Item -Path $metadata.AdoWiki.FileAbsolute -NewName $metadata.DocFxSafe.FileName -Force -PassThru

    Write-Debug "Moving mdFile"
    Write-Debug "  From: $($metadata.File.FullName)"
    Write-Debug "    To: $($ToPath)"

    if (!$ToPath.Directory.Exists)
    {
        $ToPath.Directory.Create()
    }

    $ToPath_toc_yml = Join-Path $ToPath.Directory -ChildPath "toc.yml"

    if (!(Test-Path $ToPath_toc_yml))
    {
      Write-Debug "Creating empty toc.yml [$ToPath_toc_yml]"
      [ordered]@{items = @()} | ConvertTo-Yaml | set-content $ToPath_toc_yml
    }

    $metadata.File = Move-Item $metadata.File -Destination $ToPath -Force -PassThru
}

function Get-AdoWikiTocItem
{
  param(
    [Parameter(Mandatory)][string]$DisplayName, 
    [Parameter(Mandatory)][System.IO.FileInfo]$DotOrderPath,
    $Metadata,
    [switch]$IsRootWiki
  )

  Write-Debug "Get-AdoWikiTocItem for order item [$($DisplayName)]"
  Write-Debug ".order: [$($DotOrderPath)]"
  Write-Debug "mdFile: [$($metadata.File.FullName)]"

  $ret = [ordered]@{
    name = [System.Web.HttpUtility]::UrlDecode("$($DisplayName)".Replace("\(", "(").Replace("\)", ")").Replace("-", " "))
  }

  if ($null -ne $Metadata)
  {
    $mdFile = $Metadata.File
    
    if ($Metadata.FileIsRenamed)
    {
      Write-Debug "Metadata provided, but has moved"
      Write-Debug "mdFile was originally: [$($Metadata.AdoWiki.File)]"
      Write-Debug "mdFile now known as:   [$($MetaData.File.FullName)]"
    }
    else
    {
      Write-Debug "Metadata provided, using the last known location of the mdFile"
      Write-Debug "mdFile: [$($MetaData.File.FullName)]"
    }
  }
  else
  {
    Write-Debug "Metadata not provided, looking for a file with the .order item [$($DisplayName)] near [$($DotOrderPath)]"
    
    $mdFile = Get-ChildItem -Path $DotOrderPath.Directory -Filter "$($DisplayName).md" -Force | select-object -first 1
  }

  if ($mdFile)
  {
    $dotOrderFolder = $DotOrderPath.Directory
    $mdFileFolder = (split-path -Path $mdFile)
    $dotOrderIsRoot = $dotOrderFolder.FullName -eq (get-location).Path

    if ($mdFileFolder -eq $dotOrderFolder.FullName)
    {
      if ($isRootWiki -and $dotOrderIsRoot -and $mdFile.name -eq "index.md")
      {
        Write-Verbose "  md File is the default site's page, index.md from the root folder of the root wiki.  This toc item is therefor ignored"
        $ret = $null
      }
      else
      {
        Write-Verbose "md File is the same folder as the .order"

        $mdFileBaseNameFolder = Join-Path $mdFile.Directory -ChildPath $mdFile.BaseName

        if ([System.IO.Directory]::Exists($mdFileBaseNameFolder))
        {
          Write-Verbose "but found a folder with the mdFile's BaseName, so href to toc.yml + homepage to mdfile"
          $ret.href = "$($mdFile.BaseName)/toc.yml"
          $ret.homepage = "$($mdFile.Name)"
          Write-Verbose "href: $($ret.href)"
          Write-Verbose "homepage: $($ret.homepage)"
        }
        else
        {
          Write-Verbose "didn't find a folder with the mdFile's BaseName, so href is the mdFile"
          $ret.href = $mdFile.Name
          Write-Verbose "href: $($ret.href)"
        }
      }
    }
    else
    {
      Write-Verbose "mdFile is in a different folder than the .order"

      $mdFolderRelativeToDotOrder = Resolve-Path -Path $mdFileFolder -Relative -RelativeBasePath $dotOrderFolder.FullName

      if ($isRootWiki -and $dotOrderIsRoot)
      {
        Write-Verbose ".order is in the root folder of the root wiki, removing toc.yml from href, keeping trailing /"
        $ret.href = "$($mdFolderRelativeToDotOrder)/"
      }
      else
      {
        $ret.href = "$($mdFolderRelativeToDotOrder)/toc.yml"
      }
      Write-Verbose "href: $($ret.href)"

      if ($mdFile.Name -eq "index.md")
      {
        Write-Debug "mdFile is index.md, removing the filename from path"
        $mdFileHomepageFilename = ""
      }
      else
      {
        $mdFileHomepageFilename = "$($mdFile.Name)"
      }
      $ret.homepage = "$($mdFolderRelativeToDotOrder)/$($mdFileHomepageFilename)"
      Write-Debug "homepage: $($ret.homepage)"
    }
  }
  else
  {
    Write-Debug "Metadata is empty for item [$($DisplayName)] and [$($DotOrderPath)]"
    $ret.href = "$($DisplayName).md"
    Write-Debug "href: $($ret.href)"
  }

  return $ret
}

function ConvertTo-DocFxAdoWiki
{
  <#
    .SYNOPSIS
      Converts in 10 steps an Ado Wiki file format to DocFx file format

    .DESCRIPTION
      Steps performed
        1. Set Yaml Headers
          a. _docfxHelper.remote (was adoWikiAbsolutePath)
          b. _adoWikiUri
          c. DocFxHelperOrginalFileAbsolute
          d. Guid
        2. Snapshot .order files to the corresponding md file guid
        3. Prepare Hyperlinks
          a. Update wiki links removing escapes \(->( and \)->)
          b. Convert relative links to absolute
        4. Rename [md Files] to DocFx safe name format
        5. Rename [Folders] to DocFx safe name format
        6. Moving Root [md Files] that should actually be in their subfolder
        7. Finalize Hyperlinks
          a. Update wiki links to .md extension
          b. Update wiki links to match the renamed mdFiles or folder
          c. Convert absolute links to relative
        8. Update Mermaid Code Delimiters
        9. Set each page's UID      
        10. Convert every .order to toc.yml
        obsolete 11. Set toc.yml Items files that should point to their folder instead of their .md
        obsolete 12. Set Root toc.yml Items to Reference TOCs style /Foo/ instead of /Foo/toc.yml

  #>

  param(
    [Parameter(Mandatory)][System.IO.DirectoryInfo]$Path,
    [Parameter(Mandatory)][Uri]$WikiUri,
    [string]$RepoBranch = "main",
    [string]$RepoRelativePath = "/",
    [string]$PagesUidPrefix,
    [switch]$UseModernTemplate,
    [switch]$IsRootWiki,
    $AllMetadataExportPath
  )
 
  Write-Host "Updating AdoWiki [$Path] to make it DocFx friendly"

  Write-Debug "WikiUri: $($WikiUri)"
  Write-Debug "Repo Branch: $($RepoBranch)"
  Write-Debug "Repo Relative Path: $($RepoRelativePath)"
  Write-Debug "Pages UID Prefix: $($PagesUidPrefix)"
  Write-Debug "Use Modern Template: $($UseModernTemplate)"
  Write-Debug "Is Root Wiki: $($IsRootWiki)"
  Write-Debug "AllMetadata export path: $($AllMetadataExportPath)"
    
  push-location $Path

  $workingDirectory = (Get-Location)

  $renameMap = [System.Collections.ArrayList]::new()
  
  $folders = AdoWiki_GetAdoWikiFolders -Path . -Exclude @(".git", ".attachments")
  $allMetadata = $folders | AdoWiki_GetWikiMarkdowns | AdoWiki_GetAdoWikiMetadata

  Write-Host "Wiki [$($Path)]"
  Write-Host "   Folder Count: $($folders.Count)"
  Write-Host "   File count: $($allMetadata.Count)"
  
  
  # ------------------------------------------------------------------------  
  Write-Host "   - [1/10] Set Yaml Headers"
  Write-Verbose "     - _docfxHelper.remote"
  Write-Verbose "     - _adoWikiUri"
  Write-Verbose "     - DocFxHelperOrginalFileAbsolute"
  Write-Verbose "     - Guid"

  foreach ($metadata in $allMetadata)
  {
    <#
      $metadata = $allMetadata | select-object -first 1
      $metadata = $allMetadata | select-object -first 1 -skip 1

    #>

    Write-Debug "- $($metadata.File.Fullname)"

    $mdFileRemote = Get-DocFxRemote -fileRelativePath (Resolve-path $metadata.File -Relative) -CloneUrl "$WikiUri" -Branch $RepoBranch -RepoRelativePath $RepoRelativePath

    Write-Debug "Overwriting _docfxHelper.remote.path to the AdoWiki absolute path instead"
    $mdFileRemote.remote.path = $metadata.AdoWiki.WikiAbsolutePath

    # _docfxHelper.remote: Will be used by DocFxHelper DocFx template to generate the "Edit this document" url
    # used by DocFxHelper DocFx Template
    Util_Set_MdYamlHeader -file $metadata.File -key "_docfxHelper" -value $mdFileRemote
    
    # the only practical way to signal that this file is an ADO Wiki page and the path is not this file in the git repo but in the wiki
    # used by DocFxHelper DocFx Template
    Util_Set_MdYamlHeader -file $metadata.File -key "_adoWikiUri" -value "$WikiUri"

    # the only way to map a renamed/move mdFile to its original metadata
    # Used by the hyperlink linker
    Util_Set_MdYamlHeader -file $metadata.File -key "DocFxHelperOrginalFileAbsolute" -value $metadata.AdoWiki.FileAbsolute
    
    # the only way to map a renamed/move mdFile to the .order's orderItems
    Util_Set_MdYamlHeader -file $metadata.File -key "DocFxHelperGuid" -value $metadata.Guid

  }

  # ------------------------------------------------------------------------
  Write-Host "   - [2/10] Snapshot .order files to the corresponding md file guid"
  $dot_orders = Get-ChildItem -path . -Filter ".order" -Recurse -Force
  foreach ($dot_order in $dot_orders)
  {
    <#
      $dot_order = $dot_orders | select-object -first 1
      $dot_order = $dot_orders | select-object -first 1 -skip 1
      $dot_order = $dot_orders | select-object -first 1 -skip 2
      $dot_order = $dot_orders | select-object -first 1 -skip 3
      $dot_order
    #>

    $dot_order_relative = (Resolve-Path $dot_order.FullName -relative)
    $snapshot_dot_order = (Join-Path $dot_order.Directory.FullName -ChildPath "snapshot.order")

    [void](New-Item $snapshot_dot_order -ItemType File)

    $orderItems = Get-Content $dot_order

    foreach($orderItem in $orderItems)
    {
      <#
        $orderItem = $orderItems | select-object -first 1
        $orderItem

        $allMetadata.AdoWiki | select-object -first 1
        $allMetadata.AdoWiki.LinkAbsolute
      #>


      $metadata = $allMetadata | where-object {$_.AdoWiki.DotOrderRelative -eq $dot_order_relative -and $_.AdoWiki.LinkOrderItem -eq $orderItem}

      if ($null -eq $metadata)
      {
        Write-Warning "come on !!!"
      }

      [ordered]@{
        OrderItem = $orderItem
        Guid = $metadata.Guid
      } | ConvertTo-Json -Compress | Add-Content $snapshot_dot_order
    }
  }

  # ------------------------------------------------------------------------
  Write-Host "   - [3/10] Prepare Hyperlinks"
  Write-Verbose "     - a. Update wiki links removing escapes \(->( and \)->)"
  Write-Verbose "     - b. Convert relative links to absolute"

  foreach ($metadata in $allMetadata)
  {
    <#
      $metadata = $allMetadata | select-object -first 1
      $metadata = $allMetadata | select-object -first 1 -skip 1
    #>
    $mdFile = $metadata.File

    Write-Verbose $mdFile.fullname

    $content = Get-Content -LiteralPath $mdFile.FullName
    
    $content = AdoWiki_FixAdoWikiEscapes -content $content

    $pageUri = [Uri]::new($baseUri, $metadata.AdoWiki.FileRelativeUri)
    $content = AdoWiki_UpdateLinksToAbsoluteLinks -content $content -PageUri $pageUri

    $content | Set-Content -LiteralPath $mdFile.FullName

  }



  # ------------------------------------------------------------------------
  Write-Host "   - [4/10] Rename [md Files] to DocFx safe name format"
  foreach ($metadata in $allMetadata | where-object {$_.RenameRequired})
  {
    <#
      $metadata = $allMetadata | where-object {$_.RenameRequired} | select-object -first 1      
      $metadata = $allMetadata | where-object {$_.RenameRequired -and -not $_.FileIsRenamed} | select-object -first 1      
    #>    

    Write-Verbose "   - File $($metadata.AdoWiki.Filename) is not DocFx safe, rename required"

    #$metadataDocFxSafeLinkAbsoluteBefore = $metadata.File.FullName.SubString($workingDirectory.Path.Length).Replace("\", "/")
    #$metadata.File = Rename-Item -Path $metadata.AdoWiki.FileAbsolute -NewName $metadata.DocFxSafe.FileName -Force -PassThru

    $moveTo = (Join-Path (Get-Location).Path -ChildPath $metadata.DocFxSafe.FileRelative)
    Move-MdFile -Metadata $metadata -ToPath $moveTo
    Add-ToRenameMap -Map $renameMap -Metadata $metadata
    Util_Set_MdYamlHeader -file $metadata.File -key "DocFxSafeFileName" -value $metadata.File.Name
  }

  # ------------------------------------------------------------------------
  Write-Host "   - [5/10] Rename [Folders] to DocFx safe name format"
  $foldersMetadata = [System.Collections.ArrayList]::new()
  foreach ($folder in $folders)
  {

    <#
      $folder = $folders | select-object -first 1
    #>

    $foldersMetadata.Add([PSCustomObject]@{
        Folder         = $folder
        FolderRelative = $folder.FullName.Substring($workingDirectory.Path.Length)
        Depth          = $folder.FullName.Split("$([IO.Path]::DirectorySeparatorChar)").Count
      }) | out-null

  }

  foreach ($folderMetadata in $foldersMetadata | sort-object Depth -Descending)
  {
    <#
      $folderMetadata = $foldersMetadata | sort-object Depth -Descending | select-object -first 1
      $folderMetadata = $foldersMetadata | select-object -first 1 -skip 1

    #>    
    $folderUri = [Uri]::new($baseUri, $folderMetadata.FolderRelative.Replace("$([IO.Path]::DirectorySeparatorChar)", "/"))

    if ($folderUri.AbsoluteUri -ne $folderUri.OriginalString)
    {
      Write-Verbose "   - Folder $($folderMetadata.FolderRelative) is not DocFx safe, rename required"

      $filePathToRename = $folderMetadata.Folder.FullName
      $oldName = $folderMetadata.Folder.Name
      $newName = $folderUri.Segments[-1]
      Write-Verbose "      From: $($oldName)"
      Write-Verbose "        To: $($newName)"
      $newFolder = Rename-Item -Path $filePathToRename -NewName $newName -Force -PassThru

      foreach($mdFile in AdoWiki_GetAdoWikiFolders -Path $newFolder -Exclude @(".git", ".attachments") | AdoWiki_GetWikiMarkdowns)
      {
        <#
          $mdFile = AdoWiki_GetAdoWikiFolders -Path $newFolder -Exclude @(".git", ".attachments") | AdoWiki_GetWikiMarkdowns | select-object -first 1
          $mdFile
        #>

        $mdFileYaml = Util_Get_MdYamlHeader -file $mdFile
        $metadata = $allMetadata | where-object {$_.AdoWiki.FileAbsolute -eq $mdFileYaml.DocFxHelperOrginalFileAbsolute}
        $metadata.file = $mdFile
        
        Add-ToRenameMap -Map $renameMap -Metadata $metadata
    
      }
    }
  }

  # ------------------------------------------------------------------------
  Write-Host "   - [6/10] Moving Root [md Files] that should actually be in their subfolder"
  if ($UseModernTemplate -and $IsRootWiki)
  {    

    $rootMdFiles = Get-Childitem -path . -filter "*.md" -Force | where-object {$_.Name -ne "index.md"}
    
    foreach($mdFile in $rootMdFiles)
    {
        <#
            $mdFile = $rootMdFiles | select-object -first 1
            $mdFile
        #>
        $mdFileYaml = Util_Get_MdYamlHeader -file $mdFile
        $metadata = $allMetadata | where-object {$_.AdoWiki.FileAbsolute -eq $mdFileYaml.DocFxHelperOrginalFileAbsolute}
        $moveTo = Join-Path $metadata.File.Directory.FullName -ChildPath $metadata.File.BaseName -AdditionalChildPath "index.md"
        <#
            $Metadata = $metadata
            $ToPath = $moveTo
        #>
        Move-MdFile -Metadata $metadata -ToPath $moveTo
        
        <#
            $Map = $renameMap         
        #>
        Add-ToRenameMap -Map $renameMap -Metadata $metadata

    }  
  }
  else
  {
    Write-Host "     ... [6/10] Moving Root [md Files] that should actually be in their subfolder ----- This is either a child wiki or a doesn't use Modern Template, skipping..."
  }

  # ------------------------------------------------------------------------
  Write-Host "   - [7/10] Finalize Hyperlinks"
  Write-Verbose "     - a. Update wiki links to .md extension"
  Write-Verbose "     - b. Update wiki links to match the renamed mdFiles or folder"
  Write-Verbose "     - c. Convert absolute links to relative"
  foreach ($metadata in $allMetadata)
  {
    <#
      $metadata = $allMetadata | select-object -first 1
    #>
    $mdFile = $metadata.File

    Write-Verbose $mdFile.fullname

    $content = Get-Content -LiteralPath $mdFile.FullName
   
    
    # /foo/bar -> /foo/bar.md    
    $content = AdoWiki_UpdateLinksToMdLinks -content $content -AllMdFiles $allMetadata.DocFxSafe.LinkAbsolute -MdFileMetadata $metadata
    
    if ($renameMap.Count -gt 0)
    {
      # /foo bar/foo bar.md -> /foo_bar/foo_bar.md
      $content = AdoWiki_UpdateRenamedLinks -Content $content -Map $renameMap
    }
    
    # /foo/bar.md -> [[../]foo/]bar.md depends on the current page's uri
    $pageUri = [Uri]::new($baseUri, $mdFile.FullName.Substring($workingDirectory.Path.Length))
    $content = AdoWiki_UpdateLinksToRelativeLinks -content $content -PageUri $pageUri

    $content | Set-Content -LiteralPath $mdFile.FullName
  }





  # ------------------------------------------------------------------------
  Write-Host "   - [8/10] Update Mermaid Code Delimiters"
  foreach ($metadata in $allMetadata)
  {
    $mdFile = $metadata.File

    AdoWiki_UpdateMermaidCodeDelimiter -mdfile $mdFile
  }

  # ------------------------------------------------------------------------
  Write-Host "   - [9/10] Set each page's UID"
  foreach ($metadata in $allMetadata)
  {

    $pageUID = Util_Get_PageUid -pagesUidPrefix $PagesUidPrefix -mdfile $metadata.File
    Util_Set_MdYamlHeader -file $metadata.File -key "uid" -value $pageUID    
  }

  Write-Debug "Reloading folder list because some might have been renamed"
  $folders = AdoWiki_GetAdoWikiFolders -Path . -Exclude @(".git", ".attachments")

  # ------------------------------------------------------------------------
  Write-Host "   - [10/10] Convert every .order to toc.yml"
  foreach ($folder in $folders)
  {
    <#
      $folder = $folders | select-object -first 1
      $folder = $folders | select-object -first 1 -skip 1
      $folder = $folders | select-object -first 1 -skip 2
      $folder = $folders | select-object -first 1 -skip 3
      $folder
    #>

    $snapshot_dot_order = (Join-Path $folder -ChildPath "snapshot.order")
    $toc_yml = (Join-Path $folder -ChildPath "toc.yml")

    $docfx_toc_items = [System.Collections.ArrayList]::new()

    if (Test-Path $snapshot_dot_order)
    {
      Write-Verbose $snapshot_dot_order

      $dot_order = Join-Path (Split-Path $snapshot_dot_order) -ChildPath ".order"

      $snapshot_items = Get-Content $snapshot_dot_order
      <#
        $snapshot_items
      #>

      $s = @{}
      if ($isRootWiki)
      {
        $s.IsRootWiki = $isRootWiki
      }

      foreach($snapshot_item in $snapshot_items)
      {
        <#
          $snapshot_item = $snapshot_items | select-object -first 1
          $snapshot_item = $snapshot_items | select-object -first 1 -skip 1
          $snapshot_item = $snapshot_items | select-object -first 1 -skip 2
          $snapshot_item

          $allMetadata | convertto-json

        #>
        $orderItem = $snapshot_item | ConvertFrom-Json
        if ($null -ne $orderItem.Guid)
        {
          $metadata = $allMetadata | where-object {$_.Guid -eq $orderItem.Guid}
          
          $docfx_toc_item = Get-AdoWikiTocItem -displayName $orderItem.OrderItem -Metadata $metadata -DotOrderPath $dot_order @s
        }
        else
        {
          Write-Warning "Metadata not found for guid [$($orderItem.Guid)]"
        }
        if ($null -ne $docfx_toc_item)
        {
          [void]$docfx_toc_items.Add($docfx_toc_item)
        }
      }
    }
    
    if (Test-Path -LiteralPath $toc_yml)
    {
      Write-Verbose "Reading items from [$toc_yml]"
      $toc = Get-Content -LiteralPath $toc_yml | convertfrom-Yaml
    }
    else
    {
      $toc = [ordered]@{}
    }

    if ($null -eq $toc.items)
    {
      $toc.items = @()
    }

    if ($docfx_toc_items.Count -gt 0)
    {
      if ($toc.items.Count -gt 0)
      {
        Write-Debug "Merging items from [.order] into existing [$toc_yml]"
        $toc.items = Join-DocFxTocItems -tocItems $toc.items -otherTocItems $docfx_toc_items
      }
      else
      {
        $toc.items = $docfx_toc_items.ToArray()
      }
    }
    
    Write-Debug "Saving toc to [$toc_yml]"
    $toc | ConvertTo-Yaml -Depth 10 | Set-Content $toc_yml
  }

  Write-Information "Conversion done"

  if ($AllMetadataExportPath)
  {
    Write-Information "Saving DocFxAdoWiki's metadata to [$($AllMetadataExportPath)]"
    [void](New-Item $AllMetadataExportPath -ItemType File -Force)
    $allMetadata | ConvertTo-Json -Depth 6 | set-content $AllMetadataExportPath
    Write-Host "DocFx Ado Wiki Metadata exported to [$AllMetadataExportPath]"
  }

  pop-location

}

function Add-AdoWiki {
  param(
      [Parameter(Mandatory)][System.IO.DirectoryInfo]$Path,
      [Parameter(Mandatory)][string]$Id,
      [Parameter(Mandatory)][Uri]$CloneUrl,
      [Parameter(Mandatory)][Uri]$WikiUrl,
      [string]$Target,
      [string]$MenuParentItemName,
      [string]$MenuDisplayName,
      [int]$MenuPosition = -1,
      [string]$Homepage,
      [string]$MenuUid,
      [string[]]$Excludes,
      [string]$WikiDocsSubfolder,
      [string[]]$Medias,
      [string]$ParentId
  )

  Write-Debug "----------------------------------------------"
  Write-Debug "[$($MyInvocation.MyCommand.Name)]"
  Write-Debug "Path:     [$Path]"
  Write-Debug "Id:       [$Id]"
  Write-Debug "CloneUrl: [$CloneUrl]"
  Write-Debug "WikiUrl:  [$WikiUrl]"

  Push-Location (split-path $DocFxHelper.docFx.Path)

  Write-Debug "----------------------------------------------"
  Write-Host "Prepare ViewModel $Path"
  $a = @{
      ResourceType       = [ResourceType]::Wiki
      Id                 = $Id
      Path               = $Path.FullName
      CloneUrl           = $CloneUrl
      SubFolder          = $WikiDocsSubfolder
      Target             = $Target
      MenuParentItemName = $MenuParentItemName
      MenuDisplayName    = $MenuDisplayName
      MenuPosition       = $MenuPosition
      Homepage           = $Homepage
      MenuUid            = $MenuUid
      Medias             = $Medias
      ParentId           = $ParentId
      Excludes           = $Excludes
  }    
  $viewModel = ViewModel_getGenericResourceViewModel @a

  Write-Debug "----------------------------------------------"
  Write-Debug "Add resource specific details to Resource ViewModel"
  $viewModel.wikiUrl = "$WikiUrl"
  $viewModel.isRootWiki = ("$($viewModel.target)" -eq "/")
  $viewModel.medias += ".attachments"

  Write-Debug "----------------------------------------------"
  Write-Debug "Add Resource ViewModel to DocFxHelper"
  Add-DocFxHelperResource -Resource $viewModel

  if ($viewModel.Id -eq $viewModel.ParentId)
  {
    Write-Debug "----------------------------------------------"
    Write-Host  "This is the root resource - no child to add to a parent toc.yml"
  }
  else
  {
    if ("$($viewModel.menuDisplayName)" -eq "") {
      Write-Debug "----------------------------------------------"
      Write-Host  "Resource $($viewModel.id) doesn't not specify a Menu Display (-MenuDisplayName), so the resource won't be added to the parent toc.yml"
    }
    else{
      Write-Debug "----------------------------------------------"
      Write-Host  "Adding $($viewModel.menuDisplayName) to parent [$($viewModel.parentToc_yml)]"
  
      AddResource_ToParent `
        -ParentTocYml $viewModel.parentToc_yml `
        -ParentTocYmlIsRoot $viewModel.parentToc_yml_isRoot `
        -ResourcePath $viewModel.Path `
        -MenuParentItemName $viewModel.MenuParentItemName `
        -MenuDisplayName $viewModel.MenuDisplayName `
        -MenuPosition $viewModel.menuPosition `
        -HomePage $viewModel.homepage `
        -MenuUid $viewModel.MenuUid
    }
  }

  $destSegments = [System.Collections.ArrayList]::new()

  foreach($s in ("$($viewModel.Target)".Replace("/", "\").Split("\") | where-object {$_}))
  {
    [void]$destSegments.Add($s)
  }

  $adoWikiMeta = [ordered]@{
    Build = [ordered]@{
      Content      = [ordered]@{
          files = @("**/*.yml", "**/*.md")
          src   = (Resolve-Path $Path.FullName -Relative)
          dest  = Join-Path -Path . -ChildPath "" -AdditionalChildPath $destSegments.ToArray()
      }
      Resource     = [ordered]@{
          files = @(".attachments/**")
          src   = (Resolve-Path $Path.FullName -Relative)
          dest  =  Join-Path -Path . -ChildPath "" -AdditionalChildPath ($destSegments.ToArray() + ".attachments")
      }
    }
  }

  Write-Debug "----------------------------------------------"
  Write-Host "Adding Resource to DocFx.json"
  DocFx_AddViewModel -Path $DocFxhelper.docFx.Path -Meta $adoWikiMeta
  
  Write-Host "[$($MyInvocation.MyCommand.Name)] Done"

  Pop-Location
}

function Add-DotnetApi
{
  param(
    [Parameter(Mandatory)][System.IO.DirectoryInfo]$Path,
    [Parameter(Mandatory)][string]$Id,
    [string]$Target,
    [string]$MenuParentItemName,
    [string]$MenuDisplayName,
    [int]$MenuPosition = -1,
    [string]$MenuUid,
    [string[]]$Excludes,
    [string[]]$Medias,
    [string]$ParentId
  )

  Write-Debug "----------------------------------------------"
  Write-Debug "[$($MyInvocation.MyCommand.Name)]"
  Write-Debug "Path:     [$Path]"
  Write-Debug "Id:       [$Id]"

  Push-Location (split-path $DocFxHelper.docFx.Path)
  
  Write-Debug "----------------------------------------------"
  Write-Host "Prepare ViewModel $Path"
  $a = @{
    ResourceType       = [ResourceType]::Api
    Id                 = $Id
    Path               = $Path.FullName    
    Target             = $Target
    MenuParentItemName = $MenuParentItemName
    MenuDisplayName    = $MenuDisplayName
    MenuPosition       = $MenuPosition
    MenuUid            = $MenuUid
    Medias             = $Medias
    ParentId           = $ParentId
  }
  $viewModel = ViewModel_getGenericResourceViewModel @a
  
  
  Write-Debug "----------------------------------------------"
  Write-Debug "Add Resource ViewModel to DocFxHelper"
  Add-DocFxHelperResource -Resource $viewModel
  
  if ($viewModel.Id -eq $viewModel.ParentId)
  {
    Write-Debug "----------------------------------------------"
    Write-Host  "This is the root resource - no child to add to a parent toc.yml"
  }
  else
  {
    if ("$($viewModel.menuDisplayName)" -eq "") {
      Write-Debug "----------------------------------------------"
      Write-Host  "Resource $($viewModel.id) doesn't not specify a Menu Display (-MenuDisplayName), so the resource won't be added to the parent toc.yml"
    }
    else{
      Write-Debug "----------------------------------------------"
      Write-Host  "Adding $($viewModel.menuDisplayName) to parent [$($viewModel.parentToc_yml)]"
  
      AddResource_ToParent `
        -ParentTocYml $viewModel.parentToc_yml `
        -ParentTocYmlIsRoot $viewModel.parentToc_yml_isRoot `
        -ResourcePath $viewModel.Path `
        -MenuParentItemName $viewModel.MenuParentItemName `
        -MenuDisplayName $viewModel.MenuDisplayName `
        -MenuPosition $viewModel.menuPosition `
        -HomePage $viewModel.homepage `
        -MenuUid $viewModel.MenuUid
    }
  }

  Write-Debug "----------------------------------------------"
  Write-Host  "Fix Toc Items that should point to their folder instead of their .md"  
  DocFx_FixTocItemsThatShouldPointToTheirFolderInstead -Path $viewModel.Path
  
  $dotnetApiMeta = [ordered]@{
    Build = [ordered]@{
      Content      = [ordered]@{
          files = @("**/*.yml", "**/*.md")
          src   = (Resolve-Path $Path.FullName -Relative)
      }
    }
  }

  if ($viewModel.Target -ne "/")
  {
    $dotnetApiMeta.Build.Content.dest = ($viewModel.Target -split "/" | where-object {$_}) -join "/"
  }


  Write-Debug "----------------------------------------------"
  Write-Host "Adding Resource to DocFx.json"
  DocFx_AddViewModel -Path $DocFxhelper.docFx.Path -Meta $dotnetApiMeta
  
  Write-Host "[$($MyInvocation.MyCommand.Name)] Done"

  pop-location
  return $DocFxHelper
}

function Add-RestApi
{
  param(
    [Parameter(Mandatory)][System.IO.DirectoryInfo]$Path,
    [Parameter(Mandatory)][string]$Id,
    [string]$Target,
    [string]$MenuParentItemName,
    [string]$MenuDisplayName,
    [int]$MenuPosition = -1,
    [string]$MenuUid,
    [string[]]$Excludes,
    [string[]]$Medias,
    [string]$ParentId
  )

  Write-Debug "----------------------------------------------"
  Write-Debug "[$($MyInvocation.MyCommand.Name)]"
  Write-Debug "Path:     [$Path]"
  Write-Debug "Id:       [$Id]"

  Push-Location (split-path $DocFxHelper.docFx.Path)
  
  Write-Debug "----------------------------------------------"
  Write-Host "Prepare ViewModel $Path"
  $a = @{
    ResourceType       = [ResourceType]::Api
    Id                 = $Id
    Path               = $Path.FullName    
    Target             = $Target
    MenuParentItemName = $MenuParentItemName
    MenuDisplayName    = $MenuDisplayName
    MenuPosition       = $MenuPosition
    MenuUid            = $MenuUid
    Medias             = $Medias
    ParentId           = $ParentId
  }
  $viewModel = ViewModel_getGenericResourceViewModel @a
  
  
  Write-Debug "----------------------------------------------"
  Write-Debug "Add Resource ViewModel to DocFxHelper"
  Add-DocFxHelperResource -Resource $viewModel
  
  if ($viewModel.Id -eq $viewModel.ParentId)
  {
    Write-Debug "----------------------------------------------"
    Write-Host  "This is the root resource - no child to add to a parent toc.yml"
  }
  else
  {
    if ("$($viewModel.menuDisplayName)" -eq "") {
      Write-Debug "----------------------------------------------"
      Write-Host  "Resource $($viewModel.id) doesn't not specify a Menu Display (-MenuDisplayName), so the resource won't be added to the parent toc.yml"
    }
    else{
      Write-Debug "----------------------------------------------"
      Write-Host  "Adding $($viewModel.menuDisplayName) to parent [$($viewModel.parentToc_yml)]"
  
      AddResource_ToParent `
        -ParentTocYml $viewModel.parentToc_yml `
        -ParentTocYmlIsRoot $viewModel.parentToc_yml_isRoot `
        -ResourcePath $viewModel.Path `
        -MenuParentItemName $viewModel.MenuParentItemName `
        -MenuDisplayName $viewModel.MenuDisplayName `
        -MenuPosition $viewModel.menuPosition `
        -HomePage $viewModel.homepage `
        -MenuUid $viewModel.MenuUid
    }
  }

  Write-Debug "----------------------------------------------"
  Write-Host  "Fix Toc Items that should point to their folder instead of their .md"  
  DocFx_FixTocItemsThatShouldPointToTheirFolderInstead -Path $viewModel.Path
  
  $restApiMeta = [ordered]@{
    Build = [ordered]@{
      Content      = [ordered]@{
          files = @("**/*swagger.json")
          src   = (Resolve-Path $Path.FullName -Relative)
      }
    }
  }

  if ($viewModel.Target -ne "/")
  {
    $restApiMeta.Build.Content.dest = ($viewModel.Target -split "/" | where-object {$_}) -join "/"
  }

  Write-Debug "----------------------------------------------"
  Write-Host "Adding Resource to DocFx.json"
  DocFx_AddViewModel -Path $DocFxhelper.docFx.Path -Meta $restApiMeta
  
  Write-Host "[$($MyInvocation.MyCommand.Name)] Done"

  pop-location
  return $DocFxHelper
}

function ConvertTo-DocFxConceptual
{
  param(
    [Parameter(Mandatory)][System.IO.DirectoryInfo]$Path, 
    [Parameter(Mandatory)][Uri]$CloneUrl, 
    [string]$PagesUidPrefix,
    [string]$RepoBranch = "main",
    [string]$RepoRelativePath = "/"
  )

  Write-Host "[ConvertTo-DocFxConceptual]"
  Write-Host "   Conceptual path: [$($Path)]"
  Write-Host "          CloneUrl: [$($CloneUrl)]"
  Write-Host "            Branch: [$($RepoBranch)]"
  Write-Host "Repo relative path: [$($RepoRelativePath)]"
      
  Push-Location $Path
  
  $mdFiles = get-childitem -Path . -Filter "*.md" -Recurse -Force
  
  Write-Host "$($mdFiles.count) conceptual markdown files found"

  $relativePathSegments = "$RepoRelativePath".Replace("\", "/") -split "/"
  
  foreach ($mdFile in $mdFiles)
  {
    <#
      $mdFile = $mdFiles | select-object -first 1
      $mdFile 
    #>
    <#
      $File = $mdfile
    #>

    $pageUid = Util_Get_PageUid -pagesUidPrefix $pagesUidPrefix -mdfile $mdFile    
    Util_Set_MdYamlHeader -file $mdFile -key "uid" -value $pageUid

    $mdFileRemote = Get-DocFxRemote -fileRelativePath (Resolve-path $mdFile -Relative) -CloneUrl "$CloneUrl" -Branch $Branch -RepoRelativePath $RepoRelativePath

    # _docfxHelper.remote: Will be used by DocFxHelper DocFx template to generate the "Edit this document" url
    Util_Set_MdYamlHeader -file $mdFile -key "_docfxHelper" -value $mdFileRemote


  }

  pop-location

  Write-Debug "----------------------------------------------"
  Write-Host  "Fix Toc Items that should point to their folder instead of their .md"
  DocFx_FixTocItemsThatShouldPointToTheirFolderInstead -Path $Path

}


function Add-Conceptual
{
  param(
    [Parameter(Mandatory)][System.IO.DirectoryInfo]$Path,
    [Parameter(Mandatory)][string]$Id,
    [Parameter(Mandatory)][Uri]$CloneUrl,
    [string]$RepoRelativePath,
    [string]$Target,
    [string]$MenuParentItemName,
    [string]$MenuDisplayName,
    [int]$MenuPosition = -1,
    [string]$Homepage,
    [string]$MenuUid,
    [string[]]$Excludes,
    [string[]]$Medias,
    [string]$ParentId
  )

  
  Write-Debug "----------------------------------------------"
  Write-Debug "[$($MyInvocation.MyCommand.Name)]"
  Write-Debug "Path:     [$Path]"
  Write-Debug "Id:       [$Id]"
  Write-Debug "CloneUrl: [$CloneUrl]"

  Push-Location (split-path $DocFxHelper.docFx.Path)
  
  Write-Debug "----------------------------------------------"
  Write-Host "Prepare ViewModel $Path"
  $a = @{
    ResourceType       = [ResourceType]::Conceptual
    Id                 = $Id
    Path               = $Path.FullName
    CloneUrl           = $CloneUrl
    RepoRelativePath   = $RepoRelativePath
    Target             = $Target
    MenuParentItemName = $MenuParentItemName
    MenuDisplayName    = $MenuDisplayName
    MenuPosition       = $MenuPosition
    Homepage           = $Homepage
    MenuUid            = $MenuUid
    Medias             = $Medias
    ParentId           = $ParentId
  }
  $viewModel = ViewModel_getGenericResourceViewModel @a

  Write-Debug "----------------------------------------------"
  Write-Debug "Add resource specific details to Resource ViewModel"

  Write-Debug "----------------------------------------------"
  Write-Debug "Add Resource ViewModel to DocFxHelper"
  Add-DocFxHelperResource -Resource $viewModel

  if ($viewModel.Id -eq $viewModel.ParentId)
  {
    Write-Debug "----------------------------------------------"
    Write-Host  "This is the root resource - no child to add to a parent toc.yml"
  }
  else
  {
    if ("$($viewModel.menuDisplayName)" -eq "") {
      Write-Debug "----------------------------------------------"
      Write-Host  "Resource $($viewModel.id) doesn't not specify a Menu Display (-MenuDisplayName), so the resource won't be added to the parent toc.yml"
    }
    else{
      Write-Debug "----------------------------------------------"
      Write-Host  "Adding $($viewModel.menuDisplayName) to parent [$($viewModel.parentToc_yml)]"
  
      AddResource_ToParent `
        -ParentTocYml $viewModel.parentToc_yml `
        -ParentTocYmlIsRoot $viewModel.parentToc_yml_isRoot `
        -ResourcePath $viewModel.Path `
        -MenuParentItemName $viewModel.MenuParentItemName `
        -MenuDisplayName $viewModel.MenuDisplayName `
        -MenuPosition $viewModel.menuPosition `
        -HomePage $viewModel.homepage `
        -MenuUid $viewModel.MenuUid
    }
  }

  
  Write-Debug "----------------------------------------------"
  Write-Host "Adding Resource to DocFx.json"

  $ConceptualMeta = [ordered]@{
    Build = [ordered]@{
      Content = [ordered]@{
          files = @("**/*.{md,yml}")
          src = (Resolve-Path $Path.FullName -Relative)
          dest = ($viewModel.Target -split "/" | where-object {$_}) -join "/"
      }
    }
  }

  if ($Excludes)
  {
    $ConceptualMeta.Build.Content.exclude = @()

    foreach($exclude in $Excludes)
    {
      $ConceptualMeta.Build.Content.exclude += $exclude
    }
  }
  else
  {
    $ConceptualMeta.Build.Content.exclude = @("**/*Private*")
  }

  if ($ViewModel.Medias)
  {
    $ConceptualMeta.Build.Resource = [ordered]@{
      src = (Resolve-Path $Path.FullName -Relative)
      dest = ($viewModel.Target -split "/" | where-object {$_}) -join "/"
      files = @()
    }
    foreach($res in $ViewModel.Medias)
    {
      $ConceptualMeta.Build.Resource.files += $res
    }
  }

  DocFx_AddViewModel -Path $DocFxhelper.docFx.Path -Meta $ConceptualMeta
  
  Write-Host "[$($MyInvocation.MyCommand.Name)] Done"

  pop-location

}

function Set_DocFxRemote
{
  param([Parameter(Mandatory)][System.IO.FileInfo]$mdFile, $Remote)

  Util_Set_MdYamlHeader -file $mdFile -key "source" -value $Remote.source
  Util_Set_MdYamlHeader -file $mdFile -key "documentation" -value $Remote.documentation

}

function Get-DocFxRemote
{
  param(
    [Parameter(Mandatory)][string]$fileRelativePath,
    [Parameter(Mandatory)][Uri]$CloneUrl,
    [string]$Branch = "main",
    [string]$RepoRelativePath = "/"
  )

    $repoRelativePathSegments = "$repoRelativePath".Replace("\", "/") -split "/"
    $fileRelativePathSegments = "$fileRelativePath".Replace("\", "/") -split "/"

    return [ordered]@{
      remote = [ordered]@{
        repo = "$CloneUrl"
        branch = "$RepoBranch"
        path = "$(($repoRelativePathSegments + $fileRelativePathSegments | where-object {$_ -and $_ -ne "."}) -join "/")"
      }
    }
}

function ConvertTo-DocFxPowerShellModule
{
  param(
    [Parameter(Mandatory)][System.IO.DirectoryInfo]$Path, 
    [Parameter(Mandatory)][string]$PagesUidPrefix, 
    [Parameter(Mandatory)][Uri]$CloneUrl,
    [string]$RepoBranch = "main",
    [string]$RepoRelativePath = "/"
  )

  Write-Host "[ConvertTo-DocFxPowerShellModule]"
  Write-Host "   Conceptual path: [$($Path)]"
  Write-Host "    PagesUidPrefix: [$($PagesUidPrefix)]"
  Write-Host "          CloneUrl: [$($CloneUrl)]"
  Write-Host "        RepoBranch: [$($RepoBranch)]"
  Write-Host "  RepoRelativePath: [$($RepoRelativePath)]"

      
  Push-Location $Path
  
  $mdFiles = get-childitem -Path . -Filter "*.md" -Recurse -Force

  Write-Host "$($mdFiles.count) PowerShell Module markdown files found"
  
  foreach ($mdFile in $mdFiles)
  {
    <#
      $mdFile = $mdFiles | select-object -first 1
      $mdFile 
    #>
    <#
      $File = $mdfile
    #>

    $pageUid = Util_Get_PageUid -pagesUidPrefix $PagesUidPrefix -mdfile $mdFile
    Util_Set_MdYamlHeader -file $mdFile -key "uid" -value $pageUid

    $mdFileRemote = Get-DocFxRemote -fileRelativePath (Resolve-Path $mdFile -Relative) -CloneUrl "$CloneUrl" -Branch $RepoBranch -RepoRelativePath $RepoRelativePath

    Write-Debug "Overwriting _docfxHelper.remote.path to the ps1/psd1/psm1 file instead"
    $meta = Util_Get_MdYamlHeader -file $mdFile
    $mdFileRemote.remote.path = $meta.metadata.path

    $mdFileRemote.startLine = if ($meta.metadata.startLine) { $meta.metadata.startLine} else {0}
    $mdFileRemote.endLine = if ($meta.metadata.endLine) { $meta.metadata.endLine} else {0}

    # _docfxHelper.remote: Will be used by DocFxHelper DocFx template to generate the "Edit this document" url
    Util_Set_MdYamlHeader -file $mdFile -key "_docfxHelper" -value $mdFileRemote

  }
  pop-location

}

function Add-PowerShellModule
{
  param(
    [Parameter(Mandatory)][System.IO.DirectoryInfo]$Path,
    [Parameter(Mandatory)][string]$Id,
    [Parameter(Mandatory)][Uri]$CloneUrl,
    [string]$RepoRelativePath,
    [string]$RepoBranch,
    [string]$Target,
    [string]$MenuParentItemName,
    [string]$MenuDisplayName,
    [int]$MenuPosition = -1,
    [string]$Homepage,
    [string]$MenuUid,
    [string[]]$Excludes,
    [string[]]$Medias,
    [string]$ParentId
  )
  Write-Debug "----------------------------------------------"
  Write-Debug "[$($MyInvocation.MyCommand.Name)]"
  Write-Debug "Path:     [$Path]"
  Write-Debug "Id:       [$Id]"
  Write-Debug "CloneUrl: [$CloneUrl]"

  Push-Location (split-path $DocFxHelper.docFx.Path)

  Write-Debug "----------------------------------------------"
  Write-Host "Prepare ViewModel $Path"

  $a = @{
    ResourceType       = [ResourceType]::PowerShellModule
    Id                 = $Id
    Path               = $Path.FullName
    CloneUrl           = $CloneUrl
    RepoBranch         = $RepoBranch
    RepoRelativePath   = $RepoRelativePath
    Target             = $Target
    MenuParentItemName = $MenuParentItemName
    MenuDisplayName    = $MenuDisplayName
    MenuPosition       = $MenuPosition
    Homepage           = $Homepage
    MenuUid            = $MenuUid
    Medias             = $Medias
    ParentId           = $ParentId
  }
  $viewModel = ViewModel_getGenericResourceViewModel @a

  Write-Debug "----------------------------------------------"
  Write-Debug "Add resource specific details to Resource ViewModel"
  $viewModel.medias += ".attachments"

  Write-Debug "----------------------------------------------"
  Write-Debug "Add Resource ViewModel to DocFxHelper"
  Add-DocFxHelperResource -Resource $viewModel
  
  if ($viewModel.Id -eq $viewModel.ParentId)
  {
    Write-Debug "----------------------------------------------"
    Write-Host  "This is the root resource - no child to add to a parent toc.yml"
  }
  else
  {
    if ("$($viewModel.menuDisplayName)" -eq "") {
      Write-Debug "----------------------------------------------"
      Write-Host  "Resource $($viewModel.id) doesn't not specify a Menu Display (-MenuDisplayName), so the resource won't be added to the parent toc.yml"
    }
    else{
      Write-Debug "----------------------------------------------"
      Write-Host  "Adding $($viewModel.menuDisplayName) to parent [$($viewModel.parentToc_yml)]"
  
      AddResource_ToParent `
        -ParentTocYml $viewModel.parentToc_yml `
        -ParentTocYmlIsRoot $viewModel.parentToc_yml_isRoot `
        -ResourcePath $viewModel.Path `
        -MenuParentItemName $viewModel.MenuParentItemName `
        -MenuDisplayName $viewModel.MenuDisplayName `
        -MenuPosition $viewModel.menuPosition `
        -HomePage $viewModel.homepage `
        -MenuUid $viewModel.MenuUid
    }
  }
 
  Write-Debug "----------------------------------------------"
  Write-Host "Adding Resource to DocFx.json"


  $PowerShellModuleMeta = [ordered]@{
    Build = [ordered]@{
      Content = [ordered]@{
          files = @("**/*.{md,yml}")
          src = (Resolve-Path $Path.FullName -Relative)
          dest = ($viewModel.Target -split "/" | where-object {$_}) -join "/"
      }
    }
  }

  if ($Excludes)
  {
    $PowerShellModuleMeta.Build.Content.exclude = @()
    foreach($exclude in $Excludes)
    {
      $PowerShellModuleMeta.Build.Content.exclude += $exclude
    }
  }
  else
  {
    $PowerShellModuleMeta.Build.Content.exclude = @("**/*Private*")
  }

  if ($Medias)
  {
    $PowerShellModuleMeta.Build.Resource = [ordered]@{
      src = Resolve-Path $Path.FullName -Relative
      dest = ($viewModel.Target -split "/" | where-object {$_}) -join "/"
      files = @()
    }
    foreach($res in $Medias)
    {
      $PowerShellModuleMeta.Build.Resource.files += $res
    }
  }
  DocFx_AddViewModel -Path $DocFxhelper.docFx.Path -Meta $PowerShellModuleMeta

  Write-Host "[$($MyInvocation.MyCommand.Name)] Done"

  pop-location

}

function Set-Template
{
  param(    
    [Parameter(Mandatory)]$Template, 
    [Parameter(Mandatory)][System.IO.FileInfo]$Target
  )

  Write-Host "Set-Template Generating Files from ViewModel using Mustache templates"
  Write-Host "Set-Template Step 1 - Prepare metadata"

  $saveYamlHeader = (split-path $Target -Extension) -eq ".md"

  if ($saveYamlHeader)
  {
    if (Test-Path -LiteralPath $Target.Fullname)
    {
      $mdMetadata = Util_Get_MdYamlHeader -file $Target
    }
    else
    {
      $mdMetadata = [ordered]@{}
    }
    $mdMetadata.generatedFrom = $Template
    $mdMetadata.generatedAt = (Get-Date).DateTime
    $mdMetadata.generatedOn = "$($ENV:COMPUTERNAME)"
    $mdMetadata.generatedBuildNumber = "$($ENV:BUILD_BUILDNUMBER)"
  }
  Write-Host "Set-Template Step 2 - Run Template"
  
  $resultFolder = (Split-path $Target)

  if (!(test-Path $resultFolder))
  {
    new-item -Path $resultFolder -Force -ItemType Directory | out-null
  }
  Write-Debug "  Template: [$($Template)]"
  Write-Debug "    Result: [$($Target)]"  
  $docFxHelperJson = $DocFxHelper | ConvertTo-Json -Depth 4
  $result = ConvertTo-PoshstacheTemplate -InputFile $Template -ParametersObject $DocFxHelperJson -Verbose
  $result | Set-Content -LiteralPath $Target.fullname -Force

  if ($saveYamlHeader)
  {
    Util_Set_MdYamlHeader -file $Target -data $mdMetadata
  }

  Write-Host "Set-Template Done - File [$($Target)] generated"

}

function Get-DocFxBuildLogViewModel
{
  param(
    [Parameter(Mandatory, ParameterSetName="ByFile")][System.IO.FileInfo]$DocFxLogFile,
    [Parameter(Mandatory, ParameterSetName="ByString")][string]$Content,
    [Parameter(Mandatory, ParameterSetName="ByObject")][object[]]$DocFxLogs

  )

  if ($DocFxLogFile)
  {
    if (Test-Path $DocFxLogFile)
    {
      $docfxBuildResult = Get-Content $DocFxLogFile | ConvertFrom-Json
    }
  }
  elseif ($Content)
  {
    $docfxBuildResult = ConvertFrom-Json
  }
  else
  {
    $docfxBuildResult = $DocFxLogs
  }

  # $docfxBuildResult | group-object {$_.severity}
  # $docfxBuildResult | group-object {$_.code}

  $vm = [ordered]@{
    DocFxVersion = "$(((& docfx --version) -split "\+")[0] )"
    DocFxHelperVersion = "$($DocFxHelperVersion)"
    GeneratedDateTime = "$((Get-Date))"
    StartedAt = $docfxBuildResult[0].date_time.ToString("hh:mm:ss")
    FinishedAt = $docfxBuildResult[-1].date_time.ToString("hh:mm:ss")
    TimeToBuild = "$(($docfxBuildResult[-1].date_time - $docfxBuildResult[0].date_time))"
    All = $docfxBuildResult
    GroupByMessageSeverity = $docfxBuildResult  | group-object {$_.severity} | select-object Name, @{l="ItemCount";e={$_.Count}}

  }

  $warnings = $docfxBuildResult | where-object {$_.severity -eq "warning"}

  if ($warnings.Count -gt 0)
  {
    $vm.Warnings = @{
      ItemCount = $warnings.Count
      GroupByCode = $warnings  | group-object {$_.code} | select-object Name, @{l="ItemCount";e={$_.Count}}
      TopProblemFiles = $warnings | group-object file | Sort-Object Count -Descending | select-object -first 10 Name, @{l="ItemCount";e={$_.Count}}
      ByCode = @()
    }

    $xrefs = @{}

    foreach($key in $vm.Warnings.groupByCode)
    {
      <#
        $key = $vm.Warnings.groupByCode[0]
        $key = $vm.Warnings.groupByCode[1]
      #>

      $ByCode = [PSCustomObject]@{
        CodeName = $key.Name
        ItemCount = $key.ItemCount
        Items = @()
      }

      foreach($item in $warnings | where-object {$_.code -eq $key.Name})
      {
        <#
          $item = $warnings | where-object {$_.code -eq $key.Name} | select-object -first 1
          $item = $warnings | where-object {$_.code -eq $key.Name} | select-object -last 1
          $item
        #>

        $xref = @{}

        if ($xrefs.ContainsKey($item.file))
        {
          $xref = $xrefs."$($item.file)"
        }
        else
        {
          if ($item.file.EndsWith(".md"))
          {
            try
            {
              if (Test-Path $item.file)
              {
                $yaml = Util_Get_MdYamlHeader -file (Get-Item -Path (Resolve-Path $item.file))
                $xref.xref = $yaml.uid
              }
            }
            catch {}
          }

          $xrefs."$($item.file)" = $xref
        }

        if ($xref.xref)
        {
          $ByCode.Items += $item | select-object *, @{l="xref";e={$xref.xref}}
        }
        else
        {
          $ByCode.Items += $item | select-object *
        }
      }

      $vm.Warnings.ByCode += $ByCode

    }
  }

  return [PSCustomObject]$vm
}
