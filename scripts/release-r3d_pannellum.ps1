[CmdletBinding()]
param(
    [string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$ToolsRoot = "D:\1DEV\_tools",
    [string]$EnvFile = ".env.release.local",
    [ValidateSet('patch', 'minor', 'major')]
    [string]$Bump = 'patch',
    [string]$Version,
    [ValidateSet('BuildOnly', 'DryRun', 'Live')]
    [string]$PublicationMode = 'BuildOnly',
    [switch]$NoPush,
    [switch]$NoPublish
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Invoke-Git {
    param([string[]]$Args)
    & git @Args
    if ($LASTEXITCODE -ne 0) {
        throw ("git {0} failed with exit code {1}" -f ($Args -join ' '), $LASTEXITCODE)
    }
}

function Get-GitOutput {
    param([string[]]$Args)
    $output = & git @Args
    if ($LASTEXITCODE -ne 0) {
        throw ("git {0} failed with exit code {1}" -f ($Args -join ' '), $LASTEXITCODE)
    }
    return @($output)
}

$resolvedProjectRoot = (Resolve-Path -LiteralPath $ProjectRoot).Path
$expectedRoot = [System.IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot)).TrimEnd('\', '/')
$gitRoot = ((Get-GitOutput -Args @('-C', $resolvedProjectRoot, 'rev-parse', '--show-toplevel')) -join '').Trim()
$normalizedGitRoot = [System.IO.Path]::GetFullPath($gitRoot).TrimEnd('\', '/')
if ($normalizedGitRoot -cne $expectedRoot -or $resolvedProjectRoot.TrimEnd('\', '/') -cne $expectedRoot) {
    throw "Release root mismatch. Expected '$expectedRoot', got '$normalizedGitRoot'."
}

$currentBranch = ((Get-GitOutput -Args @('-C', $resolvedProjectRoot, 'branch', '--show-current')) -join '').Trim()
if ($currentBranch -ne 'main') {
    throw "Release flow expects branch main, got '$currentBranch'."
}

# Check identity before any fetch, version write, build, commit, push, or publication.
$origin = ((Get-GitOutput -Args @('-C', $resolvedProjectRoot, 'config', '--get', 'remote.origin.url')) -join '').Trim()
$canonicalOrigin = ($origin -replace '^git@github\.com:', 'https://github.com/' -replace '^ssh://git@github\.com/', 'https://github.com/' -replace '\.git/?$', '.git')
if ($canonicalOrigin -ne 'https://github.com/r3dvorak/r3d_pannellum.git') { throw "Release flow requires canonical origin; got '$origin'." }

$initialStatus = @(Get-GitOutput -Args @('-C', $resolvedProjectRoot, 'status', '--porcelain', '--untracked-files=all'))
if ($initialStatus.Count -ne 0) {
    throw "Release flow requires a clean working tree. Commit intended source changes separately before releasing."
}

Invoke-Git -Args @('-C', $resolvedProjectRoot, 'fetch', '--no-tags', 'origin', 'main')
$upstream = ((Get-GitOutput -Args @('-C', $resolvedProjectRoot, 'rev-parse', '--abbrev-ref', '@{upstream}')) -join '').Trim()
if ($upstream -ne 'origin/main') {
    throw "Release flow requires upstream origin/main, got '$upstream'."
}
$syncCounts = ((Get-GitOutput -Args @('-C', $resolvedProjectRoot, 'rev-list', '--left-right', '--count', 'HEAD...@{upstream}')) -join '').Trim() -split '\s+'
if ($syncCounts.Count -ne 2 -or $syncCounts[0] -ne '0' -or $syncCounts[1] -ne '0') {
    throw "Local main must match origin/main before release (ahead=$($syncCounts[0]), behind=$($syncCounts[1]))."
}

if ($NoPublish) {
    if ($PSBoundParameters.ContainsKey('PublicationMode') -and $PublicationMode -ne 'BuildOnly') {
        throw "-NoPublish cannot be combined with publication mode '$PublicationMode'."
    }
    $PublicationMode = 'BuildOnly'
}
if ($NoPush -and $PublicationMode -eq 'Live') {
    throw "Live publication requires the validated release commit to be pushed."
}

$preparedVersion = [version]((Get-Content -LiteralPath (Join-Path $resolvedProjectRoot 'VERSION') -Raw).Trim())
$releaseState = Get-Content -LiteralPath (Join-Path $resolvedProjectRoot 'release-state.json') -Raw | ConvertFrom-Json
$publishedVersion = [version]$releaseState.publishedVersion
if ($preparedVersion -le $publishedVersion) { throw "Prepared version $preparedVersion must be newer than published version $publishedVersion." }
$newVersion = $preparedVersion.ToString()
if (-not [string]::IsNullOrWhiteSpace($Version)) {
    $requestedVersion = [version]$Version.Trim()
    if ($requestedVersion -le $publishedVersion -or $requestedVersion -lt $preparedVersion) { throw "Requested version $requestedVersion is not newer than published/prepared state." }
    if ($requestedVersion -gt $preparedVersion) { $newVersion = (& (Join-Path $resolvedProjectRoot "scripts\uptick-r3d_pannellum.ps1") -ProjectRoot $resolvedProjectRoot -Version $requestedVersion.ToString() | Select-Object -Last 1).Trim() }
}

& (Join-Path $resolvedProjectRoot "scripts\publish-r3d_pannellum.ps1") `
    -ProjectRoot $resolvedProjectRoot `
    -Mode BuildOnly
if (-not $?) { throw "Pre-commit build and validation failed." }

& (Join-Path $resolvedProjectRoot "tests\run-tests.ps1") -ProjectRoot $resolvedProjectRoot
if (-not $?) { throw "Pre-commit regression suite failed." }
$validatedArtifactPath = Join-Path $resolvedProjectRoot ("04_dist\pkg_r3d_pannellum-{0}.zip" -f $newVersion)
if (-not (Test-Path -LiteralPath $validatedArtifactPath -PathType Leaf)) { throw "Validated package artifact missing: $validatedArtifactPath" }
$validatedArtifactSha256 = (Get-FileHash -LiteralPath $validatedArtifactPath -Algorithm SHA256).Hash

Invoke-Git -Args @('-C', $resolvedProjectRoot, 'diff', '--check')

if ($PublicationMode -ne 'BuildOnly') {
    & (Join-Path $resolvedProjectRoot "scripts\publish-r3d_pannellum.ps1") `
        -ProjectRoot $resolvedProjectRoot `
        -ToolsRoot $ToolsRoot `
        -EnvFile $EnvFile `
        -Mode DryRun `
        -SkipBuild
    if (-not $?) { throw "Pre-commit publication dry-run failed." }
}

$intendedFiles = @(
    'project.json',
    'VERSION',
    '01_src/pkg_r3d_pannellum.xml',
    '01_src/script.pkg_r3d_pannellum.php'
)
$changedFiles = @(Get-GitOutput -Args @('-C', $resolvedProjectRoot, 'status', '--porcelain', '--untracked-files=all') | ForEach-Object {
    if ($_.Length -ge 4) { $_.Substring(3).Trim('"') }
})
$unexpectedFiles = @($changedFiles | Where-Object { $_ -notin $intendedFiles })
if ($unexpectedFiles.Count -gt 0) {
    throw "Unexpected release changes detected: $($unexpectedFiles -join ', ')"
}
foreach ($path in $intendedFiles) {
    if ($path -notin $changedFiles) {
        throw "Expected release change missing: $path"
    }
}

Invoke-Git -Args (@('-C', $resolvedProjectRoot, 'add', '--') + $intendedFiles)
Invoke-Git -Args @('-C', $resolvedProjectRoot, 'diff', '--cached', '--check')
Invoke-Git -Args @('-C', $resolvedProjectRoot, 'commit', '-m', ("v{0} release" -f $newVersion))

if (-not $NoPush) {
    Invoke-Git -Args @('-C', $resolvedProjectRoot, 'push', 'origin', 'main')
}

if ($PublicationMode -eq 'Live') {
    & (Join-Path $resolvedProjectRoot "scripts\publish-r3d_pannellum.ps1") `
        -ProjectRoot $resolvedProjectRoot `
        -ToolsRoot $ToolsRoot `
        -EnvFile $EnvFile `
        -Mode $PublicationMode `
        -ValidatedArtifactPath $validatedArtifactPath `
        -ValidatedArtifactSha256 $validatedArtifactSha256 `
        -SkipBuild
    if (-not $?) { throw "Publication stage failed." }
}
