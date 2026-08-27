[CmdletBinding()]
param([string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot))

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path -LiteralPath $ProjectRoot).Path

& php (Join-Path $root 'tests\php\module_helper_test.php')
if ($LASTEXITCODE -ne 0) { throw 'PHP regression tests failed.' }

& node (Join-Path $root 'tests\js\viewer_test.js')
if ($LASTEXITCODE -ne 0) { throw 'JavaScript regression tests failed.' }

& (Join-Path $root 'tests\powershell\release_workflow_test.ps1') -ProjectRoot $root
if (-not $?) { throw 'PowerShell regression tests failed.' }

Write-Host 'All local regression tests: OK'
