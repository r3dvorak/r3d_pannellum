[CmdletBinding()]
param(
    [string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$OutputRoot = "",
    [switch]$NoArchive
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

function Fail {
    param([string]$Message)
    Write-Error $Message
    exit 1
}

function Log {
    param([string]$Message)
    Write-Host $Message
}

function Add-ZipEntry {
    param(
        [System.IO.Compression.ZipArchive]$Archive,
        [string]$SourcePath,
        [string]$EntryName
    )

    $entry = $Archive.CreateEntry($EntryName, [System.IO.Compression.CompressionLevel]::Optimal)
    $entry.LastWriteTime = [System.DateTimeOffset]::new(2000, 1, 1, 0, 0, 0, [System.TimeSpan]::Zero)
    $input = [System.IO.File]::OpenRead($SourcePath)
    $output = $entry.Open()
    try {
        $input.CopyTo($output)
    }
    finally {
        $output.Dispose()
        $input.Dispose()
    }
}

function New-ZipFromDirectoryOrdered {
    param(
        [string]$SourceDir,
        [string]$ZipPath,
        [string]$FirstFileName
    )

    if (Test-Path -LiteralPath $ZipPath) {
        Remove-Item -LiteralPath $ZipPath -Force
    }

    $sourceRoot = (Resolve-Path -LiteralPath $SourceDir).Path
    $files = @(Get-ChildItem -Path $sourceRoot -Recurse -File | Sort-Object FullName)
    $ordered = New-Object System.Collections.Generic.List[object]

    if ($FirstFileName) {
        $preferred = Join-Path $sourceRoot $FirstFileName
        $match = $files | Where-Object { $_.FullName -eq $preferred }
        if ($match) {
            $ordered.Add($match[0])
        }
        $files = @($files | Where-Object { $_.FullName -ne $preferred })
    }

    foreach ($file in $files) {
        $ordered.Add($file)
    }

    $zipStream = [System.IO.File]::Open($ZipPath, [System.IO.FileMode]::Create)
    try {
        $archive = [System.IO.Compression.ZipArchive]::new($zipStream, [System.IO.Compression.ZipArchiveMode]::Create, $false)
        try {
            foreach ($file in $ordered) {
                $rel = $file.FullName.Substring($sourceRoot.Length).TrimStart('\', '/') -replace '\\', '/'
                Add-ZipEntry -Archive $archive -SourcePath $file.FullName -EntryName $rel
            }
        }
        finally {
            $archive.Dispose()
        }
    }
    finally {
        $zipStream.Dispose()
    }
}

function Get-VerifiedExtensionInventory {
    param([string]$SourceDir, [string[]]$RequiredRoots)
    $root = (Resolve-Path -LiteralPath $SourceDir).Path
    $files = @(Get-ChildItem -LiteralPath $root -Recurse -File | ForEach-Object {
        $_.FullName.Substring($root.Length).TrimStart([char]92,[char]47) -replace '\\','/'
    })
    $allowed = @()
    foreach ($entry in $RequiredRoots) {
        $path = Join-Path $root $entry
        if (Test-Path -LiteralPath $path -PathType Leaf) { $allowed += $entry }
        elseif (Test-Path -LiteralPath $path -PathType Container) {
            $allowed += @(Get-ChildItem -LiteralPath $path -Recurse -File | ForEach-Object { $_.FullName.Substring($root.Length).TrimStart([char]92,[char]47) -replace '\\','/' })
        } else { Fail "Required release inventory item missing: $entry" }
    }
    $allowed = @($allowed | Sort-Object -Unique)
    $unexpected = @($files | Where-Object { $_ -notin $allowed })
    if ($unexpected.Count) { Fail "Unexpected extension files rejected by release inventory: $($unexpected -join ', ')" }
    return $allowed
}

function New-ZipFromInventory {
    param([string]$SourceDir, [string[]]$Inventory, [string]$ZipPath, [string]$FirstFileName)
    $root = (Resolve-Path -LiteralPath $SourceDir).Path
    $temp = Join-Path ([System.IO.Path]::GetTempPath()) ('r3d-pan-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $temp | Out-Null
    try {
        foreach ($entry in $Inventory) { $destination = Join-Path $temp $entry; New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force | Out-Null; Copy-Item -LiteralPath (Join-Path $root $entry) -Destination $destination }
        New-ZipFromDirectoryOrdered -SourceDir $temp -ZipPath $ZipPath -FirstFileName $FirstFileName
    } finally { if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Recurse -Force } }
}

function New-ZipFromFilesOrdered {
    param(
        [string[]]$Files,
        [string[]]$EntryNames,
        [string]$ZipPath
    )

    if (Test-Path -LiteralPath $ZipPath) {
        Remove-Item -LiteralPath $ZipPath -Force
    }

    $zipStream = [System.IO.File]::Open($ZipPath, [System.IO.FileMode]::Create)
    try {
        $archive = [System.IO.Compression.ZipArchive]::new($zipStream, [System.IO.Compression.ZipArchiveMode]::Create, $false)
        try {
            for ($i = 0; $i -lt $Files.Count; $i++) {
                Add-ZipEntry -Archive $archive -SourcePath $Files[$i] -EntryName $EntryNames[$i]
            }
        }
        finally {
            $archive.Dispose()
        }
    }
    finally {
        $zipStream.Dispose()
    }
}

function Get-XmlVersion {
    param([string]$Path)

    [xml]$doc = Get-Content -LiteralPath $Path -Raw
    $node = $doc.SelectSingleNode('/extension/version')
    if (-not $node -or [string]::IsNullOrWhiteSpace($node.InnerText)) {
        Fail "Missing <version> in $Path"
    }

    return $node.InnerText.Trim()
}

function Move-OldPackageZips {
    param(
        [string]$DistRoot,
        [string]$Slug,
        [string]$CurrentVersion
    )

    $archiveRoot = Join-Path $DistRoot 'Archiv'
    New-Item -ItemType Directory -Path $archiveRoot -Force | Out-Null

    $currentName = ("pkg_{0}-{1}.zip" -f $Slug, $CurrentVersion)
    Get-ChildItem -Path $DistRoot -Filter ("pkg_{0}-*.zip" -f $Slug) -File |
        Where-Object { $_.Name -ne $currentName } |
        Move-Item -Destination $archiveRoot -Force
}

$projectRoot = (Resolve-Path -LiteralPath $ProjectRoot).Path
$projectJsonPath = Join-Path $projectRoot 'project.json'
$srcRoot = Join-Path $projectRoot '01_src'
$distRoot = if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
    Join-Path $projectRoot '04_dist'
} elseif ([System.IO.Path]::IsPathRooted($OutputRoot)) {
    [System.IO.Path]::GetFullPath($OutputRoot)
} else {
    [System.IO.Path]::GetFullPath((Join-Path $projectRoot $OutputRoot))
}
$moduleDir = Join-Path $srcRoot 'packages\mod_r3d_pannellum'
$pluginDir = Join-Path $srcRoot 'packages\plg_system_r3d_adminui'
$packageLangEn = Join-Path $srcRoot 'language\en-GB\pkg_r3d_pannellum.sys.ini'
$packageLangDe = Join-Path $srcRoot 'language\de-DE\pkg_r3d_pannellum.sys.ini'
$packageLangRootEn = Join-Path $srcRoot 'pkg_r3d_pannellum.en-GB.sys.ini'
$packageLangRootDe = Join-Path $srcRoot 'pkg_r3d_pannellum.de-DE.sys.ini'
$packageXml = Join-Path $srcRoot 'pkg_r3d_pannellum.xml'
$packageScript = Join-Path $srcRoot 'script.pkg_r3d_pannellum.php'

foreach ($path in @($projectJsonPath, $srcRoot, $moduleDir, $pluginDir, $packageLangEn, $packageLangDe, $packageLangRootEn, $packageLangRootDe, $packageXml, $packageScript)) {
    if (-not (Test-Path -LiteralPath $path)) {
        Fail "Missing build input: $path"
    }
}

try {
    $project = Get-Content -LiteralPath $projectJsonPath -Raw | ConvertFrom-Json
}
catch {
    Fail "project.json is not valid JSON: $($_.Exception.Message)"
}

$slug = [string]$project.project.slug
if ([string]::IsNullOrWhiteSpace($slug)) {
    Fail "project.project.slug missing in project.json"
}

$pkgVersion = [string]$project.project.defaults.version
if ([string]::IsNullOrWhiteSpace($pkgVersion)) {
    Fail "project.project.defaults.version missing in project.json"
}

New-Item -ItemType Directory -Path $distRoot -Force | Out-Null
if (-not $NoArchive) {
    Move-OldPackageZips -DistRoot $distRoot -Slug $slug -CurrentVersion $pkgVersion
}

$moduleVersion = Get-XmlVersion -Path (Join-Path $moduleDir 'mod_r3d_pannellum.xml')
$pluginVersion = Get-XmlVersion -Path (Join-Path $pluginDir 'r3d_adminui.xml')

$moduleZip = Join-Path $distRoot ("mod_r3d_pannellum-{0}.zip" -f $moduleVersion)
$pluginZip = Join-Path $distRoot ("plg_system_r3d_adminui-{0}.zip" -f $pluginVersion)
$packageZip = Join-Path $distRoot ("pkg_r3d_pannellum-{0}.zip" -f $pkgVersion)

$moduleInventory = Get-VerifiedExtensionInventory -SourceDir $moduleDir -RequiredRoots @('mod_r3d_pannellum.xml','mod_r3d_pannellum.php','helper.php','fields','tmpl','forms','language','media/demo.jpg','media/viewer.js','media/pannellum/pannellum.js','media/pannellum/pannellum.css')
$pluginInventory = Get-VerifiedExtensionInventory -SourceDir $pluginDir -RequiredRoots @('r3d_adminui.xml','r3d_adminui.php','language','media/adminui.js','media/picker.js','media/picker.css')
New-ZipFromInventory -SourceDir $moduleDir -Inventory $moduleInventory -ZipPath $moduleZip -FirstFileName 'mod_r3d_pannellum.xml'
Log "Built module ZIP: $moduleZip"

New-ZipFromInventory -SourceDir $pluginDir -Inventory $pluginInventory -ZipPath $pluginZip -FirstFileName 'r3d_adminui.xml'
Log "Built plugin ZIP: $pluginZip"

$tempParent = Join-Path $projectRoot '02_build\.tmp'
New-Item -ItemType Directory -Path $tempParent -Force | Out-Null
$tempRoot = Join-Path $tempParent ("r3d_pannellum_pkg_{0}" -f ([guid]::NewGuid().ToString('N')))
New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
try {
    Copy-Item -LiteralPath $packageXml -Destination (Join-Path $tempRoot 'pkg_r3d_pannellum.xml')
    New-Item -ItemType Directory -Path (Join-Path $tempRoot 'language\en-GB') -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $tempRoot 'language\de-DE') -Force | Out-Null
    Copy-Item -LiteralPath $packageLangRootEn -Destination (Join-Path $tempRoot 'pkg_r3d_pannellum.en-GB.sys.ini')
    Copy-Item -LiteralPath $packageLangRootDe -Destination (Join-Path $tempRoot 'pkg_r3d_pannellum.de-DE.sys.ini')
    Copy-Item -LiteralPath $packageLangEn -Destination (Join-Path $tempRoot 'language\en-GB\pkg_r3d_pannellum.sys.ini')
    Copy-Item -LiteralPath $packageLangDe -Destination (Join-Path $tempRoot 'language\de-DE\pkg_r3d_pannellum.sys.ini')
    Copy-Item -LiteralPath $packageScript -Destination (Join-Path $tempRoot 'script.pkg_r3d_pannellum.php')
    Copy-Item -LiteralPath $moduleZip -Destination (Join-Path $tempRoot 'mod_r3d_pannellum.zip')
    Copy-Item -LiteralPath $pluginZip -Destination (Join-Path $tempRoot 'plg_system_r3d_adminui.zip')

    New-ZipFromFilesOrdered -Files @(
        (Join-Path $tempRoot 'pkg_r3d_pannellum.xml'),
        (Join-Path $tempRoot 'pkg_r3d_pannellum.en-GB.sys.ini'),
        (Join-Path $tempRoot 'pkg_r3d_pannellum.de-DE.sys.ini'),
        (Join-Path $tempRoot 'language\en-GB\pkg_r3d_pannellum.sys.ini'),
        (Join-Path $tempRoot 'language\de-DE\pkg_r3d_pannellum.sys.ini'),
        (Join-Path $tempRoot 'script.pkg_r3d_pannellum.php'),
        (Join-Path $tempRoot 'mod_r3d_pannellum.zip'),
        (Join-Path $tempRoot 'plg_system_r3d_adminui.zip')
    ) -EntryNames @(
        'pkg_r3d_pannellum.xml',
        'pkg_r3d_pannellum.en-GB.sys.ini',
        'pkg_r3d_pannellum.de-DE.sys.ini',
        'language/en-GB/pkg_r3d_pannellum.sys.ini',
        'language/de-DE/pkg_r3d_pannellum.sys.ini',
        'script.pkg_r3d_pannellum.php',
        'mod_r3d_pannellum.zip',
        'plg_system_r3d_adminui.zip'
    ) -ZipPath $packageZip
}
finally {
    Remove-Item -LiteralPath $tempRoot -Recurse -Force
}

Log "Built package ZIP: $packageZip"
Get-ChildItem -Path $distRoot -Filter '*.zip' -File | Sort-Object Name | ForEach-Object {
    Write-Host ("{0} ({1} bytes)" -f $_.Name, $_.Length)
}
