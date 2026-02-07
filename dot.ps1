<#
.SYNOPSIS
    Dotfiles management script for Windows PowerShell.

.DESCRIPTION
    A simple automation tool to manage configuration files by creating
    symbolic links from .dotfiles\.config to the user's .config folder.

.PARAMETER Command
    The command to execute: link, unlink, status, doctor, edit, help

.EXAMPLE
    .\dot.ps1 link       # Create symlinks for all configs
    .\dot.ps1 unlink     # Remove symlinks and restore backups
    .\dot.ps1 status     # Show current link status
    .\dot.ps1 doctor     # Run diagnostics
    .\dot.ps1 edit       # Open dotfiles in editor
#>

param(
    [Parameter(Position = 0)]
    [ValidateSet("link", "unlink", "status", "doctor", "edit", "install", "help")]
    [string]$Command = "help"
)

# Script configuration
$script:Version = "1.0.0"
$script:DotfilesDir = $PSScriptRoot
$script:ConfigSource = Join-Path $DotfilesDir ".config"
$script:ConfigTarget = Join-Path $env:USERPROFILE ".config"
$script:BackupDir = Join-Path $DotfilesDir "backups"

# Colors for output
function Write-Header { param($Message) Write-Host "`n==> $Message" -ForegroundColor Blue }
function Write-Success { param($Message) Write-Host "[OK] $Message" -ForegroundColor Green }
function Write-Error { param($Message) Write-Host "[X] $Message" -ForegroundColor Red }
function Write-Warning { param($Message) Write-Host "[!] $Message" -ForegroundColor Yellow }
function Write-Info { param($Message) Write-Host "[i] $Message" -ForegroundColor Cyan }

function Get-ConfigItems {
    if (-not (Test-Path $script:ConfigSource)) {
        return @()
    }
    Get-ChildItem -Path $script:ConfigSource -Directory | Select-Object -ExpandProperty Name
}

function Test-IsSymlink {
    param([string]$Path)
    if (-not (Test-Path $Path)) { return $false }
    $item = Get-Item $Path -Force
    return ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0
}

function Test-IsAdmin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Invoke-Link {
    Write-Header "Creating symlinks for dotfiles"

    if (-not (Test-IsAdmin)) {
        Write-Info "Requesting Administrator privileges..."
        $scriptPath = $MyInvocation.PSCommandPath
        if (-not $scriptPath) { $scriptPath = $PSCommandPath }
        $cmd = "-NoProfile -ExecutionPolicy Bypass -Command `"& '$scriptPath' link; Write-Host; Read-Host 'Press Enter to close'`""
        try {
            Start-Process pwsh -Verb RunAs -ArgumentList $cmd -Wait
        }
        catch {
            Start-Process powershell -Verb RunAs -ArgumentList $cmd -Wait
        }
        return
    }

    $configs = Get-ConfigItems
    if ($configs.Count -eq 0) {
        Write-Warning "No configs found in $($script:ConfigSource)"
        return
    }

    # Ensure target directory exists
    if (-not (Test-Path $script:ConfigTarget)) {
        New-Item -ItemType Directory -Path $script:ConfigTarget -Force | Out-Null
    }

    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $backupPath = Join-Path $script:BackupDir $timestamp

    foreach ($config in $configs) {
        $source = Join-Path $script:ConfigSource $config
        $target = Join-Path $script:ConfigTarget $config

        Write-Info "Processing: $config"

        # Check if target already exists
        if (Test-Path $target) {
            if (Test-IsSymlink $target) {
                $existingLink = (Get-Item $target).Target
                if ($existingLink -eq $source) {
                    Write-Success "$config already linked correctly"
                    continue
                }
                # Remove incorrect symlink
                Remove-Item $target -Force
            }
            else {
                # Backup existing config
                if (-not (Test-Path $backupPath)) {
                    New-Item -ItemType Directory -Path $backupPath -Force | Out-Null
                }
                $backupTarget = Join-Path $backupPath $config
                Write-Warning "Backing up existing $config to $backupPath"
                Move-Item -Path $target -Destination $backupTarget -Force
            }
        }

        # Create symlink
        try {
            New-Item -ItemType SymbolicLink -Path $target -Target $source -Force | Out-Null
            Write-Success "$config linked: $target -> $source"
        }
        catch {
            Write-Error "Failed to link $config`: $_"
        }
    }

    Write-Header "Linking complete!"
}

function Invoke-Unlink {
    Write-Header "Removing symlinks"

    $configs = Get-ConfigItems
    $latestBackup = Get-ChildItem -Path $script:BackupDir -Directory -ErrorAction SilentlyContinue |
                    Sort-Object Name -Descending |
                    Select-Object -First 1

    foreach ($config in $configs) {
        $target = Join-Path $script:ConfigTarget $config

        if (Test-Path $target) {
            if (Test-IsSymlink $target) {
                Remove-Item $target -Force
                Write-Success "Removed symlink: $config"

                # Restore backup if available
                if ($latestBackup) {
                    $backupSource = Join-Path $latestBackup.FullName $config
                    if (Test-Path $backupSource) {
                        Move-Item -Path $backupSource -Destination $target -Force
                        Write-Info "Restored backup for: $config"
                    }
                }
            }
            else {
                Write-Warning "$config is not a symlink, skipping"
            }
        }
    }

    Write-Header "Unlink complete!"
}

