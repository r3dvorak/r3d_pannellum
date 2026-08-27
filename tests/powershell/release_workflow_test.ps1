[CmdletBinding()]
param([string]$ProjectRoot = (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)))

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

$root = (Resolve-Path -LiteralPath $ProjectRoot).Path
$publishPath = Join-Path $root 'scripts\publish-r3d_pannellum.ps1'
$releasePath = Join-Path $root 'scripts\release-r3d_pannellum.ps1'
$installerPath = Join-Path $root '01_src\script.pkg_r3d_pannellum.php'
$modulePath = Join-Path $root '01_src\packages\mod_r3d_pannellum\mod_r3d_pannellum.php'
$templatePath = Join-Path $root '01_src\packages\mod_r3d_pannellum\tmpl\default.php'
$pluginPath = Join-Path $root '01_src\packages\plg_system_r3d_adminui\r3d_adminui.php'
$publish = Get-Content -LiteralPath $publishPath -Raw
$release = Get-Content -LiteralPath $releasePath -Raw
$installer = Get-Content -LiteralPath $installerPath -Raw
$runtimeSources = (Get-Content -LiteralPath $modulePath -Raw) + (Get-Content -LiteralPath $templatePath -Raw) + (Get-Content -LiteralPath $pluginPath -Raw)

Assert-True ($publish.Contains("[ValidateSet('BuildOnly', 'DryRun')]")) 'Standalone publication exposes a Live mode.'
Assert-True ($publish.IndexOf("if (`$effectiveMode -eq 'BuildOnly')") -lt $publish.IndexOf('$resolvedToolsRoot')) 'BuildOnly does not return before publication tooling is resolved.'
Assert-True ($publish.Contains('$createArgs["DryRun"] = $true')) '31 dry-run forwarding is missing.'
Assert-True ($publish.Contains('$updateArgs["DryRun"] = $true')) '32 dry-run forwarding is missing.'
Assert-True ($publish.Contains("[ValidateSet('BuildOnly', 'DryRun')]")) 'Direct -Mode Live is not rejected by parameter validation.'
Assert-True ($release.Contains("PublicationMode -eq 'Live'")) 'Guarded release no longer owns the Live publication stage.'
Assert-True (-not ($release -match "git add -A|'add', '-A'")) 'Release script still stages all changes.'
Assert-True ($release.IndexOf('-Mode BuildOnly') -lt $release.IndexOf("'commit'")) 'Build validation does not precede commit.'
Assert-True ($release.IndexOf('-Mode DryRun') -lt $release.IndexOf("'commit'")) 'Publication dry-run does not precede commit.'
Assert-True ($release -match 'status.+--porcelain') 'Clean working-tree guard is missing.'
Assert-True ($release -match "'fetch', '--no-tags', 'origin', 'main'") 'Remote synchronization refresh is missing.'
Assert-True ($release -match 'HEAD\.\.\.@\{upstream\}') 'Upstream synchronization guard is missing.'

Assert-True ($installer.Contains("if (!in_array(`$type, ['install', 'discover_install'], true))")) 'Installer does not distinguish install from update.'
Assert-True (-not $installer.Contains("enableExtension(`$db, 'module'")) 'Installer still pretends to activate a module instance.'
Assert-True ($installer.Contains("load('pkg_r3d_pannellum.sys'")) 'Installer loads the wrong package language catalogue.'
Assert-True ($installer -match 'Log::add') 'Installer failure logging is missing.'
Assert-True (-not $runtimeSources.Contains('addScriptDeclaration')) 'Deprecated inline script declaration remains.'
Assert-True (-not $runtimeSources.Contains('Factory::getDocument')) 'Deprecated Factory::getDocument remains.'
Assert-True (-not (Get-Content -LiteralPath $templatePath -Raw).Contains('<script')) 'Template still contains executable inline script.'

$project = Get-Content -LiteralPath (Join-Path $root 'project.json') -Raw | ConvertFrom-Json
$preparedVersion = [string]$project.project.defaults.version
Assert-True ([string]$project.standards.targetJoomla -match '4\.4' -and [string]$project.standards.targetJoomla -match '5\.x' -and [string]$project.standards.targetJoomla -match '6\.x') 'Project Joomla compatibility metadata is incomplete.'
[xml]$publishedUpdate = Get-Content -LiteralPath (Join-Path $root '05_updates\pkg_r3d_pannellum.xml') -Raw
Assert-True ($publishedUpdate.updates.update.php_minimum -eq '8.1.0') 'Published extension PHP minimum should remain 8.1.'

$baselineZip = Join-Path $root '04_dist\pkg_r3d_pannellum-5.2.20.zip'
$baselineHash = (Get-FileHash -LiteralPath $baselineZip -Algorithm SHA256).Hash
Assert-True ($baselineHash -eq '2D3ACE0D7C361E0EFC72665AC0D58326437A61EBA26783325D786154D3857ED0') 'Published 5.2.20 baseline ZIP changed.'

$testDist = Join-Path $root '02_build\test-nopublish'
if (Test-Path -LiteralPath $testDist) { Remove-Item -LiteralPath $testDist -Recurse -Force }
try {
    & $publishPath -ProjectRoot $root -NoPublish -BuildOutputRoot $testDist -ToolsRoot (Join-Path $testDist 'must-not-be-resolved')
    if (-not $?) { throw 'BuildOnly execution failed.' }
    $testPackage = Join-Path $testDist ("pkg_r3d_pannellum-{0}.zip" -f $preparedVersion)
    Assert-True (Test-Path -LiteralPath $testPackage) 'BuildOnly package was not created.'
    $firstHash = (Get-FileHash -LiteralPath $testPackage -Algorithm SHA256).Hash
    & $publishPath -ProjectRoot $root -NoPublish -BuildOutputRoot $testDist -ToolsRoot (Join-Path $testDist 'must-not-be-resolved')
    if (-not $?) { throw 'Second deterministic BuildOnly execution failed.' }
    $secondHash = (Get-FileHash -LiteralPath $testPackage -Algorithm SHA256).Hash
    Assert-True ($firstHash -eq $secondHash) 'Repeated builds from unchanged source are not reproducible.'
}
finally {
    if (Test-Path -LiteralPath $testDist) { Remove-Item -LiteralPath $testDist -Recurse -Force }
}

echo 'PowerShell release regression tests: OK'
