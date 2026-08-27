[CmdletBinding()]
param([string]$ProjectRoot = (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)))

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-LanguageKeys([string]$Path) {
    $keys = @{}
    Get-Content -LiteralPath $Path | ForEach-Object {
        if ($_ -match '^([A-Z0-9_]+)=') { $keys[$Matches[1]] = $true }
    }
    return $keys
}

$root = (Resolve-Path -LiteralPath $ProjectRoot).Path
$forms = @(
    (Join-Path $root '01_src\packages\mod_r3d_pannellum\mod_r3d_pannellum.xml'),
    (Join-Path $root '01_src\packages\mod_r3d_pannellum\forms\hotspot.xml'),
    (Join-Path $root '01_src\packages\mod_r3d_pannellum\forms\scene.xml')
)
$en = Get-LanguageKeys (Join-Path $root '01_src\packages\mod_r3d_pannellum\language\en-GB\en-GB.mod_r3d_pannellum.ini')
$de = Get-LanguageKeys (Join-Path $root '01_src\packages\mod_r3d_pannellum\language\de-DE\de-DE.mod_r3d_pannellum.ini')
$referenced = @{}

foreach ($formPath in $forms) {
    [xml]$xml = Get-Content -LiteralPath $formPath -Raw
    $text = Get-Content -LiteralPath $formPath -Raw
    foreach ($match in [regex]::Matches($text, 'MOD_R3D_PAN_[A-Z0-9_]+')) { $referenced[$match.Value] = $true }
    foreach ($match in [regex]::Matches($text, '(?:label|description|hint)="([^"]+)"')) {
        $value = $match.Groups[1].Value
        if ($value -notmatch '^(MOD_R3D_PAN_|JGLOBAL_|JOPTION_)') { throw "Hardcoded visible form text '$value' in $formPath" }
    }
    foreach ($match in [regex]::Matches($text, '<option[^>]*>([^<]+)</option>')) {
        $value = $match.Groups[1].Value.Trim()
        if ($value -and $value -notmatch '^(MOD_R3D_PAN_|JGLOBAL_|JOPTION_)') { throw "Hardcoded visible option '$value' in $formPath" }
    }
}

foreach ($key in $referenced.Keys) {
    if (-not $en.ContainsKey($key)) { throw "Missing en-GB language key: $key" }
    if (-not $de.ContainsKey($key)) { throw "Missing de-DE language key: $key" }
}

Write-Host 'Module language parity regression test: OK'
