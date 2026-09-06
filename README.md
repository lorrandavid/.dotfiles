# .dotfiles

Personal dotfiles repo for Windows and Linux / WSL.

This repo keeps application configs under `./.config/` and provides helper scripts to **symlink** those folders into your `.config` directory:

- **Windows**: `dot.ps1` (PowerShell) — targets `%USERPROFILE%\.config`
- **Linux / WSL**: `dot.sh` (Bash) — targets `$XDG_CONFIG_HOME` (defaults to `~/.config`)

## What's included

Configs currently managed (folders under `./.config/`):

- `nvim`
- `powershell` (Windows only — skipped on Linux)
- `psmux` (Windows only — skipped on Linux)
- `windows-terminal` (Windows scheme snippets — skipped on Linux)
- `wezterm`
- `zed`

The `.config/shared` directory is deprecated and retained only for compatibility. The installers intentionally ignore it. Global agent configuration lives under `.config/.agents`; the installers link that directory to `~/.agents`, link its `AGENTS.md` directly to both `~/.codex/AGENTS.md` and `~/.copilot/copilot-instructions.md`, and link its `skills` directory to `~/.copilot/skills`. Both harnesses therefore load one versioned policy without instruction-file imports. Linking also migrates the legacy whole-directory `~/.copilot` symlink to this file-level layout.

## Prerequisites

**Windows**
- PowerShell or PowerShell 7 (`pwsh`)
- Ability to create symlinks (the script will self-elevate to Administrator for `link`)
- `winget` (App Installer) for the `install` command

**Linux / WSL**
- Bash
- One of: `apt`, `dnf`, `pacman`, or `brew`

## Usage

### Windows

```powershell
.\dot.ps1 help      # Show help
.\dot.ps1 setup     # Install tools and create symlinks (recommended for first run)
.\dot.ps1 link      # Create symlinks into %USERPROFILE%\.config
.\dot.ps1 unlink    # Remove symlinks and restore latest backups
.\dot.ps1 unlink nvim zed  # Remove only selected configs
.\dot.ps1 status    # Show status of each config
.\dot.ps1 doctor    # Run diagnostics
.\dot.ps1 edit      # Open repo in editor
.\dot.ps1 install   # Install wezterm and nvim
```

### Linux / WSL

```bash
./dot.sh help       # Show help
./dot.sh setup      # Install tools and create symlinks (recommended for first run)
./dot.sh link       # Create symlinks into ~/.config
./dot.sh unlink     # Remove symlinks and restore latest backups
./dot.sh unlink nvim zed  # Remove only selected configs
./dot.sh status     # Show status of each config
./dot.sh doctor     # Run diagnostics
./dot.sh edit       # Open repo in editor
./dot.sh install    # Install wezterm and nvim
```

## Install command

Running `install` checks for each tool and installs it if missing:

| Tool | Windows | Linux / WSL |
|------|---------|-------------|
| `wezterm` | `winget install wez.wezterm` | package manager (manual on apt) |
| `nvim` | `winget install Neovim.Neovim` | package manager |
| `psmux` | `winget install marlocarlo.psmux` | Windows only |

## How it works

- **Source**: `./.config/<config>`
- **Target**: `~/.config/<config>` (or `%USERPROFILE%\.config\<config>` on Windows)
- When `link` finds an existing real folder/file at the target (not a symlink), it moves it into `./backups/<timestamp>/` before creating the symlink.
- `unlink` removes symlinks and restores from the **latest** backup folder if available. You can pass one or more config names to target specific entries only.
- On Linux, `dot.sh` also ensures `XDG_CONFIG_HOME` is set in `~/.profile`.
- The `powershell` and `psmux` config folders are skipped on Linux.

## Backups

Backups are stored in `./backups/<timestamp>/`. Each `link` run creates a new timestamped directory only if something needed backing up.

## Adding a new config

1. Add a folder under `./.config/` (e.g. `./.config/mytool/`).
2. Run `./dot.sh link` or `.\dot.ps1 link`.

## Quick start

Clone the repo and run `setup` to install all tools and create symlinks in one step:

```bash
# Linux / WSL
./dot.sh setup
```

```powershell
# Windows
.\dot.ps1 setup
```

## Notes

- On Windows, the `link` command requires Administrator privileges; the script will prompt for elevation automatically.
- On Linux, symlinks do not require elevated privileges.
- The `windows-terminal` folder stores reusable scheme JSON snippets for manual import into Windows Terminal's `settings.json`; linking it into `~/.config` or `%USERPROFILE%\.config` does not apply the scheme automatically.
- `dot.ps1 setup` installs the psmux plugins declared in `.config/psmux/psmux.conf`. PPM keeps plugin code in `%USERPROFILE%\.psmux\plugins`, outside this repository; use `Prefix + I`, `Prefix + U`, and `Prefix + M` to install, update, and remove plugins later.
- Clipboard copy/yank is built into current psmux releases, so the retired `psmux-yank` plugin is represented by `set-clipboard on` instead of being installed.
