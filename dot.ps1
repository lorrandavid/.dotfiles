<#
.SYNOPSIS
    Dotfiles management script for Windows PowerShell.

.DESCRIPTION
    A simple automation tool to manage configuration files by creating
    symbolic links from .dotfiles\.config to the user's .config folder.

.PARAMETER Command
    The command to execute: link, unlink, status, doctor, edit, update-skills, help

.PARAMETER Configs
    Optional config names to target when using the unlink command.

.EXAMPLE
    .\dot.ps1 link       # Create symlinks for all configs
    .\dot.ps1 unlink     # Remove symlinks and restore backups
    .\dot.ps1 unlink nvim zed  # Remove specific symlinks
    .\dot.ps1 status     # Show current link status
    .\dot.ps1 doctor     # Run diagnostics
    .\dot.ps1 edit       # Open dotfiles in editor
    .\dot.ps1 update-skills  # Update project skills without installing Claude skills
#>

param(
    [Parameter(Position = 0)]
    [ValidateSet("link", "unlink", "status", "doctor", "edit", "install", "setup", "update-skills", "help")]
    [string]$Command = "help",

    [Parameter(Position = 1, ValueFromRemainingArguments = $true)]
    [string[]]$Configs = @()
)

# Script configuration
$script:Version = "1.0.0"
$script:DotfilesDir = $PSScriptRoot
$script:ConfigSource = Join-Path $DotfilesDir ".config"
$script:ConfigTarget = if ($env:XDG_CONFIG_HOME) { $env:XDG_CONFIG_HOME } else { Join-Path $env:USERPROFILE ".config" }
$script:BackupDir = Join-Path $DotfilesDir "backups"
$script:AgentsSource = Join-Path $ConfigSource ".agents"
$script:AgentsTarget = Join-Path $env:USERPROFILE ".agents"
$script:CodexAgentsSource = Join-Path $script:AgentsSource "AGENTS.md"
$script:CodexAgentsTarget = Join-Path $env:USERPROFILE ".codex\AGENTS.md"
$script:CopilotInstructionsSource = $script:CodexAgentsSource
$script:CopilotInstructionsTarget = Join-Path $env:USERPROFILE ".copilot\copilot-instructions.md"
$script:CopilotSkillsSource = Join-Path $script:AgentsSource "skills"
$script:CopilotSkillsTarget = Join-Path $env:USERPROFILE ".copilot\skills"

# Colors for output
function Write-Header { param($Message) Write-Host "`n==> $Message" -ForegroundColor Blue }
function Write-Success { param($Message) Write-Host "[OK] $Message" -ForegroundColor Green }
function Write-Error { param($Message) Write-Host "[X] $Message" -ForegroundColor Red }
function Write-Warning { param($Message) Write-Host "[!] $Message" -ForegroundColor Yellow }
function Write-Info { param($Message) Write-Host "[i] $Message" -ForegroundColor Cyan }

function Ensure-XdgConfigHome {
    $xdgConfigHome = Join-Path $env:USERPROFILE ".config"
    if ($env:XDG_CONFIG_HOME -eq $xdgConfigHome) {
        $script:ConfigTarget = $env:XDG_CONFIG_HOME
        Write-Success "XDG_CONFIG_HOME already set: $xdgConfigHome"
        return
    }

    [System.Environment]::SetEnvironmentVariable("XDG_CONFIG_HOME", $xdgConfigHome, "User")
    $env:XDG_CONFIG_HOME = $xdgConfigHome
    $script:ConfigTarget = $xdgConfigHome
    Write-Success "Configured XDG_CONFIG_HOME: $xdgConfigHome"
}

function Get-ConfigItems {
    if (-not (Test-Path $script:ConfigSource)) {
        return @()
    }
    Get-ChildItem -Path $script:ConfigSource -Directory -Force |
        Where-Object { $_.Name -notin @('.agents', '.copilot', 'opencode', 'powershell', 'shared', 'vscode') } |
        Select-Object -ExpandProperty Name
}

