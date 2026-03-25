#!/usr/bin/env bash
#
# dot.sh - Dotfiles management script for Linux / WSL.
#
# A simple automation tool to manage configuration files by creating
# symbolic links from .dotfiles/.config to the user's .config folder.
#
# Usage:
#   ./dot.sh link       # Create symlinks for all configs
#   ./dot.sh unlink     # Remove symlinks and restore backups
#   ./dot.sh unlink nvim opencode  # Remove specific symlinks
#   ./dot.sh status     # Show current link status
#   ./dot.sh doctor     # Run diagnostics
#   ./dot.sh edit       # Open dotfiles in editor
#   ./dot.sh install    # Install required tools via package manager
#   ./dot.sh help       # Show help message

set -euo pipefail

# Script configuration
VERSION="1.0.0"
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_SOURCE="$DOTFILES_DIR/.config"
CONFIG_TARGET="${XDG_CONFIG_HOME:-$HOME/.config}"
BACKUP_DIR="$DOTFILES_DIR/backups"

# Colors
BLUE='\033[0;34m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

write_header()  { echo -e "\n${BLUE}==> $1${NC}"; }
write_success() { echo -e "${GREEN}[OK] $1${NC}"; }
write_error()   { echo -e "${RED}[X] $1${NC}"; }
write_warning() { echo -e "${YELLOW}[!] $1${NC}"; }
write_info()    { echo -e "${CYAN}[i] $1${NC}"; }

get_config_items() {
    if [[ ! -d "$CONFIG_SOURCE" ]]; then
        return
    fi
    find "$CONFIG_SOURCE" -mindepth 1 -maxdepth 1 -type d ! -iname 'powershell' ! -iname 'windows-terminal' ! -iname 'vscode' -printf '%f\n' | sort
}

config_in_list() {
    local candidate="$1"
    shift

    local item
    for item in "$@"; do
        if [[ "$item" == "$candidate" ]]; then
            return 0
        fi
    done

    return 1
}

