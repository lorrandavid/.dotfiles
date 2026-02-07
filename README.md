# .dotfiles (Windows)

Personal dotfiles repo for Windows.

This repo keeps application configs under `./.config/` and provides a small PowerShell helper (`dot.ps1`) to **symlink** those folders into `%USERPROFILE%\.config`.

## What’s included

Configs currently managed (folders under `./.config/`):

- `.copilot`
- `nvim`
- `opencode`
- `powershell`
- `wezterm`

## Prerequisites

- Windows PowerShell or PowerShell 7 (`pwsh`)
- Ability to create symlinks (the script will try to self-elevate to Administrator for `link`)

## Usage

From the repo root:

```powershell
# Show help
.\dot.ps1 help

# Create symlinks (creates/updates %USERPROFILE%\.config\<name> -> .\.config\<name>)
.\dot.ps1 link

# Remove symlinks and restore the latest backups (if any)
.\dot.ps1 unlink

# Show status of each config
.\dot.ps1 status

# Diagnostics (admin check, paths, optional tools)
.\dot.ps1 doctor

# Open repo in your editor (uses $env:EDITOR, then VS Code, then Neovim, then Notepad)
.\dot.ps1 edit
```

## How it works

- Source: `./.config/<config>`
- Target: `%USERPROFILE%\.config\<config>`
- When `link` finds an existing *real* folder/file at the target (not a symlink), it moves it into `./backups/<timestamp>/` before creating the symlink.
- `unlink` removes symlinks and restores from the **latest** backup folder if available.

## Backups

Backups are stored in:

- `./backups/<yyyyMMdd_HHmmss>/`

Each run of `link` creates a new timestamped backup directory *only if something needed backing up*.

## Adding a new config

1. Add a folder under `./.config/` (e.g. `./.config/mytool/`).
2. Run:

```powershell
.\dot.ps1 link
```

## Notes

- The `link` command generally requires Administrator privileges on Windows; the script will prompt for elevation when needed.
