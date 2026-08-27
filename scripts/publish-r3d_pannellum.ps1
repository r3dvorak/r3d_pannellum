[CmdletBinding()]
param(
    [string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$ToolsRoot = "D:\1DEV\_tools",
    [string]$EnvFile = ".env.release.local",
    [ValidateSet('BuildOnly', 'DryRun')]
    [string]$Mode = 'BuildOnly',
    [switch]$DryRun,
    [switch]$NoPublish,
    [switch]$SkipBuild,
    [string]$BuildOutputRoot = "",
    [string]$ValidatedArtifactPath = "",
    [string]$ValidatedArtifactSha256 = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$resolvedProjectRoot = (Resolve-Path -LiteralPath $ProjectRoot).Path
$expectedRoot = 'D:\1DEV\pkgs\r3d_pannellum'
$effectiveMode = $Mode
if ($NoPublish) {
    if ($PSBoundParameters.ContainsKey('Mode') -and $Mode -ne 'BuildOnly') {
        throw "-NoPublish cannot be combined with publication mode '$Mode'."
    }
    $effectiveMode = 'BuildOnly'
}
if ($DryRun) {
    if ($NoPublish -or ($PSBoundParameters.ContainsKey('Mode') -and $Mode -ne 'DryRun')) {
        throw "-DryRun cannot be combined with -NoPublish or publication mode '$Mode'."
    }
    $effectiveMode = 'DryRun'
}
if ($BuildOutputRoot -and $effectiveMode -ne 'BuildOnly') {
    throw "-BuildOutputRoot is supported only in BuildOnly mode."
}
if ($effectiveMode -eq 'Live' -and ([string]::IsNullOrWhiteSpace($ValidatedArtifactPath) -or [string]::IsNullOrWhiteSpace($ValidatedArtifactSha256))) {
    throw 'Live publication must be started through scripts/release-r3d_pannellum.ps1 with a validated artifact receipt.'
}

if (-not $SkipBuild) {
    $buildArgs = @{ ProjectRoot = $resolvedProjectRoot }
    if ($BuildOutputRoot) {
        $buildArgs['OutputRoot'] = $BuildOutputRoot
        $buildArgs['NoArchive'] = $true
    }
    & (Join-Path $resolvedProjectRoot "scripts\build-r3d_pannellum.ps1") @buildArgs
    if (-not $?) { throw "build-r3d_pannellum.ps1 failed." }
}

$validationArgs = @{ ProjectRoot = $resolvedProjectRoot }
if ($BuildOutputRoot) { $validationArgs['DistRoot'] = $BuildOutputRoot }
& (Join-Path $resolvedProjectRoot "scripts\validate-r3d_pannellum.ps1") @validationArgs
if (-not $?) { throw "validate-r3d_pannellum.ps1 failed." }

if ($effectiveMode -eq 'BuildOnly') {
    Write-Host "BuildOnly complete: publication stages were not invoked."
    return
}

if ($effectiveMode -eq 'Live') {
    # Live is deliberately impossible without the identity receipt created by
    # release-r3d_pannellum.ps1 after its guarded build / test sequence.
    if ($resolvedProjectRoot.TrimEnd('\','/') -cne $expectedRoot) { throw "Live release root mismatch: $resolvedProjectRoot" }
    $gitRoot = (& git -C $resolvedProjectRoot rev-parse --show-toplevel).Trim()
    if ($LASTEXITCODE -ne 0 -or [System.IO.Path]::GetFullPath($gitRoot).TrimEnd('\','/') -cne $expectedRoot) { throw 'Live release Git root mismatch.' }
    if ((& git -C $resolvedProjectRoot branch --show-current).Trim() -ne 'main') { throw 'Live publication requires branch main.' }
    $remote = (& git -C $resolvedProjectRoot config --get remote.origin.url).Trim()
    $normalizedRemote = $remote -replace '^git@github\.com:', 'https://github.com/' -replace '\.git/?$', '.git'
    if ($normalizedRemote -ne 'https://github.com/r3dvorak/r3d_pannellum.git') { throw "Live publication requires canonical origin; got '$remote'." }
    if ((& git -C $resolvedProjectRoot status --porcelain --untracked-files=all)) { throw 'Live publication requires a clean release working tree.' }
    if ((& git -C $resolvedProjectRoot rev-parse --abbrev-ref '@{upstream}').Trim() -ne 'origin/main') { throw 'Live publication requires upstream origin/main.' }
    $sync = ((& git -C $resolvedProjectRoot rev-list --left-right --count 'HEAD...@{upstream}') -join ' ').Trim() -split '\s+'
    if ($sync.Count -ne 2 -or $sync[0] -ne '0' -or $sync[1] -ne '0') { throw 'Live publication requires main synchronized with origin/main.' }
    $artifact = [System.IO.Path]::GetFullPath($ValidatedArtifactPath)
    $expectedArtifact = Join-Path $resolvedProjectRoot ('04_dist\pkg_r3d_pannellum-' + ((Get-Content -LiteralPath (Join-Path $resolvedProjectRoot 'VERSION') -Raw).Trim()) + '.zip')
    if ($artifact -cne $expectedArtifact -or -not (Test-Path -LiteralPath $artifact -PathType Leaf)) { throw 'Validated artifact path is not the prepared package artifact.' }
    $actualHash = (Get-FileHash -LiteralPath $artifact -Algorithm SHA256).Hash
    if ($actualHash -cne $ValidatedArtifactSha256.ToUpperInvariant()) { throw 'Validated artifact SHA-256 changed; refusing publication.' }
    $publishedMetadata = Join-Path $resolvedProjectRoot '05_updates\pkg_r3d_pannellum.xml'
    if (-not (Test-Path -LiteralPath $publishedMetadata -PathType Leaf)) { throw 'Published-version metadata is required for live publication.' }
    [xml]$publishedXml = Get-Content -LiteralPath $publishedMetadata -Raw
    $publishedVersion = [version]$publishedXml.updates.update.version
    $preparedVersion = [version]((Get-Content -LiteralPath (Join-Path $resolvedProjectRoot 'VERSION') -Raw).Trim())
    if ($preparedVersion -le $publishedVersion) { throw "Prepared version $preparedVersion must be newer than published version $publishedVersion." }
    & (Join-Path $resolvedProjectRoot 'tests\run-tests.ps1') -ProjectRoot $resolvedProjectRoot
    if (-not $?) { throw 'Regression suite failed before live publication.' }
    if ((Get-FileHash -LiteralPath $artifact -Algorithm SHA256).Hash -cne $ValidatedArtifactSha256.ToUpperInvariant()) {
        throw 'Validated artifact changed after regression tests; refusing publication.'
    }
}

$resolvedToolsRoot = (Resolve-Path -LiteralPath $ToolsRoot).Path
$resolvedEnvPath = if ($effectiveMode -eq 'Live') {
    Join-Path $resolvedToolsRoot '.env'
} elseif ([System.IO.Path]::IsPathRooted($EnvFile)) {
    $EnvFile
} else {
    Join-Path $resolvedProjectRoot $EnvFile
}

$createArgs = @{
    ProjectRoot = $resolvedProjectRoot
    EnvFile = $resolvedEnvPath
}
if ($effectiveMode -eq 'DryRun') { $createArgs["DryRun"] = $true }
& (Join-Path $resolvedToolsRoot "31-create-download.ps1") @createArgs
if (-not $?) { throw "31-create-download.ps1 failed." }

$updateArgs = @{
    ProjectRoot = $resolvedProjectRoot
    EnvFile = $resolvedEnvPath
}
if ($effectiveMode -eq 'DryRun') { $updateArgs["DryRun"] = $true }
& (Join-Path $resolvedToolsRoot "32-publish-updateserver.ps1") @updateArgs
if (-not $?) { throw "32-publish-updateserver.ps1 failed." }