get_selected_configs() {
    local -a requested_configs=("$@")
    local -a available_configs
    mapfile -t available_configs < <(get_config_items)

    if [[ ${#requested_configs[@]} -eq 0 ]]; then
        if [[ ${#available_configs[@]} -gt 0 ]]; then
            printf '%s\n' "${available_configs[@]}"
        fi
        return 0
    fi

    if [[ ${#available_configs[@]} -eq 0 ]]; then
        return 0
    fi

    local -A seen_configs=()
    local requested_config
    for requested_config in "${requested_configs[@]}"; do
        if ! config_in_list "$requested_config" "${available_configs[@]}"; then
            write_error "Unknown config: $requested_config" >&2
            write_info "Available configs: ${available_configs[*]}" >&2
            return 1
        fi

        if [[ -n "${seen_configs[$requested_config]:-}" ]]; then
            continue
        fi

        seen_configs[$requested_config]=1
        printf '%s\n' "$requested_config"
    done
}

get_path_basename() {
    local path="$1"
    printf '%s\n' "${path##*/}"
}

get_config_display_name() {
    local config="$1"

    if [[ "$config" == ".copilot" ]]; then
        printf '%s\n' "~/.copilot"
        return
    fi

    printf '%s\n' "$config"
}

get_config_target_path() {
    local config="$1"

    if [[ "$config" == ".copilot" ]]; then
        printf '%s\n' "$HOME/.copilot"
        return
    fi

    printf '%s\n' "$CONFIG_TARGET/$config"
}

get_config_backup_name() {
    local config="$1"

    if [[ "$config" == ".copilot" ]]; then
        printf '%s\n' ".copilot"
        return
    fi

    printf '%s\n' "$config"
}

get_config_legacy_target_paths() {
    local config="$1"

    if [[ "$config" == ".copilot" ]]; then
        printf '%s\n' "$CONFIG_TARGET/copilot"
        printf '%s\n' "$CONFIG_TARGET/.copilot"
    fi
}

get_config_legacy_backup_name() {
    local config="$1"
    local legacy_target="$2"
    local legacy_name
    legacy_name=$(get_path_basename "$legacy_target")

    if [[ "$config" == ".copilot" && "$legacy_name" == ".copilot" ]]; then
        printf '%s\n' "config-.copilot"
        return
    fi

    printf '%s\n' "$legacy_name"
}

get_config_restore_candidates() {
    local config="$1"

    printf '%s\n' "$(get_config_backup_name "$config")"

    if [[ "$config" == ".copilot" ]]; then
        printf '%s\n' "copilot"
        printf '%s\n' "config-.copilot"
    fi
}

ensure_xdg_config_home() {
    local desired_config_home="$HOME/.config"
    local profile_file="$HOME/.profile"
    local export_line='export XDG_CONFIG_HOME="$HOME/.config"'

    if [[ "${XDG_CONFIG_HOME:-}" == "$desired_config_home" ]]; then
        CONFIG_TARGET="$XDG_CONFIG_HOME"
        write_success "XDG_CONFIG_HOME already set: $XDG_CONFIG_HOME"
        return
    fi

    if [[ -f "$profile_file" ]] && grep -Fqx "$export_line" "$profile_file"; then
        write_success "XDG_CONFIG_HOME already configured in $profile_file"
    else
        printf '\n%s\n' "$export_line" >> "$profile_file"
        write_success "Configured XDG_CONFIG_HOME in $profile_file"
    fi

    export XDG_CONFIG_HOME="$desired_config_home"
    CONFIG_TARGET="$XDG_CONFIG_HOME"
}

is_symlink() {
    [[ -L "$1" ]]
}

# VS Code extension linking helpers
VSCODE_EXT_SOURCE="$CONFIG_SOURCE/vscode/extensions"
VSCODE_EXT_TARGET="$HOME/.vscode/extensions"

get_vscode_extensions() {
    if [[ ! -d "$VSCODE_EXT_SOURCE" ]]; then
        return
    fi
    find "$VSCODE_EXT_SOURCE" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort
}

do_link_vscode_extensions() {
    mapfile -t extensions < <(get_vscode_extensions)
    if [[ ${#extensions[@]} -eq 0 ]]; then
        return
    fi

    write_header "Linking VS Code extensions"
    mkdir -p "$VSCODE_EXT_TARGET"

    for ext in "${extensions[@]}"; do
        local source="$VSCODE_EXT_SOURCE/$ext"
        local target="$VSCODE_EXT_TARGET/$ext"

        if [[ -e "$target" || -L "$target" ]]; then
            if is_symlink "$target"; then
                local existing_link
                existing_link=$(readlink -f "$target")
                local real_source
                real_source=$(readlink -f "$source")
                if [[ "$existing_link" == "$real_source" ]]; then
                    write_success "vscode/$ext already linked correctly"
                    continue
                fi
                rm -f "$target"
            else
                write_warning "vscode/$ext exists and is not a symlink, skipping"
                continue
            fi
        fi

        if ln -s "$source" "$target" 2>/dev/null; then
            write_success "vscode/$ext linked: $target -> $source"
        else
            write_error "Failed to link vscode/$ext"
        fi
    done
}

do_unlink_vscode_extensions() {
    mapfile -t extensions < <(get_vscode_extensions)
    if [[ ${#extensions[@]} -eq 0 ]]; then
        return
    fi

    write_header "Removing VS Code extension symlinks"

    for ext in "${extensions[@]}"; do
        local target="$VSCODE_EXT_TARGET/$ext"

        if [[ -e "$target" || -L "$target" ]]; then
            if is_symlink "$target"; then
                rm -f "$target"
                write_success "Removed symlink: vscode/$ext"
            else
                write_warning "vscode/$ext is not a symlink, skipping"
            fi
        fi
    done
}

do_status_vscode_extensions() {
    mapfile -t extensions < <(get_vscode_extensions)
    if [[ ${#extensions[@]} -eq 0 ]]; then
        return
    fi

    for ext in "${extensions[@]}"; do
        local source="$VSCODE_EXT_SOURCE/$ext"
        local target="$VSCODE_EXT_TARGET/$ext"
        local status

        if [[ ! -e "$target" && ! -L "$target" ]]; then
            status="Not linked"
        elif is_symlink "$target"; then
            local link_target
            link_target=$(readlink -f "$target")
            local real_source
            real_source=$(readlink -f "$source")
            if [[ "$link_target" == "$real_source" ]]; then
                status="Linked"
            else
                status="Wrong target"
            fi
        else
            status="Exists (not symlink)"
        fi

        printf "%-30s %s\n" "vscode/$ext" "$status"
    done
}

do_link() {
    write_header "Creating symlinks for dotfiles"
    ensure_xdg_config_home

    mapfile -t configs < <(get_config_items)
    if [[ ${#configs[@]} -eq 0 ]]; then
        write_warning "No configs found in $CONFIG_SOURCE"
        return
    fi

    # Ensure target directory exists
    mkdir -p "$CONFIG_TARGET"

    local timestamp
    timestamp=$(date +"%Y%m%d_%H%M%S")
    local backup_path="$BACKUP_DIR/$timestamp"
    local powershell_target="$CONFIG_TARGET/powershell"

    if [[ -L "$powershell_target" ]]; then
        rm -f "$powershell_target"
        write_info "Removed PowerShell symlink for Linux environment"
    fi

    for config in "${configs[@]}"; do
        local source="$CONFIG_SOURCE/$config"
        local display_name
        display_name=$(get_config_display_name "$config")
        local target
        target=$(get_config_target_path "$config")
        local backup_name
        backup_name=$(get_config_backup_name "$config")

        write_info "Processing: $display_name"

        while IFS= read -r legacy_target; do
            [[ -z "$legacy_target" ]] && continue

            if [[ "$legacy_target" == "$target" || ! -e "$legacy_target" && ! -L "$legacy_target" ]]; then
                continue
            fi

            if is_symlink "$legacy_target"; then
                rm -f "$legacy_target"
                write_info "Removed legacy target: $legacy_target"
                continue
            fi

            mkdir -p "$backup_path"
            local legacy_backup_name
            legacy_backup_name=$(get_config_legacy_backup_name "$config" "$legacy_target")
            local legacy_backup_target="$backup_path/$legacy_backup_name"

            write_warning "Backing up legacy $legacy_target to $legacy_backup_target"
            mv "$legacy_target" "$legacy_backup_target"
        done < <(get_config_legacy_target_paths "$config")

        if [[ -e "$target" || -L "$target" ]]; then
            if is_symlink "$target"; then
                local existing_link
                existing_link=$(readlink -f "$target")
                local real_source
                real_source=$(readlink -f "$source")
                if [[ "$existing_link" == "$real_source" ]]; then
                    write_success "$display_name already linked correctly"
                    continue
                fi
                rm -f "$target"
            else
                # Backup existing config
                mkdir -p "$backup_path"
                write_warning "Backing up existing $display_name to $backup_path"
                mv "$target" "$backup_path/$backup_name"
            fi
        fi

        # Create symlink
        mkdir -p "$(dirname "$target")"
        if ln -s "$source" "$target" 2>/dev/null; then
            write_success "$display_name linked: $target -> $source"
        else
            write_error "Failed to link $display_name"
        fi
    done

    do_link_vscode_extensions

    write_header "Linking complete!"
}

do_unlink() {
    write_header "Removing symlinks"

    local selected_configs=""
    local -a configs
    selected_configs=$(get_selected_configs "$@") || return 1
    if [[ -n "$selected_configs" ]]; then
        mapfile -t configs <<< "$selected_configs"
    fi
    if [[ ${#configs[@]} -eq 0 ]]; then
        write_warning "No configs found in $CONFIG_SOURCE"
        return
    fi

    local latest_backup=""
    if [[ -d "$BACKUP_DIR" ]]; then
        latest_backup=$(find "$BACKUP_DIR" -mindepth 1 -maxdepth 1 -type d | sort -r | head -n1)
    fi

    for config in "${configs[@]}"; do
        local display_name
        display_name=$(get_config_display_name "$config")
        local target
        target=$(get_config_target_path "$config")

        while IFS= read -r legacy_target; do
            [[ -z "$legacy_target" ]] && continue

            if [[ ! -e "$legacy_target" && ! -L "$legacy_target" ]]; then
                continue
            fi

            if is_symlink "$legacy_target"; then
                rm -f "$legacy_target"
                write_info "Removed legacy symlink: $legacy_target"
            else
                write_warning "Legacy target exists and was left untouched: $legacy_target"
            fi
        done < <(get_config_legacy_target_paths "$config")

        if [[ -e "$target" || -L "$target" ]]; then
            if is_symlink "$target"; then
                rm -f "$target"
                write_success "Removed symlink: $display_name"

                # Restore backup if available
                if [[ -n "$latest_backup" ]]; then
                    local backup_source=""
                    local backup_name
                    while IFS= read -r backup_name; do
                        [[ -z "$backup_name" ]] && continue

                        if [[ -e "$latest_backup/$backup_name" || -L "$latest_backup/$backup_name" ]]; then
                            backup_source="$latest_backup/$backup_name"
                            break
                        fi
                    done < <(get_config_restore_candidates "$config")

                    if [[ -n "$backup_source" ]]; then
                        mv "$backup_source" "$target"
                        write_info "Restored backup for: $display_name"
                    fi
                fi
            else
                write_warning "$display_name is not a symlink, skipping"
            fi
        fi
    done

    do_unlink_vscode_extensions

    write_header "Unlink complete!"
}

do_status() {
    write_header "Dotfiles Status"

    echo ""
    echo "Source: $CONFIG_SOURCE"
    echo "Target: $CONFIG_TARGET"
    echo ""

    printf "%-30s %s\n" "CONFIG" "STATUS"
    printf "%-30s %s\n" "------" "------"

    mapfile -t configs < <(get_config_items)
    for config in "${configs[@]}"; do
        local display_name
        display_name=$(get_config_display_name "$config")
        local target
        target=$(get_config_target_path "$config")
        local source="$CONFIG_SOURCE/$config"
        local status

        if [[ ! -e "$target" && ! -L "$target" ]]; then
            status="Not linked"

            while IFS= read -r legacy_target; do
                [[ -z "$legacy_target" ]] && continue

                if [[ ! -e "$legacy_target" && ! -L "$legacy_target" ]]; then
                    continue
                fi

                if is_symlink "$legacy_target"; then
                    status="Legacy path linked"
                else
                    status="Legacy path exists"
                fi
                break
            done < <(get_config_legacy_target_paths "$config")
        elif is_symlink "$target"; then
            local link_target
            link_target=$(readlink -f "$target")
            local real_source
            real_source=$(readlink -f "$source")
            if [[ "$link_target" == "$real_source" ]]; then
                status="Linked"
            else
                status="Wrong target"
            fi
        else
            status="Exists (not symlink)"
        fi

        printf "%-30s %s\n" "$display_name" "$status"
    done

    do_status_vscode_extensions

    echo ""
}

do_doctor() {
    write_header "Running diagnostics"

    local issues=0

    # Check if running as root (not required on Linux, but noted)
    if [[ $EUID -eq 0 ]]; then
        write_warning "Running as root (not required for symlinks on Linux)"
    else
        write_success "Running as regular user (symlinks work without root)"
    fi

    # Check dotfiles directory
    if [[ -d "$CONFIG_SOURCE" ]]; then
        local count
        count=$(get_config_items | wc -l)
        write_success "Config source exists: $count configs found"
    else
        write_error "Config source not found: $CONFIG_SOURCE"
        ((issues++))
    fi

    # Check target directory
    if [[ -d "$CONFIG_TARGET" ]]; then
        write_success "Config target exists: $CONFIG_TARGET"
    else
        write_info "Config target will be created: $CONFIG_TARGET"
    fi

    # Check backups
    if [[ -d "$BACKUP_DIR" ]]; then
        local backup_count
        backup_count=$(find "$BACKUP_DIR" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l)
        write_success "Backup directory exists: $backup_count backups"
    else
        write_info "No backups yet"
    fi

    # Check common tools
    for tool in git nvim code opencode copilot; do
        if command -v "$tool" &>/dev/null; then
            write_success "$tool is installed"
        else
            write_info "$tool not found (optional)"
        fi
    done

    if [[ $issues -eq 0 ]]; then
        write_header "All checks passed!"
    else
        write_header "Found $issues issue(s)"
    fi
}

do_edit() {
    write_header "Opening dotfiles in editor"

    local editor=""
    if [[ -n "${EDITOR:-}" ]]; then
        editor="$EDITOR"
    elif command -v code &>/dev/null; then
        editor="code"
    elif command -v nvim &>/dev/null; then
        editor="nvim"
    elif command -v vim &>/dev/null; then
        editor="vim"
    elif command -v nano &>/dev/null; then
        editor="nano"
    fi

    if [[ -n "$editor" ]]; then
        write_info "Opening with: $editor"
        "$editor" "$DOTFILES_DIR"
    else
        write_error "No editor found"
    fi
}

do_install() {
    write_header "Installing required tools"

    local pkg_manager=""
    if command -v apt-get &>/dev/null; then
        pkg_manager="apt"
    elif command -v dnf &>/dev/null; then
        pkg_manager="dnf"
    elif command -v pacman &>/dev/null; then
        pkg_manager="pacman"
    elif command -v brew &>/dev/null; then
        pkg_manager="brew"
    fi

    if [[ -z "$pkg_manager" ]]; then
        write_error "No supported package manager found (apt, dnf, pacman, brew)."
        return 1
    fi

    write_info "Detected package manager: $pkg_manager"

    declare -A tools=(
        [wezterm]="wezterm"
        [nvim]="neovim"
    )

    for tool in "${!tools[@]}"; do
        write_info "Checking: $tool"

        if command -v "$tool" &>/dev/null; then
            write_success "$tool is already installed"
        else
            local pkg="${tools[$tool]}"
            write_info "Installing $tool..."
            case "$pkg_manager" in
                apt)
                    if [[ "$tool" == "wezterm" ]]; then
                        write_warning "wezterm requires manual installation on apt-based systems."
                        write_info "See: https://wezfurlong.org/wezterm/install/linux.html"
                        continue
                    fi
                    sudo apt-get install -y "$pkg"
                    ;;
                dnf)
                    if [[ "$tool" == "wezterm" ]]; then
                        sudo dnf copr enable -y wezfurlong/wezterm-nightly
                        sudo dnf install -y wezterm
                    else
                        sudo dnf install -y "$pkg"
                    fi
                    ;;
                pacman)
                    if [[ "$tool" == "wezterm" ]]; then
                        pkg="wezterm"
                    fi
                    sudo pacman -S --noconfirm "$pkg"
                    ;;
                brew)
                    if [[ "$tool" == "wezterm" ]]; then
                        pkg="wezterm"
                    fi
                    brew install "$pkg"
                    ;;
            esac

            if command -v "$tool" &>/dev/null; then
                write_success "$tool installed successfully"
            else
                write_error "Failed to install $tool"
            fi
        fi
    done

    # Install opencode via official installer if not present
    write_info "Checking: opencode"
    if command -v opencode &>/dev/null; then
        write_success "opencode is already installed"
    else
        write_info "Installing opencode..."
        if curl -fsSL https://opencode.ai/install | bash; then
            if command -v opencode &>/dev/null; then
                write_success "opencode installed successfully"
            else
                write_warning "opencode installed but not yet on PATH (restart terminal)"
            fi
        else
            write_error "Failed to install opencode"
        fi
    fi

    # Install GitHub Copilot CLI via official installer if not present
    write_info "Checking: copilot (GitHub Copilot CLI)"
    if command -v copilot &>/dev/null; then
        write_success "copilot is already installed"
    else
        write_info "Installing GitHub Copilot CLI..."
        if curl -fsSL https://gh.io/copilot-install | bash; then
            if command -v copilot &>/dev/null; then
                write_success "copilot installed successfully"
            else
                write_warning "copilot installed but not yet on PATH (restart terminal)"
            fi
        else
            write_error "Failed to install GitHub Copilot CLI"
        fi
    fi

    write_header "Installation complete!"
    write_info "You may need to restart your terminal for PATH changes to take effect."
}

do_setup() {
    write_header "Running full setup (install + link)"
    do_install
    do_link
    write_header "Setup complete!"
}

show_help() {
    cat <<EOF

  dot.sh - Dotfiles Management for Linux / WSL
  Version: $VERSION

  USAGE:
    ./dot.sh <command> [config ...]

  COMMANDS:
    link      Create symbolic links from .dotfiles to .config
    unlink    Remove symlinks and restore backups (optionally selected configs)
    status    Show current link status for all configs
    doctor    Run diagnostics and check installation
    edit      Open dotfiles directory in editor
    setup     Install required tools and create symlinks
    install   Install required tools (wezterm, nvim, opencode, copilot) via package manager
    help      Show this help message

  EXAMPLES:
    ./dot.sh link       # Link all configs
    ./dot.sh unlink     # Unlink all configs
    ./dot.sh unlink nvim opencode  # Unlink selected configs
    ./dot.sh status     # Check what's linked
    ./dot.sh doctor     # Run health checks
    ./dot.sh setup      # Install tools and link configs
    ./dot.sh install    # Install wezterm, nvim, opencode, and copilot

EOF
}

# Main execution
command="${1:-help}"
if [[ $# -gt 0 ]]; then
    shift
fi

if [[ $# -gt 0 && "$command" != "unlink" ]]; then
    write_warning "Ignoring extra arguments; only unlink accepts config names"
fi

case "$command" in
    link)    do_link ;;
    unlink)  do_unlink "$@" ;;
    status)  do_status ;;
    doctor)  do_doctor ;;
    edit)    do_edit ;;
    install) do_install ;;
    setup)   do_setup ;;
    help)    show_help ;;
    *)
        write_error "Unknown command: $command"
        show_help
        exit 1
        ;;
esac