function Invoke-Status {
    Write-Header "Dotfiles Status"

    $configs = Get-ConfigItems

    Write-Host ""
    Write-Host "Source: $($script:ConfigSource)"
    Write-Host "Target: $($script:ConfigTarget)"
    Write-Host ""

    $table = @()
    foreach ($config in $configs) {
        $target = Join-Path $script:ConfigTarget $config
        $source = Join-Path $script:ConfigSource $config

        $status = if (-not (Test-Path $target)) {
            "Not linked"
        }
        elseif (Test-IsSymlink $target) {
            $linkTarget = (Get-Item $target).Target
            if ($linkTarget -eq $source) { "Linked" } else { "Wrong target" }
        }
        else {
            "Exists (not symlink)"
        }

        $table += [PSCustomObject]@{
            Config = $config
            Status = $status
        }
    }

    $table | Format-Table -AutoSize
}

function Invoke-Doctor {
    Write-Header "Running diagnostics"

    $issues = 0

    # Check admin privileges
    if (Test-IsAdmin) {
        Write-Success "Running as Administrator"
    }
    else {
        Write-Warning "Not running as Administrator (needed for symlinks)"
        $issues++
    }

    # Check dotfiles directory
    if (Test-Path $script:ConfigSource) {
        $count = (Get-ConfigItems).Count
        Write-Success "Config source exists: $count configs found"
    }
    else {
        Write-Error "Config source not found: $($script:ConfigSource)"
        $issues++
    }

    # Check target directory
    if (Test-Path $script:ConfigTarget) {
        Write-Success "Config target exists: $($script:ConfigTarget)"
    }
    else {
        Write-Info "Config target will be created: $($script:ConfigTarget)"
    }

    # Check backups
    if (Test-Path $script:BackupDir) {
        $backupCount = (Get-ChildItem $script:BackupDir -Directory -ErrorAction SilentlyContinue).Count
        Write-Success "Backup directory exists: $backupCount backups"
    }
    else {
        Write-Info "No backups yet"
    }

    # Check common tools
    $tools = @("git", "nvim", "code")
    foreach ($tool in $tools) {
        if (Get-Command $tool -ErrorAction SilentlyContinue) {
            Write-Success "$tool is installed"
        }
        else {
            Write-Info "$tool not found (optional)"
        }
    }

    if ($issues -eq 0) {
        Write-Header "All checks passed!"
    }
    else {
        Write-Header "Found $issues issue(s)"
    }
}

function Invoke-Edit {
    Write-Header "Opening dotfiles in editor"

    $editor = if ($env:EDITOR) { $env:EDITOR }
              elseif (Get-Command code -ErrorAction SilentlyContinue) { "code" }
              elseif (Get-Command nvim -ErrorAction SilentlyContinue) { "nvim" }
              elseif (Get-Command notepad -ErrorAction SilentlyContinue) { "notepad" }
              else { $null }

    if ($editor) {
        Write-Info "Opening with: $editor"
        & $editor $script:DotfilesDir
    }
    else {
        Write-Error "No editor found"
    }
}

function Invoke-Install {
    Write-Header "Installing required tools via winget"

    # Check if winget is available
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Error "winget is not installed. Please install App Installer from the Microsoft Store."
        return
    }

    $tools = @(
        @{ Name = "wezterm"; WingetId = "wez.wezterm" },
        @{ Name = "nvim"; WingetId = "Neovim.Neovim" }
    )

    foreach ($tool in $tools) {
        Write-Info "Checking: $($tool.Name)"

        if (Get-Command $tool.Name -ErrorAction SilentlyContinue) {
            Write-Success "$($tool.Name) is already installed"
        }
        else {
            Write-Info "Installing $($tool.Name) via winget..."
            try {
                winget install --id $tool.WingetId --accept-source-agreements --accept-package-agreements --silent
                if ($LASTEXITCODE -eq 0) {
                    Write-Success "$($tool.Name) installed successfully"
                }
                else {
                    Write-Error "Failed to install $($tool.Name)"
                }
            }
            catch {
                Write-Error "Failed to install $($tool.Name): $_"
            }
        }
    }

    Write-Header "Installation complete!"
    Write-Info "You may need to restart your terminal for PATH changes to take effect."
}

function Show-Help {
    Write-Host @"

  dot.ps1 - Dotfiles Management for Windows
  Version: $($script:Version)

  USAGE:
    .\dot.ps1 <command>

  COMMANDS:
    link      Create symbolic links from .dotfiles to .config
    unlink    Remove symbolic links and restore backups
    status    Show current link status for all configs
    doctor    Run diagnostics and check installation
    edit      Open dotfiles directory in editor
    install   Install required tools (wezterm, nvim) via winget
    help      Show this help message

  EXAMPLES:
    .\dot.ps1 link       # Link all configs
    .\dot.ps1 status     # Check what's linked
    .\dot.ps1 doctor     # Run health checks
    .\dot.ps1 install    # Install wezterm and nvim

  NOTE:
    The 'link' command requires Administrator privileges.

"@
}

# Main execution
switch ($Command) {
    "link"    { Invoke-Link }
    "unlink"  { Invoke-Unlink }
    "status"  { Invoke-Status }
    "doctor"  { Invoke-Doctor }
    "edit"    { Invoke-Edit }
    "install" { Invoke-Install }
    "help"    { Show-Help }
    default   { Show-Help }
}
