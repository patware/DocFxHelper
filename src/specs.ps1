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

#>
. $PSScriptRoot/specs.include.ps1

$script:SpecsVersions = @(
    [ordered]@{version=[Version]"0.1.6"; title="Using drops folder"}
    [ordered]@{version=[Version]"0.1.7"; title="Merging resources"}
    [ordered]@{version=[Version]"0.1.8"; title="New script parameter names"}
    [ordered]@{version=[Version]"0.1.9"; title="Copy-Robo instead of robocopy"}
    [ordered]@{version=[Version]"0.1.10"; title="Checking if specs are valid"}
)

$script:SpecsVersion = $SpecsVersions[-1]
Write-Host "specs.ps1 Version [$($SpecsVersion.Version)] $($SpecsVersion.title)"

$DocFxHelperFolders = @{
    sources = (Join-Path $WorkspacePath -ChildPath "sources")
    converted = (Join-Path $WorkspacePath -ChildPath "converted")
    staging = (Join-Path $WorkspacePath -ChildPath "staging")
}

function Write-Progress2
{
    param($Activity, $Status, $Id, $ParentId, $PercentageComplete, [switch]$Completed)
    $wp = @{
        Activity = $Activity
        Status = $Status
        Id = $Id
    }

    if ($ParentId)
    {
        $wp.ParentId = $ParentId
    }

    if ($PercentageComplete)
    {
        $wp.PercentageComplete = $PercentageComplete
    }
    if ($Completed)
    {
        $wp.Completed = $Completed
    }

    Write-Progress @wp

    $wh = $Activity
    
    if ($Status)
    {
        $wh = "$wh - $Status"
    }

    Write-Host $wh
    
}

Write-Host "Checking out the Workspace folders"
foreach($key in $DocFxHelperFolders.Keys)
{
    Write-Host " - $($key)"
    if (!(Test-Path $DocFxHelperFolders."$key"))
    {
        new-Item $DocFxHelperFolders."$key" -ItemType Directory
    }
}

$DocFxHelperFiles = @{
    docfx_json = (join-Path $DocFxHelperFolders.staging -ChildPath "docfx.json")
    docfxhelper_json = (join-Path $DocFxHelperFolders.staging -ChildPath "docfxhelper.json")
}

# ------------------------------------------------------------------------

Write-Progress2 -Activity "Fetching Doc Specs from the Drops folders" -Status "Looking for specs.docs.json" -Id 0
$specs_docs_json_list = Get-ChildItem -Path $DropsPath -Filter "specs.docs.json" -Recurse

