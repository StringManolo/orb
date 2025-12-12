#!/usr/bin/env bash

set -euo pipefail

ORB_VERSION="0.1.0"
ORB_REPO="https://github.com/stringmanolo/orb"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${GREEN}[orb-install]${NC} $*"; }
info() { echo -e "${BLUE}[orb-install]${NC} $*"; }
warn() { echo -e "${YELLOW}[orb-install]${NC} $*"; }
error() { echo -e "${RED}[orb-install:error]${NC} $*" >&2; }
die() { error "$@"; exit 1; }

show_banner() {
    cat << "EOF"
  ___  ____  ____
 / _ \|  _ \| __ )
| | | | |_) |  _ \
| |_| |  _ <| |_) |
 \___/|_| \_\____/
EOF
    echo -e "${BLUE}Bash Package Manager v${ORB_VERSION}${NC}"
    echo ""
}

get_install_dir() {
    local install_type="${1:-auto}"
    local default_system="/usr/local/bin"
    local default_user="${HOME}/.local/bin"
    
    case "$install_type" in
        "system")
            echo "$default_system"
            ;;
        "user")
            mkdir -p "$default_user" 2>/dev/null || true
            echo "$default_user"
            ;;
        "auto"|*)
            if [[ "$EUID" -eq 0 ]] || [[ -w "$default_system" ]]; then
                echo "$default_system"
            else
                mkdir -p "$default_user" 2>/dev/null || true
                if [[ -w "$default_user" ]] || [[ -w "$(dirname "$default_user")" ]]; then
                    echo "$default_user"
                else
                    echo "${HOME}/bin"
                fi
            fi
            ;;
    esac
}

check_dependencies() {
    log "Checking dependencies..."
    
    local missing=()
    
    if ! command -v curl &>/dev/null && ! command -v wget &>/dev/null; then
        missing+=("curl or wget")
    fi
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        error "Missing dependencies:"
        for dep in "${missing[@]}"; do
            error "  - $dep"
        done
        return 1
    fi
    
    log "Dependencies: ✓"
    return 0
}

download_orb() {
    local url="$1"
    local output="$2"
    
    if command -v curl &>/dev/null; then
        curl -sSLf -o "$output" "$url" || return 1
    elif command -v wget &>/dev/null; then
        wget -q -O "$output" "$url" || return 1
    else
        return 1
    fi
}

install_orb() {
    local install_dir="$1"
    local check_update="$2"
    
    log "Installing to: $install_dir"
    
    mkdir -p "$install_dir" 2>/dev/null || {
        error "Cannot create directory: $install_dir"
        return 1
    }
    
    local temp_file
    temp_file="$(mktemp)"
    local orb_url="${ORB_REPO}/raw/main/orb.sh"
    
    info "Downloading orb..."
    if ! download_orb "$orb_url" "$temp_file"; then
        rm -f "$temp_file"
        die "Download failed"
    fi
    
    chmod +x "$temp_file"
    
    local orb_path="${install_dir}/orb"
    
    if [[ -f "$orb_path" ]]; then
        local backup="${orb_path}.backup.$(date +%Y%m%d_%H%M%S)"
        cp "$orb_path" "$backup"
        info "Backup created: $backup"
    fi
    
    if mv "$temp_file" "$orb_path"; then
        log "Installed: ✓"
        
        if [[ -w "$orb_path" ]]; then
            log "Self-update capability: ✓ Enabled"
        else
            warn "Self-update capability: ✗ Disabled (no write permission)"
            warn "  To enable: chmod u+w '$orb_path'"
        fi
        
        local orb_home="${HOME}/.orb"
        mkdir -p "${orb_home}/"{cache,installed,repos} 2>/dev/null || true
        
        local official_repo="${orb_home}/repos/official"
        if [[ ! -f "$official_repo" ]]; then
            echo "https://github.com/stringmanolo/orbpackages" > "$official_repo"
            info "Official repository configured"
        fi
        
        if "$orb_path" --version &>/dev/null; then
            log "Verification: ✓ Success"
            
            if ! command -v orb &>/dev/null; then
                echo ""
                warn "Note: 'orb' is not in your PATH"
                warn "Add this to your shell configuration:"
                warn "  export PATH=\"\$PATH:$install_dir\""
                echo ""
            fi
            
            if [[ "$check_update" == "true" ]]; then
                info "Checking for updates..."
                if "$orb_path" --check-update 2>/dev/null | grep -q "Update available"; then
                    warn "Update available! Run 'orb --update'"
                fi
            fi
            
            return 0
        else
            error "Verification failed"
            return 1
        fi
    else
        error "Installation failed"
        rm -f "$temp_file"
        return 1
    fi
}

show_help() {
    cat << EOF
Orb Installer v${ORB_VERSION}

Usage: $(basename "$0") [options]

Options:
  -h, --help          Show this help
  -v, --version       Show version
  --user              Install to ~/.local/bin (recommended for users)
  --system            Install to /usr/local/bin (requires sudo)
  --dir PATH          Install to custom directory
  --no-check          Skip dependency checks
  --check-update      Check for updates after installation
  --force             Force installation even if orb exists

Examples:
  # Default installation (auto-detects best location)
  curl -sSL ${ORB_REPO}/raw/main/install.sh | bash
  
  # Install to user directory (recommended)
  curl -sSL ${ORB_REPO}/raw/main/install.sh | bash -s -- --user
  
  # Install to system directory (may need sudo)
  curl -sSL ${ORB_REPO}/raw/main/install.sh | sudo bash -s -- --system
  
  # Custom directory
  curl -sSL ${ORB_REPO}/raw/main/install.sh | bash -s -- --dir ~/myapps
EOF
}

main() {
    local install_type="auto"
    local custom_dir=""
    local skip_check=false
    local check_update=false
    local force=false
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help) show_help; exit 0 ;;
            -v|--version) echo "Orb Installer v${ORB_VERSION}"; exit 0 ;;
            --user) install_type="user"; shift ;;
            --system) install_type="system"; shift ;;
            --dir) custom_dir="$2"; shift 2 ;;
            --no-check) skip_check=true; shift ;;
            --check-update) check_update=true; shift ;;
            --force) force=true; shift ;;
            *) error "Unknown option: $1"; show_help; exit 1 ;;
        esac
    done
    
    show_banner
    
    local install_dir
    if [[ -n "$custom_dir" ]]; then
        install_dir="$custom_dir"
    else
        install_dir="$(get_install_dir "$install_type")"
    fi
    
    info "Installation directory: $install_dir"
    
    if [[ "$skip_check" != "true" ]]; then
        check_dependencies || exit 1
    fi
    
    local orb_path="${install_dir}/orb"
    if [[ -f "$orb_path" ]] && [[ "$force" != "true" ]]; then
        warn "Orb is already installed at: $orb_path"
        read -rp "Overwrite? [y/N]: " answer
        if [[ "$answer" != "y" ]] && [[ "$answer" != "Y" ]]; then
            info "Installation cancelled"
            exit 0
        fi
    fi
    
    if install_orb "$install_dir" "$check_update"; then
        echo ""
        log "🎉 Installation successful!"
        log ""
        log "Quick start:"
        log "  orb --help                 # Show help"
        log "  orb list                   # List available packages"
        log "  orb init my-project        # Start a new project"
        log "  orb install parseCLI       # Install a package"
        log "  orb --update               # Update orb itself"
        log ""
        log "Need help? Visit: ${ORB_REPO}"
        echo ""
    else
        die "Installation failed"
    fi
}

main "$@"
