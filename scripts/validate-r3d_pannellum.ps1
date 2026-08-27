[CmdletBinding()]
param(
    [string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$DistRoot = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

function Assert-Equal([string]$Label, [string]$Expected, [string]$Actual) {
    if ($Expected -cne $Actual) {
        throw "$Label mismatch: expected '$Expected', got '$Actual'."
    }
}

function Get-XmlVersion([string]$Path) {
    [xml]$document = Get-Content -LiteralPath $Path -Raw
    $version = $document.SelectSingleNode('/extension/version')
    if (-not $version) { throw "Missing manifest version: $Path" }
    return $version.InnerText.Trim()
}

function Get-ZipEntryText([System.IO.Compression.ZipArchive]$Archive, [string]$Name) {
    $entry = $Archive.GetEntry($Name)
    if (-not $entry) { throw "Missing ZIP entry: $Name" }
    $stream = $entry.Open()
    $reader = [System.IO.StreamReader]::new($stream)
    try { return $reader.ReadToEnd() } finally { $reader.Dispose(); $stream.Dispose() }
}

function Get-NestedManifestVersion([System.IO.Compression.ZipArchive]$Package, [string]$EntryName, [string]$ManifestName) {
    $entry = $Package.GetEntry($EntryName)
    if (-not $entry) { throw "Missing nested ZIP: $EntryName" }
    $entryStream = $entry.Open()
    $memory = [System.IO.MemoryStream]::new()
    try {
        $entryStream.CopyTo($memory)
        $memory.Position = 0
        $nested = [System.IO.Compression.ZipArchive]::new($memory, [System.IO.Compression.ZipArchiveMode]::Read, $true)
        try { [xml]$manifest = Get-ZipEntryText -Archive $nested -Name $ManifestName } finally { $nested.Dispose() }
        return $manifest.extension.version.Trim()
    }
    finally { $entryStream.Dispose(); $memory.Dispose() }
}

function Assert-NestedEntry([System.IO.Compression.ZipArchive]$Package, [string]$EntryName, [string]$RequiredName) {
    $entry = $Package.GetEntry($EntryName)
    if (-not $entry) { throw "Missing nested ZIP: $EntryName" }
    $entryStream = $entry.Open()
    $memory = [System.IO.MemoryStream]::new()
    try {
        $entryStream.CopyTo($memory)
        $memory.Position = 0
        $nested = [System.IO.Compression.ZipArchive]::new($memory, [System.IO.Compression.ZipArchiveMode]::Read, $true)
        try {
            if (-not $nested.GetEntry($RequiredName)) {
                throw "Missing nested entry '$RequiredName' in '$EntryName'."
            }
        }
        finally { $nested.Dispose() }
    }
    finally { $entryStream.Dispose(); $memory.Dispose() }
}

$root = (Resolve-Path -LiteralPath $ProjectRoot).Path
$dist = if ([string]::IsNullOrWhiteSpace($DistRoot)) {
    Join-Path $root '04_dist'
} elseif ([System.IO.Path]::IsPathRooted($DistRoot)) {
    [System.IO.Path]::GetFullPath($DistRoot)
} else {
    [System.IO.Path]::GetFullPath((Join-Path $root $DistRoot))
}

$project = Get-Content -LiteralPath (Join-Path $root 'project.json') -Raw | ConvertFrom-Json
$packageVersion = ([string]$project.project.defaults.version).Trim()
$versionFile = (Get-Content -LiteralPath (Join-Path $root 'VERSION') -Raw).Trim()
$packageManifest = Join-Path $root '01_src\pkg_r3d_pannellum.xml'
$installerScript = Get-Content -LiteralPath (Join-Path $root '01_src\script.pkg_r3d_pannellum.php') -Raw
$moduleVersion = Get-XmlVersion (Join-Path $root '01_src\packages\mod_r3d_pannellum\mod_r3d_pannellum.xml')
$pluginVersion = Get-XmlVersion (Join-Path $root '01_src\packages\plg_system_r3d_adminui\r3d_adminui.xml')

Assert-Equal 'VERSION' $packageVersion $versionFile
Assert-Equal 'Package manifest version' $packageVersion (Get-XmlVersion $packageManifest)
if ($installerScript -notmatch ('@version\s+' + [regex]::Escape($packageVersion) + '(?!\d)')) {
    throw "Installer header does not contain package version $packageVersion."
}
Assert-Equal 'English package language source' `
    (Get-Content -LiteralPath (Join-Path $root '01_src\pkg_r3d_pannellum.en-GB.sys.ini') -Raw) `
    (Get-Content -LiteralPath (Join-Path $root '01_src\language\en-GB\pkg_r3d_pannellum.sys.ini') -Raw)
Assert-Equal 'German package language source' `
    (Get-Content -LiteralPath (Join-Path $root '01_src\pkg_r3d_pannellum.de-DE.sys.ini') -Raw) `
    (Get-Content -LiteralPath (Join-Path $root '01_src\language\de-DE\pkg_r3d_pannellum.sys.ini') -Raw)

$packageZip = Join-Path $dist ("pkg_r3d_pannellum-{0}.zip" -f $packageVersion)
if (-not (Test-Path -LiteralPath $packageZip -PathType Leaf)) {
    throw "Prepared package ZIP missing: $packageZip"
}
$archive = [System.IO.Compression.ZipFile]::OpenRead($packageZip)
try {
    [xml]$zipManifest = Get-ZipEntryText -Archive $archive -Name 'pkg_r3d_pannellum.xml'
    Assert-Equal 'Packaged manifest version' $packageVersion $zipManifest.extension.version.Trim()
    Assert-Equal 'Nested module manifest version' $moduleVersion (Get-NestedManifestVersion $archive 'mod_r3d_pannellum.zip' 'mod_r3d_pannellum.xml')
    Assert-Equal 'Nested plugin manifest version' $pluginVersion (Get-NestedManifestVersion $archive 'plg_system_r3d_adminui.zip' 'r3d_adminui.xml')
    Assert-NestedEntry $archive 'mod_r3d_pannellum.zip' 'media/viewer.js'
    Assert-NestedEntry $archive 'plg_system_r3d_adminui.zip' 'media/adminui.js'
    foreach ($required in @(
        'language/en-GB/pkg_r3d_pannellum.sys.ini',
        'language/de-DE/pkg_r3d_pannellum.sys.ini',
        'script.pkg_r3d_pannellum.php',
        'mod_r3d_pannellum.zip',
        'plg_system_r3d_adminui.zip'
    )) {
        if (-not $archive.GetEntry($required)) { throw "Missing required package entry: $required" }
    }
}
finally { $archive.Dispose() }

Write-Host "Validation OK: package $packageVersion, module $moduleVersion, plugin $pluginVersion"
