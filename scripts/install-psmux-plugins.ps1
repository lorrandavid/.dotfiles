param()

$ErrorActionPreference = "Stop"

if (-not (Get-Command psmux -ErrorAction SilentlyContinue)) {
    throw "psmux is required before its plugins can be installed."
}

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    throw "git is required to install psmux plugins."
}

$configPath = Join-Path $env:USERPROFILE ".config\psmux\psmux.conf"
if (-not (Test-Path -LiteralPath $configPath -PathType Leaf)) {
    throw "Shared psmux config is not linked at $configPath. Run '.\dot.ps1 link' first."
}

$pluginRoot = Join-Path $env:USERPROFILE ".psmux\plugins"
$ppmRoot = Join-Path $pluginRoot "ppm"
$ppmInstaller = Join-Path $ppmRoot "scripts\install_plugins.ps1"

if (-not (Test-Path -LiteralPath $ppmInstaller -PathType Leaf)) {
    $temporaryRoot = Join-Path ([System.IO.Path]::GetTempPath()) "psmux-plugins-$([guid]::NewGuid())"

    try {
        & git -c credential.helper= clone --depth 1 https://github.com/psmux/psmux-plugins.git $temporaryRoot
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to download the psmux plugin repository."
        }

        New-Item -ItemType Directory -Path $pluginRoot -Force | Out-Null
        Copy-Item -LiteralPath (Join-Path $temporaryRoot "ppm") -Destination $ppmRoot -Recurse
    }
    finally {
        if (Test-Path -LiteralPath $temporaryRoot) {
            Remove-Item -LiteralPath $temporaryRoot -Recurse -Force
        }
    }
}

& $ppmInstaller

$expectedPlugins = @(
    "psmux-sensible",
    "psmux-pain-control",
    "psmux-vim-navigator",
    "psmux-prefix-highlight",
    "psmux-cpu",
    "psmux-git-status",
    "psmux-theme-tokyonight"
)
$missingPlugins = @($expectedPlugins | Where-Object {
    -not (Test-Path -LiteralPath (Join-Path $pluginRoot $_) -PathType Container)
})

if ($missingPlugins.Count -gt 0) {
    throw "Failed to install psmux plugins: $($missingPlugins -join ', ')"
}

Write-Host "[OK] psmux plugins are installed." -ForegroundColor Green