function Get-SelectedConfigs {
    param([string[]]$RequestedConfigs = @())

    $availableConfigs = @(Get-ConfigItems)
    if ($RequestedConfigs.Count -eq 0) {
        return $availableConfigs
    }

    if ($availableConfigs.Count -eq 0) {
        return @()
    }

    $availableConfigLookup = @{}
    foreach ($config in $availableConfigs) {
        $availableConfigLookup[$config] = $true
    }

    $selectedConfigs = New-Object System.Collections.Generic.List[string]
    $seenConfigs = @{}

    foreach ($requestedConfig in $RequestedConfigs) {
        if (-not $availableConfigLookup.ContainsKey($requestedConfig)) {
            throw "Unknown config: $requestedConfig. Available configs: $($availableConfigs -join ', ')"
        }

        if ($seenConfigs.ContainsKey($requestedConfig)) {
            continue
        }

        $seenConfigs[$requestedConfig] = $true
        [void]$selectedConfigs.Add($requestedConfig)
    }

    return @($selectedConfigs)
}

function Get-PathBasename {
    param([string]$Path)
    return Split-Path -Path $Path -Leaf
}

function Get-ConfigDisplayName {
    param([string]$Config)
    return $Config
}

function Get-ConfigTargetPath {
    param([string]$Config)
    return Join-Path $script:ConfigTarget $Config
}

function Get-ConfigBackupName {
    param([string]$Config)
    return $Config
}

function Get-ConfigLegacyTargetPaths {
    param([string]$Config)
    return @()
}

function Get-ConfigLegacyBackupName {
    param(
        [string]$Config,
        [string]$LegacyTargetPath
    )

    $legacyName = Get-PathBasename $LegacyTargetPath

    return $legacyName
}

function Get-ConfigRestoreCandidates {
    param([string]$Config)

    return @(Get-ConfigBackupName $Config)
}

function Test-IsSymlink {
    param([string]$Path)
    if (-not (Test-Path $Path)) { return $false }
    $item = Get-Item $Path -Force
    return ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0
}

# VS Code extension linking helpers
$script:VscodeExtSource = Join-Path $script:ConfigSource "vscode\extensions"
$script:VscodeExtTarget = Join-Path $env:USERPROFILE ".vscode\extensions"

# Zed themes linking helpers
$script:ZedThemesSource = Join-Path $script:ConfigSource "zed\themes"
$script:ZedThemesTarget = Join-Path $env:USERPROFILE "AppData\Roaming\Zed\themes"

function Get-VscodeExtensions {
    if (-not (Test-Path $script:VscodeExtSource)) { return @() }
    Get-ChildItem -Path $script:VscodeExtSource -Directory -Force |
        Select-Object -ExpandProperty Name
}

function Invoke-LinkVscodeExtensions {
    $extensions = Get-VscodeExtensions
    if ($extensions.Count -eq 0) { return }

    Write-Header "Linking VS Code extensions"

    if (-not (Test-Path $script:VscodeExtTarget)) {
        New-Item -ItemType Directory -Path $script:VscodeExtTarget -Force | Out-Null
    }

    foreach ($ext in $extensions) {
        $source = Join-Path $script:VscodeExtSource $ext
        $target = Join-Path $script:VscodeExtTarget $ext

        if (Test-Path -LiteralPath $target) {
            if (Test-IsSymlink $target) {
                $existingLink = (Get-Item -LiteralPath $target).Target
                if ($existingLink -eq $source) {
                    Write-Success "vscode/$ext already linked correctly"
                    continue
                }
                Remove-Item -LiteralPath $target -Force
            } else {
                Write-Warning "vscode/$ext exists and is not a symlink, skipping"
                continue
            }
        }

        try {
            New-Item -ItemType SymbolicLink -Path $target -Target $source -Force | Out-Null
            Write-Success "vscode/$ext linked: $target -> $source"
        } catch {
            Write-Error "Failed to link vscode/$ext`: $_"
        }
    }
}

function Invoke-UnlinkVscodeExtensions {
    $extensions = Get-VscodeExtensions
    if ($extensions.Count -eq 0) { return }

    Write-Header "Removing VS Code extension symlinks"

    foreach ($ext in $extensions) {
        $target = Join-Path $script:VscodeExtTarget $ext

        if (Test-Path -LiteralPath $target) {
            if (Test-IsSymlink $target) {
                Remove-Item -LiteralPath $target -Force
                Write-Success "Removed symlink: vscode/$ext"
            } else {
                Write-Warning "vscode/$ext is not a symlink, skipping"
            }
        }
    }
}

