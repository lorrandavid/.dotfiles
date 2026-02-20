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
    find "$CONFIG_SOURCE" -mindepth 1 -maxdepth 1 -type d ! -iname 'powershell' -printf '%f\n' | sort
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
        local target="$CONFIG_TARGET/$config"

        write_info "Processing: $config"

        if [[ -e "$target" || -L "$target" ]]; then
            if is_symlink "$target"; then
                local existing_link
                existing_link=$(readlink -f "$target")
                local real_source
                real_source=$(readlink -f "$source")
                if [[ "$existing_link" == "$real_source" ]]; then
                    write_success "$config already linked correctly"
                    continue
                fi
                rm -f "$target"
            else
                # Backup existing config
                mkdir -p "$backup_path"
                write_warning "Backing up existing $config to $backup_path"
                mv "$target" "$backup_path/$config"
            fi
        fi

        # Create symlink
        if ln -s "$source" "$target" 2>/dev/null; then
            write_success "$config linked: $target -> $source"
        else
            write_error "Failed to link $config"
        fi
    done

    write_header "Linking complete!"
}

do_unlink() {
    write_header "Removing symlinks"

    mapfile -t configs < <(get_config_items)

    local latest_backup=""
    if [[ -d "$BACKUP_DIR" ]]; then
        latest_backup=$(find "$BACKUP_DIR" -mindepth 1 -maxdepth 1 -type d | sort -r | head -n1)
    fi

    for config in "${configs[@]}"; do
        local target="$CONFIG_TARGET/$config"

        if [[ -e "$target" || -L "$target" ]]; then
            if is_symlink "$target"; then
                rm -f "$target"
                write_success "Removed symlink: $config"

                # Restore backup if available
                if [[ -n "$latest_backup" && -e "$latest_backup/$config" ]]; then
                    mv "$latest_backup/$config" "$target"
                    write_info "Restored backup for: $config"
                fi
            else
                write_warning "$config is not a symlink, skipping"
            fi
        fi
    done

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
        local target="$CONFIG_TARGET/$config"
        local source="$CONFIG_SOURCE/$config"
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

        printf "%-30s %s\n" "$config" "$status"
    done
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
    ./dot.sh <command>

  COMMANDS:
    link      Create symbolic links from .dotfiles to .config
    unlink    Remove symbolic links and restore backups
    status    Show current link status for all configs
    doctor    Run diagnostics and check installation
    edit      Open dotfiles directory in editor
    setup     Install required tools and create symlinks
    install   Install required tools (wezterm, nvim, opencode, copilot) via package manager
    help      Show this help message

  EXAMPLES:
    ./dot.sh link       # Link all configs
    ./dot.sh status     # Check what's linked
    ./dot.sh doctor     # Run health checks
    ./dot.sh setup      # Install tools and link configs
    ./dot.sh install    # Install wezterm, nvim, opencode, and copilot

EOF
}

# Main execution
case "${1:-help}" in
    link)    do_link ;;
    unlink)  do_unlink ;;
    status)  do_status ;;
    doctor)  do_doctor ;;
    edit)    do_edit ;;
    install) do_install ;;
    setup)   do_setup ;;
    help)    show_help ;;
    *)
        write_error "Unknown command: $1"
        show_help
        exit 1
        ;;
esac