if ($specs_docs_json_list.Count -eq 0)
{
    Write-Warning "No specs.docs.json file found in $DropsPath"
}
else
{

    Write-Progress2 -Activity "Fetching Doc Specs from the Drops folders" -Status "Building [DocSpecs] object from found specs.docs.json" -Id 0    
    $specs = $specs_docs_json_list | ConvertFrom-Specs

    if ($null -eq $specs.Main -and $specs.All.Count -eq 0)
    {
        Write-Warning "No specs found, nothing to do"
    }
    else
    {
        # ------------------------------------------------------------------------
        Write-Progress2 -Activity "Copy Doc Resources to DocFxHelper Folder Sources" -Id 0
        
        if ($specs.Main)
        {
            Write-Progress2 -Activity "Copying Main spec" -id 1 -ParentId 0

            $source = $specs.Main.Path
            $destination = (Join-Path $DocFxHelperFolders.sources -ChildPath $specs.Main.Path.Name)

            #& robocopy $source $destination  /MIR /FP /V
            Copy-Robo -Source $source -Destination $destination -Mirror -ShowFullPath -Verbose
        }
        Write-Progress2 -Activity "Copying Main spec" -id 1 -ParentId 0 -Completed
        

        $counter = 0
        foreach($spec in $specs.Ordered)
        {
            <#
                $spec = $specs.Ordered | select-object -first 1
                $spec = $specs.Ordered | select-object -first 1 -skip 1
                $spec
            #>
            $counter++
            Write-Progress2 -Activity "Copying $($spec.Id)" -Status "[$($counter)/$($specs.Ordered.Count)]" -Id 1 -ParentId 0 -PercentComplete (100.0 * ($counter-1) / $specs.Ordered.Count)

            $source = $spec.Path
            $destination = (Join-Path $DocFxHelperFolders.sources -ChildPath $spec.Path.Name)

            Copy-Robo -Source $source -Destination $destination -Mirror -ShowFullPath -Verbose
            #& robocopy $source $destination  /MIR /FP /V

        }

        Write-Progress2 -Activity "Copying done" -Id 1 -ParentId 0 -Completed


        # ------------------------------------------------------------------------
        Write-Progress2 -Activity "Converting Doc Resources" -Id 0

        Write-Progress2 -Activity "Converting Main" -Status "Main" -Id 1 -ParentId 0
        $source = join-path $DocFxHelperFolders.sources -ChildPath $specs.Main.Path.Name
        $destination = join-path $DocFxHelperFolders.converted -ChildPath $specs.Main.Path.Name
        #& robocopy $source $destination  /MIR /FP /V
        Copy-Robo -Source $source -Destination $destination -Mirror -ShowFullPath -Verbose

        $counter = 0
        foreach($spec in $specs.Ordered)
        {
            <#
                $spec = $specs.Ordered | select-object -first 1
                $spec = $specs.Ordered | select-object -first 1 -skip 1
                $spec = $specs.Ordered | select-object -first 1 -skip 2
                $spec
            #>
            $counter++
            Write-Progress2 -Activity "Converting $($spec.Id)" -Status "[$($counter)/$($specs.Ordered.Count)]" -Id 1 -ParentId 0 -PercentComplete (100.0 * ($counter-1) / $specs.Ordered.Count)

            $a = @{}

            if ($specs.Main.UseModernTemplate)
            {
                $a.UseModernTemplate = [switch]$true
            }

            Convert-DocResource `
                -Spec $spec `
                -Path (Join-Path $DocFxHelperFolders.Sources -ChildPath $Spec.Path.Name) `
                -Destination (Join-Path $DocFxHelperFolders.converted -ChildPath $Spec.Path.Name) `
                @a

        }

        Write-Progress2 -Activity "Conversion Done" -Id 1 -ParentId 0 -Completed

        # ------------------------------------------------------------------------

        Write-Progress2 -Activity "Generating DocFx.json for resources" -Id 0
        Write-Progress2 -Activity "New Docfx.json" -Id 1 -ParentId 0
        if ($specs.Main.DocFx_Json)
        {
            New-DocFx `
                -Target $DocFxHelperFolders.Staging `
                -BaseDocFxPath (Join-Path $DocFxHelperFolders.converted -ChildPath $specs.Main.Path.Name -AdditionalChildPath $specs.Main.DocFx_Json.Name)
        }
        else
        {
            New-DocFx `
                -Target $DocFxHelperFolders.Staging `
                -BaseDocFxConfig "{}"
        }


        $counter = 0
        foreach($spec in $specs.Ordered)
        {
            <#
                $spec = $specs.Ordered | select-object -first 1
                $spec = $specs.Ordered | select-object -first 1 -skip 1
                $spec = $specs.Ordered | select-object -first 1 -skip 2
                $spec
            #>
            $counter++
            Write-Progress2 -Activity "Adding Resource $($spec.Id)" -Status "[$($counter)/$($specs.Ordered.Count)]" -Id 1 -ParentId 0 -PercentComplete (100.0 * ($counter-1) / $specs.Ordered.Count)

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
        Write-Progress2 -Activity "Adding Resource"  -Id 1 -ParentId 0 -Completed

        # ------------------------------------------------------------------------
        Write-Progress2 -Activity "Generating documentation from templates" -Id 0
        $counter = 0
        foreach($t in $specs.Templates)
        {
            <#
                $t = $specs.Templates | select-object -first 1
                $t
            #>
            $counter++
            Write-Progress2 -Activity "Generating file from template" -Status "$($t.Name) [$($counter)/$($specs.Templates.Count)]" -Id 1 -ParentId 0 -PercentComplete (100.0 * ($counter-1) / $specs.Templates.Count)
            Write-Host $t.Name
            $source = join-path -Path $DocFxHelperFolders.converted -ChildPath $t.Spec.Path.Name -AdditionalChildPath $t.Template
            $destination = join-path -Path $DocFxHelperFolders.staging -ChildPath $t.Spec.Path.Name -AdditionalChildPath $t.Dest
            Write-Host "   view model: $($DocFxHelperFiles.docfxhelper_json)"
            Write-Host "     template: $($source)"
            Write-Host "  destination: $($destination)"
            $folder = (split-path $destination)
            if (!(Test-Path $folder))
            {
                New-Item $folder -itemType Directory -Force
            }
            ConvertTo-PoshstacheTemplate -InputFile $source -ParametersObject (Get-Content $DocFxHelperFiles.docfxhelper_json | ConvertFrom-Json -AsHashtable) -HashTable | set-content $destination -Force
        }

        Write-Host "File generation from templates done"
        Write-Progress2 -Activity "Generating file from template" -Id 1 -ParentId 0 -Completed




        # ------------------------------------------------------------------------
        Write-Progress2 -Activity "DryRun Building DocFx.json" -Id 0

        push-location $DocFxHelperFolders.staging
        if (test-path "docfx.build.log")
        {
            remove-item "docfx.build.log"
        }
        if (test-path "dryRun_site")
        {
            remove-item "dryRun_site" -Recurse -Force
        }
        if (test-path "dryRun_debug")
        {
            remove-item "dryRun_debug" -Recurse -Force
        }
        & docfx build --log "docfx.build.log" --verbose --output "dryRun_site" --debugOutput "dryRun_debug" --dryRun
        Pop-Location

        $docfx_build_log = Join-Path $DocFxHelperFolders.staging -ChildPath "./docfx.build.log"

        $docfx_build = get-content $docfx_build_log  | convertfrom-json -AsHashtable
        $docfx_build | group-object severity | select-object Name, Count | out-host

        Write-Host "This will be helpful for helping out writing templates:"
        Write-Host "docfxhelper view model: [$($DocFxHelperFiles.docfxhelper_json)]"
        Write-Host "docfxHelper global variable: [`$DocfxHelper)]"
        $DocfxHelper | out-host

        # ------------------------------------------------------------------------
        Write-Progress2 -Activity "Building DocFx.json" -Id 0

        push-location $DocFxHelperFolders.staging
        if (test-path "docfx.build.log")
        {
            remove-item "docfx.build.log"
        }
        if (test-path "dryRun_site")
        {
            remove-item "dryRun_site" -Recurse -Force
        }
        if (test-path "dryRun_debug")
        {
            remove-item "dryRun_debug" -Recurse -Force
        }

        & docfx build --log "docfx.build.log" --verbose --debugOutput "_debug" 
        $source = (get-item _site).FullName
        $destination = $SitePath.Path

        Write-Host "Site generated.  Copying to final destination"
        Write-Host "         site: $($source)"
        Write-Host "  destination: $($destination)"
        #& robocopy $source $destination /MIR /FP /V
        Copy-Robo -Source $source -Destination $destination -Mirror -ShowFullPath -Verbose
        Pop-Location

        Write-Progress2 -Id 0 -Completed
    }
}