function Invoke-StatusVscodeExtensions {
    $extensions = Get-VscodeExtensions
    if ($extensions.Count -eq 0) { return }

    foreach ($ext in $extensions) {
        $source = Join-Path $script:VscodeExtSource $ext
        $target = Join-Path $script:VscodeExtTarget $ext

        $status = if (-not (Test-Path -LiteralPath $target)) {
            "Not linked"
        } elseif (Test-IsSymlink $target) {
            $linkTarget = (Get-Item -LiteralPath $target).Target
            if ($linkTarget -eq $source) { "Linked" } else { "Wrong target" }
        } else {
            "Exists (not symlink)"
        }

        [PSCustomObject]@{
            Config = "vscode/$ext"
            Status = $status
        }
    }
}

function Get-ZedThemes {
    if (-not (Test-Path $script:ZedThemesSource)) { return @() }
    Get-ChildItem -Path $script:ZedThemesSource -File -Force |
        Select-Object -ExpandProperty Name
}

function Invoke-LinkZedThemes {
    $themes = Get-ZedThemes
    if ($themes.Count -eq 0) { return }

    Write-Header "Linking Zed themes"

    if (-not (Test-Path $script:ZedThemesTarget)) {
        New-Item -ItemType Directory -Path $script:ZedThemesTarget -Force | Out-Null
    }

    foreach ($theme in $themes) {
        $source = Join-Path $script:ZedThemesSource $theme
        $target = Join-Path $script:ZedThemesTarget $theme

        if (Test-Path -LiteralPath $target) {
            if (Test-IsSymlink $target) {
                $existingLink = (Get-Item -LiteralPath $target).Target
                if ($existingLink -eq $source) {
                    Write-Success "zed/themes/$theme already linked correctly"
                    continue
                }
                Remove-Item -LiteralPath $target -Force
            } else {
                Write-Warning "zed/themes/$theme exists and is not a symlink, skipping"
                continue
            }
        }

        try {
            New-Item -ItemType SymbolicLink -Path $target -Target $source -Force | Out-Null
            Write-Success "zed/themes/$theme linked: $target -> $source"
        } catch {
            Write-Error "Failed to link zed/themes/$theme`: $_"
        }
    }
}

function Invoke-UnlinkZedThemes {
    $themes = Get-ZedThemes
    if ($themes.Count -eq 0) { return }

    Write-Header "Removing Zed theme symlinks"

    foreach ($theme in $themes) {
        $target = Join-Path $script:ZedThemesTarget $theme

        if (Test-Path -LiteralPath $target) {
            if (Test-IsSymlink $target) {
                Remove-Item -LiteralPath $target -Force
                Write-Success "Removed symlink: zed/themes/$theme"
            } else {
                Write-Warning "zed/themes/$theme is not a symlink, skipping"
            }
        }
    }
}

function Invoke-StatusZedThemes {
    $themes = Get-ZedThemes
    if ($themes.Count -eq 0) { return }

    foreach ($theme in $themes) {
        $source = Join-Path $script:ZedThemesSource $theme
        $target = Join-Path $script:ZedThemesTarget $theme

        $status = if (-not (Test-Path -LiteralPath $target)) {
            "Not linked"
        } elseif (Test-IsSymlink $target) {
            $linkTarget = (Get-Item -LiteralPath $target).Target
            if ($linkTarget -eq $source) { "Linked" } else { "Wrong target" }
        } else {
            "Exists (not symlink)"
        }

        [PSCustomObject]@{
            Config = "zed/themes/$theme"
            Status = $status
        }
    }
}

