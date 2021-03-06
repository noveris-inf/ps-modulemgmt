<#
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string[]]$Stages
)

########
# Global settings
$InformationPreference = "Continue"
$ErrorActionPreference = "Stop"
Set-StrictMode -Version 2

########
# Modules
Remove-Module Noveris.ModuleMgmt -EA SilentlyContinue
Import-Module ./source/Noveris.ModuleMgmt/Noveris.ModuleMgmt.psm1

Remove-Module noveris.build -EA SilentlyContinue
Import-Module -Name noveris.build -RequiredVersion (Install-PSModuleWithSpec -Name noveris.build -Major 0 -Minor 5)

########
# Capture version information
$version = @(
    $Env:GITHUB_REF,
    $Env:BUILD_SOURCEBRANCH,
    $Env:CI_COMMIT_TAG,
    $Env:BUILD_VERSION,
    "v0.1.0"
) | Select-ValidVersions -First -Required

Write-Information "Version:"
$version

Use-BuildDirectories -Directories @(
    "assets"
)

########
# Build stage
Invoke-BuildStage -Name "Build" -Filters $Stages -Script {
    # Template PowerShell module definition
    Write-Information "Templating Noveris.ModuleMgmt.psd1"
    Format-TemplateFile -Template source/Noveris.ModuleMgmt.psd1.tpl -Target source/Noveris.ModuleMgmt/Noveris.ModuleMgmt.psd1 -Content @{
        __FULLVERSION__ = $version.PlainVersion
    }

    # Test the module manifest
    Write-Information "Testing module manifest"
    Test-ModuleManifest source/Noveris.ModuleMgmt/Noveris.ModuleMgmt.psd1
}

Invoke-BuildStage -Name "Publish" -Filters $Stages -Script {
    $owner = "noveris-inf"
    $repo = "ps-modulemgmt"

    $releaseParams = @{
        Owner = $owner
        Repo = $repo
        Name = ("Release " + $version.Tag)
        TagName = $version.Tag
        Draft = $false
        Prerelease = $version.IsPrerelease
        Token = $Env:GITHUB_TOKEN
    }

    Write-Information "Creating release"
    $release = New-GithubRelease @releaseParams

    Get-ChildItem assets |
        ForEach-Object { $_.FullName } |
        Add-GithubReleaseAsset -Owner $owner -Repo $repo -ReleaseId $release.Id -Token $Env:GITHUB_TOKEN -Verbose

    # Publish module
    Publish-Module -Path ./source/Noveris.ModuleMgmt -NuGetApiKey $Env:NUGET_API_KEY
}
