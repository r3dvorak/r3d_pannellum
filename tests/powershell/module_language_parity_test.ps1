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
    (Join-Path $root '01_src\packages\mod_r3d_pannellum\forms\hotspot-scene.xml'),
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
foreach ($key in @('MOD_R3D_PAN_TOUR_EMPTY_MESSAGE')) {
    if (-not $en.ContainsKey($key) -or -not $de.ContainsKey($key)) {
        throw "Missing localized tour status key: $key"
    }
}

$singleHotspotForm = Get-Content -LiteralPath (Join-Path $root '01_src\packages\mod_r3d_pannellum\forms\hotspot.xml') -Raw
$sceneHotspotForm = Get-Content -LiteralPath (Join-Path $root '01_src\packages\mod_r3d_pannellum\forms\hotspot-scene.xml') -Raw
if ($singleHotspotForm -match '<option value="scene">') {
    throw 'Single-panorama hotspots must not offer scene navigation.'
}
if ($sceneHotspotForm -notmatch '<option value="scene">') {
    throw 'Scene hotspots must offer scene navigation.'
}

$moduleForm = $forms[0]
[xml]$moduleXml = Get-Content -LiteralPath $moduleForm -Raw
$tourFieldset = $moduleXml.SelectSingleNode('/extension/config/fields[@name="params"]/fieldset[@name="tour"]')
if (-not $tourFieldset) { throw 'The dedicated tour fieldset is missing.' }
if ($moduleXml.SelectSingleNode('/extension/config/fields[@name="params"]/fieldset[@name="advanced"]')) {
    throw 'The module form must not use Joomla reserved fieldset name "advanced" for tour settings.'
}
foreach ($fieldName in @('first_scene', 'scenes')) {
    if (-not $tourFieldset.SelectSingleNode("field[@name='$fieldName']")) {
        throw "Tour field '$fieldName' is not in the dedicated tour fieldset."
    }
}

$basicFieldset = $moduleXml.SelectSingleNode('/extension/config/fields[@name="params"]/fieldset[@name="basic"]')
if (-not $basicFieldset) { throw 'The global viewer settings fieldset is missing.' }
if (-not $basicFieldset.SelectSingleNode('field[@name="scene_fade_duration"]')) {
    throw 'Global scene transition duration must remain in the global viewer settings.'
}
if ($tourFieldset.SelectSingleNode('field[@name="scene_fade_duration"]')) {
    throw 'Scene transition duration must not be duplicated in the tour structure tab.'
}
foreach ($fieldName in @('yaw', 'pitch', 'hfov', 'min_hfov', 'max_hfov')) {
    $field = $basicFieldset.SelectSingleNode("field[@name='$fieldName']")
    if (-not $field -or $field.GetAttribute('showon')) {
        throw "Global default field '$fieldName' must be visible in both viewer modes."
    }
}

$adminPlugin = Get-Content -LiteralPath (Join-Path $root '01_src\packages\plg_system_r3d_adminui\r3d_adminui.php') -Raw
if ($adminPlugin -notmatch "'com_modules', 'com_advancedmodules'") {
    throw 'The administrator UI plugin must load for both Joomla module editors.'
}

Write-Host 'Module language parity regression test: OK'