function Invoke-LinkAgents {
    param([string]$BackupPath)

    if (-not (Test-Path -LiteralPath $script:AgentsSource -PathType Container)) {
        return
    }

    Write-Header "Linking Codex skills"

    if (Test-Path -LiteralPath $script:AgentsTarget) {
        if (Test-IsSymlink $script:AgentsTarget) {
            $existingLink = (Get-Item -LiteralPath $script:AgentsTarget).Target
            if ($existingLink -eq $script:AgentsSource) {
                Write-Success "agents already linked correctly"
            }
            else {
                Remove-Item -LiteralPath $script:AgentsTarget -Force
            }
        }
        else {
            if (-not (Test-Path $BackupPath)) {
                New-Item -ItemType Directory -Path $BackupPath -Force | Out-Null
            }

            $backupTarget = Join-Path $BackupPath "agents"
            Write-Warning "Backing up existing agents to $backupTarget"
            Move-Item -LiteralPath $script:AgentsTarget -Destination $backupTarget -Force
        }
    }

    try {
        $targetParent = Split-Path -Parent $script:AgentsTarget
        if ($targetParent -and -not (Test-Path -LiteralPath $targetParent)) {
            New-Item -ItemType Directory -Path $targetParent -Force | Out-Null
        }

        if (-not (Test-Path -LiteralPath $script:AgentsTarget)) {
            New-Item -ItemType Junction -Path $script:AgentsTarget -Target $script:AgentsSource -Force | Out-Null
            Write-Success "agents linked: $($script:AgentsTarget) -> $($script:AgentsSource)"
        }

        if (Test-Path -LiteralPath $script:CodexAgentsTarget) {
            if (Test-IsSymlink $script:CodexAgentsTarget) {
                $existingLink = (Get-Item -LiteralPath $script:CodexAgentsTarget).Target
                if ($existingLink -eq $script:CodexAgentsSource) {
                    Write-Success "Codex AGENTS.md already linked correctly"
                }
                else {
                    Remove-Item -LiteralPath $script:CodexAgentsTarget -Force
                }
            }
            else {
                if (-not (Test-Path $BackupPath)) {
                    New-Item -ItemType Directory -Path $BackupPath -Force | Out-Null
                }

                $backupTarget = Join-Path $BackupPath "codex-AGENTS.md"
                Write-Warning "Backing up existing Codex AGENTS.md to $backupTarget"
                Move-Item -LiteralPath $script:CodexAgentsTarget -Destination $backupTarget -Force
            }
        }

        if (-not (Test-Path -LiteralPath $script:CodexAgentsTarget)) {
            $codexTargetParent = Split-Path -Parent $script:CodexAgentsTarget
            if (-not (Test-Path -LiteralPath $codexTargetParent)) {
                New-Item -ItemType Directory -Path $codexTargetParent -Force | Out-Null
            }

            New-Item -ItemType SymbolicLink -Path $script:CodexAgentsTarget -Target $script:CodexAgentsSource -Force | Out-Null
            Write-Success "Codex AGENTS.md linked: $($script:CodexAgentsTarget) -> $($script:CodexAgentsSource)"
        }

        $copilotTargetParent = Split-Path -Parent $script:CopilotInstructionsTarget
        $legacyCopilotSource = Join-Path $script:ConfigSource ".copilot"
        $copilotTargetParentItem = Get-Item -LiteralPath $copilotTargetParent -Force -ErrorAction SilentlyContinue
        if ($copilotTargetParentItem -and (($copilotTargetParentItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0)) {
            $existingCopilotHomeTarget = [string]$copilotTargetParentItem.Target
            if (-not [System.IO.Path]::IsPathRooted($existingCopilotHomeTarget)) {
                $copilotHomeParent = Split-Path -Parent $copilotTargetParent
                $existingCopilotHomeTarget = Join-Path $copilotHomeParent $existingCopilotHomeTarget
            }

            $existingCopilotHomeTarget = [System.IO.Path]::GetFullPath($existingCopilotHomeTarget)
            $expectedCopilotHomeTarget = [System.IO.Path]::GetFullPath($legacyCopilotSource)
            if (-not [string]::Equals($existingCopilotHomeTarget, $expectedCopilotHomeTarget, [System.StringComparison]::OrdinalIgnoreCase)) {
                throw "Copilot home points to an unexpected location: $existingCopilotHomeTarget"
            }

            Remove-Item -LiteralPath $copilotTargetParent -Force
            New-Item -ItemType Directory -Path $copilotTargetParent -Force | Out-Null
            Write-Success "Migrated legacy Copilot directory symlink"
        }

        if (Test-Path -LiteralPath $script:CopilotInstructionsTarget) {
            if (Test-IsSymlink $script:CopilotInstructionsTarget) {
                $existingLink = (Get-Item -LiteralPath $script:CopilotInstructionsTarget).Target
                if ($existingLink -eq $script:CopilotInstructionsSource) {
                    Write-Success "Copilot instructions already linked correctly"
                }
                else {
                    Remove-Item -LiteralPath $script:CopilotInstructionsTarget -Force
                }
            }
            else {
                if (-not (Test-Path $BackupPath)) {
                    New-Item -ItemType Directory -Path $BackupPath -Force | Out-Null
                }

                $backupTarget = Join-Path $BackupPath "copilot-instructions.md"
                Write-Warning "Backing up existing Copilot instructions to $backupTarget"
                Move-Item -LiteralPath $script:CopilotInstructionsTarget -Destination $backupTarget -Force
            }
        }

        if (-not (Test-Path -LiteralPath $copilotTargetParent)) {
            New-Item -ItemType Directory -Path $copilotTargetParent -Force | Out-Null
        }

        if (-not (Test-Path -LiteralPath $script:CopilotInstructionsTarget)) {
            New-Item -ItemType SymbolicLink -Path $script:CopilotInstructionsTarget -Target $script:CopilotInstructionsSource -Force | Out-Null
            Write-Success "Copilot instructions linked: $($script:CopilotInstructionsTarget) -> $($script:CopilotInstructionsSource)"
        }

        if (Test-Path -LiteralPath $script:CopilotSkillsSource -PathType Container) {
            if (Test-Path -LiteralPath $script:CopilotSkillsTarget) {
                if (Test-IsSymlink $script:CopilotSkillsTarget) {
                    $existingLink = (Get-Item -LiteralPath $script:CopilotSkillsTarget).Target
                    if ($existingLink -eq $script:CopilotSkillsSource) {
                        Write-Success "Copilot skills already linked correctly"
                    }
                    else {
                        Remove-Item -LiteralPath $script:CopilotSkillsTarget -Force
                    }
                }
                else {
                    if (-not (Test-Path $BackupPath)) {
                        New-Item -ItemType Directory -Path $BackupPath -Force | Out-Null
                    }

                    $backupTarget = Join-Path $BackupPath "copilot-skills"
                    Write-Warning "Backing up existing Copilot skills to $backupTarget"
                    Move-Item -LiteralPath $script:CopilotSkillsTarget -Destination $backupTarget -Force
                }
            }

            if (-not (Test-Path -LiteralPath $script:CopilotSkillsTarget)) {
                New-Item -ItemType Junction -Path $script:CopilotSkillsTarget -Target $script:CopilotSkillsSource -Force | Out-Null
                Write-Success "Copilot skills linked: $($script:CopilotSkillsTarget) -> $($script:CopilotSkillsSource)"
            }
        }
    }
    catch {
        Write-Error "Failed to link agents: $_"
    }
}

function Invoke-UnlinkAgents {
    param($LatestBackup)

    if (Test-Path -LiteralPath $script:AgentsTarget) {
        if (Test-IsSymlink $script:AgentsTarget) {
            Remove-Item -LiteralPath $script:AgentsTarget -Force
            Write-Success "Removed symlink: agents"

            if ($LatestBackup) {
                $backupSource = Join-Path $LatestBackup.FullName "agents"
                if (Test-Path -LiteralPath $backupSource) {
                    Move-Item -LiteralPath $backupSource -Destination $script:AgentsTarget -Force
                    Write-Info "Restored backup for: agents"
                }
            }
        }
        else {
            Write-Warning "agents is not a symlink, skipping"
        }
    }

    if (Test-Path -LiteralPath $script:CodexAgentsTarget) {
        if (Test-IsSymlink $script:CodexAgentsTarget) {
            Remove-Item -LiteralPath $script:CodexAgentsTarget -Force
            Write-Success "Removed symlink: Codex AGENTS.md"

            if ($LatestBackup) {
                $backupSource = Join-Path $LatestBackup.FullName "codex-AGENTS.md"
                if (Test-Path -LiteralPath $backupSource) {
                    Move-Item -LiteralPath $backupSource -Destination $script:CodexAgentsTarget -Force
                    Write-Info "Restored backup for: Codex AGENTS.md"
                }
            }
        }
        else {
            Write-Warning "Codex AGENTS.md is not a symlink, skipping"
        }
    }

    if (Test-Path -LiteralPath $script:CopilotInstructionsTarget) {
        if (Test-IsSymlink $script:CopilotInstructionsTarget) {
            Remove-Item -LiteralPath $script:CopilotInstructionsTarget -Force
            Write-Success "Removed symlink: Copilot instructions"

            if ($LatestBackup) {
                $backupSource = Join-Path $LatestBackup.FullName "copilot-instructions.md"
                if (Test-Path -LiteralPath $backupSource) {
                    Move-Item -LiteralPath $backupSource -Destination $script:CopilotInstructionsTarget -Force
                    Write-Info "Restored backup for: Copilot instructions"
                }
            }
        }
        else {
            Write-Warning "Copilot instructions are not a symlink, skipping"
        }
    }

    if (Test-Path -LiteralPath $script:CopilotSkillsTarget) {
        if (Test-IsSymlink $script:CopilotSkillsTarget) {
            Remove-Item -LiteralPath $script:CopilotSkillsTarget -Force
            Write-Success "Removed symlink: Copilot skills"

            if ($LatestBackup) {
                $backupSource = Join-Path $LatestBackup.FullName "copilot-skills"
                if (Test-Path -LiteralPath $backupSource) {
                    Move-Item -LiteralPath $backupSource -Destination $script:CopilotSkillsTarget -Force
                    Write-Info "Restored backup for: Copilot skills"
                }
            }
        }
        else {
            Write-Warning "Copilot skills are not a symlink, skipping"
        }
    }
}

function Invoke-StatusAgents {
    if (-not (Test-Path -LiteralPath $script:AgentsSource -PathType Container)) {
        return
    }

    $status = if (-not (Test-Path -LiteralPath $script:AgentsTarget)) {
        "Not linked"
    } elseif (Test-IsSymlink $script:AgentsTarget) {
        $linkTarget = (Get-Item -LiteralPath $script:AgentsTarget).Target
        if ($linkTarget -eq $script:AgentsSource) { "Linked" } else { "Wrong target" }
    } else {
        "Exists (not symlink)"
    }

    [PSCustomObject]@{
        Config = "agents"
        Status = $status
    }

    $codexStatus = if (-not (Test-Path -LiteralPath $script:CodexAgentsTarget)) {
        "Not linked"
    } elseif (Test-IsSymlink $script:CodexAgentsTarget) {
        $linkTarget = (Get-Item -LiteralPath $script:CodexAgentsTarget).Target
        if ($linkTarget -eq $script:CodexAgentsSource) { "Linked" } else { "Wrong target" }
    } else {
        "Exists (not symlink)"
    }

    [PSCustomObject]@{
        Config = "codex/AGENTS.md"
        Status = $codexStatus
    }

    $copilotStatus = if (-not (Test-Path -LiteralPath $script:CopilotInstructionsTarget)) {
        "Not linked"
    } elseif (Test-IsSymlink $script:CopilotInstructionsTarget) {
        $linkTarget = (Get-Item -LiteralPath $script:CopilotInstructionsTarget).Target
        if ($linkTarget -eq $script:CopilotInstructionsSource) { "Linked" } else { "Wrong target" }
    } else {
        "Exists (not symlink)"
    }

    [PSCustomObject]@{
        Config = "copilot/instructions"
        Status = $copilotStatus
    }

    $copilotSkillsStatus = if (-not (Test-Path -LiteralPath $script:CopilotSkillsTarget)) {
        "Not linked"
    } elseif (Test-IsSymlink $script:CopilotSkillsTarget) {
        $linkTarget = (Get-Item -LiteralPath $script:CopilotSkillsTarget).Target
        if ($linkTarget -eq $script:CopilotSkillsSource) { "Linked" } else { "Wrong target" }
    } else {
        "Exists (not symlink)"
    }

    [PSCustomObject]@{
        Config = "copilot/skills"
        Status = $copilotSkillsStatus
    }
}

function Test-IsAdmin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Invoke-Link {
    Write-Header "Creating symlinks for dotfiles"

    Ensure-XdgConfigHome

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
        $displayName = Get-ConfigDisplayName $config
        $target = Get-ConfigTargetPath $config
        $backupName = Get-ConfigBackupName $config

        Write-Info "Processing: $displayName"

        foreach ($legacyTarget in (Get-ConfigLegacyTargetPaths $config)) {
            if ($legacyTarget -eq $target -or -not (Test-Path -LiteralPath $legacyTarget)) {
                continue
            }

            if (Test-IsSymlink $legacyTarget) {
                Remove-Item -LiteralPath $legacyTarget -Force
                Write-Info "Removed legacy target: $legacyTarget"
                continue
            }

            if (-not (Test-Path $backupPath)) {
                New-Item -ItemType Directory -Path $backupPath -Force | Out-Null
            }

            $legacyBackupName = Get-ConfigLegacyBackupName $config $legacyTarget
            $legacyBackupTarget = Join-Path $backupPath $legacyBackupName
            Write-Warning "Backing up legacy $legacyTarget to $legacyBackupTarget"
            Move-Item -LiteralPath $legacyTarget -Destination $legacyBackupTarget -Force
        }

        # Check if target already exists
        if (Test-Path -LiteralPath $target) {
            if (Test-IsSymlink $target) {
                $existingLink = (Get-Item -LiteralPath $target).Target
                if ($existingLink -eq $source) {
                    Write-Success "$displayName already linked correctly"
                    continue
                }
                # Remove incorrect symlink
                Remove-Item -LiteralPath $target -Force
            }
            else {
                # Backup existing config
                if (-not (Test-Path $backupPath)) {
                    New-Item -ItemType Directory -Path $backupPath -Force | Out-Null
                }
                $backupTarget = Join-Path $backupPath $backupName
                Write-Warning "Backing up existing $displayName to $backupPath"
                Move-Item -LiteralPath $target -Destination $backupTarget -Force
            }
        }

        # Create symlink
        try {
            $targetParent = Split-Path -Parent $target
            if ($targetParent -and -not (Test-Path -LiteralPath $targetParent)) {
                New-Item -ItemType Directory -Path $targetParent -Force | Out-Null
            }
            New-Item -ItemType SymbolicLink -Path $target -Target $source -Force | Out-Null
            Write-Success "$displayName linked: $target -> $source"
        }
        catch {
            Write-Error "Failed to link $displayName`: $_"
        }
    }

    Invoke-LinkAgents -BackupPath $backupPath
    Invoke-LinkVscodeExtensions
    Invoke-LinkZedThemes

    Write-Header "Linking complete!"
}

