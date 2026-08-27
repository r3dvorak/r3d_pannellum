[CmdletBinding()]
param(
    [string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot),
    [ValidateSet('patch', 'minor', 'major')]
    [string]$Bump = 'patch',
    [string]$Version
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Fail {
    param([string]$Message)
    Write-Error $Message
    exit 1
}

function Get-CurrentVersion {
    param([string]$ProjectJsonPath)

    try {
        $project = Get-Content -LiteralPath $ProjectJsonPath -Raw | ConvertFrom-Json
    }
    catch {
        Fail "project.json is not valid JSON: $($_.Exception.Message)"
    }

    $current = [string]$project.project.defaults.version
    if ([string]::IsNullOrWhiteSpace($current)) {
        Fail "project.json is missing project.defaults.version"
    }

    return $current.Trim()
}

function Get-NextVersion {
    param(
        [string]$CurrentVersion,
        [string]$Bump
    )

    if ($CurrentVersion -notmatch '^(\d+)\.(\d+)\.(\d+)$') {
        Fail "Unsupported version format: $CurrentVersion"
    }

    $major = [int]$Matches[1]
    $minor = [int]$Matches[2]
    $patch = [int]$Matches[3]

    switch ($Bump) {
        'major' {
            $major++
            $minor = 0
            $patch = 0
        }
        'minor' {
            $minor++
            $patch = 0
        }
        default {
            $patch++
        }
    }

    return ("{0}.{1}.{2}" -f $major, $minor, $patch)
}

function Update-TextFile {
    param(
        [string]$Path,
        [string]$Pattern,
        [string]$Replacement
    )

    $text = Get-Content -LiteralPath $Path -Raw
    $updated = $text -replace $Pattern, $Replacement
    if ($updated -eq $text) {
        Fail "No replacement applied in $Path"
    }

    Set-Content -LiteralPath $Path -Value $updated
}

$projectRoot = (Resolve-Path -LiteralPath $ProjectRoot).Path
$projectJsonPath = Join-Path $projectRoot "project.json"
$versionPath = Join-Path $projectRoot "VERSION"
$packageXmlPath = Join-Path $projectRoot "01_src\pkg_r3d_pannellum.xml"
$packageScriptPath = Join-Path $projectRoot "01_src\script.pkg_r3d_pannellum.php"
$moduleXmlPath = Join-Path $projectRoot "01_src\packages\mod_r3d_pannellum\mod_r3d_pannellum.xml"
$pluginXmlPath = Join-Path $projectRoot "01_src\packages\plg_system_r3d_adminui\r3d_adminui.xml"

foreach ($path in @($projectJsonPath, $versionPath, $packageXmlPath, $packageScriptPath, $moduleXmlPath, $pluginXmlPath)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        Fail "Missing file: $path"
    }
}

$currentVersion = Get-CurrentVersion -ProjectJsonPath $projectJsonPath
$newVersion = if ([string]::IsNullOrWhiteSpace($Version)) {
    Get-NextVersion -CurrentVersion $currentVersion -Bump $Bump
} else {
    $trimmed = $Version.Trim()
    if ($trimmed -notmatch '^\d+\.\d+\.\d+$') {
        Fail "Invalid explicit version: $Version"
    }
    $trimmed
}

if ($newVersion -eq $currentVersion) {
    Fail "Version already set to $newVersion"
}

Update-TextFile -Path $projectJsonPath -Pattern '"version"\s*:\s*"[^"]+"' -Replacement ('"version": "{0}"' -f $newVersion)
Set-Content -LiteralPath $versionPath -Value $newVersion
Update-TextFile -Path $packageXmlPath -Pattern '<version>[^<]+</version>' -Replacement ("<version>{0}</version>" -f $newVersion)
Update-TextFile -Path $packageScriptPath -Pattern '@version\s+\d+\.\d+\.\d+' -Replacement ("@version     {0}" -f $newVersion)
Update-TextFile -Path $moduleXmlPath -Pattern '<version>[^<]+</version>' -Replacement ("<version>{0}</version>" -f $newVersion)
Update-TextFile -Path $pluginXmlPath -Pattern '<version>[^<]+</version>' -Replacement ("<version>{0}</version>" -f $newVersion)

Write-Host "Upticked package version: $currentVersion -> $newVersion"
Write-Output $newVersion
