param()

$ErrorActionPreference = "Stop"

$pluginRoot = Join-Path $env:USERPROFILE ".psmux\plugins"
$statusScript = Join-Path $pluginRoot "psmux-git-status\scripts\git_status.ps1"

if (-not (Test-Path -LiteralPath $statusScript -PathType Leaf)) {
    throw "Missing psmux status script: $statusScript"
}

& $statusScript