function Invoke-Unlink {
    param([string[]]$RequestedConfigs = @())

    Write-Header "Removing symlinks"

    $configs = @(Get-SelectedConfigs -RequestedConfigs $RequestedConfigs)
    if ($configs.Count -eq 0) {
        Write-Warning "No configs found in $($script:ConfigSource)"
        return
    }

    $latestBackup = Get-ChildItem -Path $script:BackupDir -Directory -ErrorAction SilentlyContinue |
                    Sort-Object Name -Descending |
                    Select-Object -First 1

    foreach ($config in $configs) {
        $displayName = Get-ConfigDisplayName $config
        $target = Get-ConfigTargetPath $config

        foreach ($legacyTarget in (Get-ConfigLegacyTargetPaths $config)) {
            if (-not (Test-Path -LiteralPath $legacyTarget)) {
                continue
            }

            if (Test-IsSymlink $legacyTarget) {
                Remove-Item -LiteralPath $legacyTarget -Force
                Write-Info "Removed legacy symlink: $legacyTarget"
            }
            else {
                Write-Warning "Legacy target exists and was left untouched: $legacyTarget"
            }
        }

        if (Test-Path -LiteralPath $target) {
            if (Test-IsSymlink $target) {
                Remove-Item -LiteralPath $target -Force
                Write-Success "Removed symlink: $displayName"

                # Restore backup if available
                if ($latestBackup) {
                    foreach ($backupName in (Get-ConfigRestoreCandidates $config)) {
                        $backupSource = Join-Path $latestBackup.FullName $backupName
                        if (-not (Test-Path -LiteralPath $backupSource)) {
                            continue
                        }

                        Move-Item -LiteralPath $backupSource -Destination $target -Force
                        Write-Info "Restored backup for: $displayName"
                        break
                    }
                }
            }
            else {
                Write-Warning "$displayName is not a symlink, skipping"
            }
        }
    }

    Invoke-UnlinkAgents -LatestBackup $latestBackup
    Invoke-UnlinkVscodeExtensions
    Invoke-UnlinkZedThemes

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
        $displayName = Get-ConfigDisplayName $config
        $target = Get-ConfigTargetPath $config
        $source = Join-Path $script:ConfigSource $config

        $status = if (-not (Test-Path -LiteralPath $target)) {
            $legacyStatus = $null

            foreach ($legacyTarget in (Get-ConfigLegacyTargetPaths $config)) {
                if (-not (Test-Path -LiteralPath $legacyTarget)) {
                    continue
                }

                $legacyStatus = if (Test-IsSymlink $legacyTarget) {
                    "Legacy path linked"
                }
                else {
                    "Legacy path exists"
                }

                break
            }

            if ($legacyStatus) { $legacyStatus } else { "Not linked" }
        }
        elseif (Test-IsSymlink $target) {
            $linkTarget = (Get-Item -LiteralPath $target).Target
            if ($linkTarget -eq $source) { "Linked" } else { "Wrong target" }
        }
        else {
            "Exists (not symlink)"
        }

        $table += [PSCustomObject]@{
            Config = $displayName
            Status = $status
        }
    }

    $table += Invoke-StatusVscodeExtensions
    $table += Invoke-StatusZedThemes
    $table += Invoke-StatusAgents

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

function Invoke-UpdateSkills {
    Write-Header "Updating project skills"

    if (-not (Get-Command node -ErrorAction SilentlyContinue) -or
        -not (Get-Command npx -ErrorAction SilentlyContinue)) {
        Write-Error "node and npx are required"
        exit 1
    }

    $updateScript = Join-Path $script:DotfilesDir "scripts\update-project-skills.mjs"
    & node $updateScript
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to update project skills"
        exit $LASTEXITCODE
    }

    Write-Success "Project skills updated without installing Claude skills"
}

function Invoke-Setup {
    Write-Header "Running full setup (install + link)"
    Invoke-Install
    Invoke-Link
    Write-Header "Setup complete!"
}

function Show-Help {
    Write-Host @"

  dot.ps1 - Dotfiles Management for Windows
  Version: $($script:Version)

  USAGE:
    .\dot.ps1 <command> [config ...]

  COMMANDS:
    link      Create symbolic links from .dotfiles to .config
    unlink    Remove symlinks and restore backups (optionally selected configs)
    status    Show current link status for all configs
    doctor    Run diagnostics and check installation
    edit      Open dotfiles directory in editor
    setup     Install required tools and create symlinks
    install   Install required tools (wezterm, nvim) via winget
    update-skills  Update project skills without installing Claude skills
    help      Show this help message

  EXAMPLES:
    .\dot.ps1 link       # Link all configs
    .\dot.ps1 unlink     # Unlink all configs
    .\dot.ps1 unlink nvim zed  # Unlink selected configs
    .\dot.ps1 status     # Check what's linked
    .\dot.ps1 doctor     # Run health checks
    .\dot.ps1 setup      # Install tools and link configs
    .\dot.ps1 install    # Install wezterm and nvim
    .\dot.ps1 update-skills  # Update project skills only

  NOTE:
    The 'link' command requires Administrator privileges.

"@
}

# Main execution
if ($Configs.Count -gt 0 -and $Command -ne "unlink") {
    Write-Warning "Ignoring extra arguments; only unlink accepts config names"
}

switch ($Command) {
    "link"    { Invoke-Link }
    "unlink"  { Invoke-Unlink -RequestedConfigs $Configs }
    "status"  { Invoke-Status }
    "doctor"  { Invoke-Doctor }
    "edit"    { Invoke-Edit }
    "install"     { Invoke-Install }
    "update-skills" { Invoke-UpdateSkills }
    "setup"       { Invoke-Setup }
    "help"        { Show-Help }
    default   { Show-Help }
}
