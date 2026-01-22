#!/usr/bin/env bash
#
# Multi-Distro Deployment Script
# Supports: Arch Linux, Ubuntu, Fedora, Debian, CentOS
# Purpose: Automated deployment of development workstations
#
# Author: System Administrator
# Version: 1.0.0
#

set -euo pipefail

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly LOG_DIR="${SCRIPT_DIR}/logs"
readonly LOG_FILE="${LOG_DIR}/deployment-$(date +%Y%m%d-%H%M%S).log"
readonly CONFIG_DIR="${SCRIPT_DIR}/config"
readonly MODULES_DIR="${SCRIPT_DIR}/modules"

# Create necessary directories
mkdir -p "${LOG_DIR}" "${CONFIG_DIR}" "${MODULES_DIR}"

#######################################
# Logging Functions
#######################################

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $*" | tee -a "${LOG_FILE}"
}

log_error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR:${NC} $*" | tee -a "${LOG_FILE}" >&2
}

log_warning() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING:${NC} $*" | tee -a "${LOG_FILE}"
}

log_info() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] INFO:${NC} $*" | tee -a "${LOG_FILE}"
}

#######################################
# Error Handling
#######################################

error_exit() {
    log_error "$1"
    exit "${2:-1}"
}

cleanup() {
    log "Cleaning up..."
    # Add cleanup tasks here
}

trap cleanup EXIT
trap 'error_exit "Script interrupted" 130' INT TERM

#######################################
# Distribution Detection
#######################################

detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo "${ID}"
    elif [ -f /etc/arch-release ]; then
        echo "arch"
    elif [ -f /etc/debian_version ]; then
        echo "debian"
    elif [ -f /etc/redhat-release ]; then
        echo "centos"
    else
        error_exit "Unable to detect distribution"
    fi
}

detect_init_system() {
    if command -v systemctl &> /dev/null; then
        echo "systemd"
    elif command -v rc-service &> /dev/null; then
        echo "openrc"
    else
        echo "unknown"
    fi
}

#######################################
# Privilege Check
#######################################

check_privileges() {
    if [ "$(id -u)" -eq 0 ]; then
        log_warning "Running as root. Some operations may be skipped."
        export SUDO=""
    else
        log "Running as regular user. Will use sudo where needed."
        export SUDO="sudo"
    fi
}

#######################################
# Package Manager Detection
#######################################

get_package_manager() {
    local distro="$1"
    
    case "${distro}" in
        arch|manjaro|endeavouros)
            echo "pacman"
            ;;
        ubuntu|debian|linuxmint|pop)
            echo "apt"
            ;;
        fedora)
            echo "dnf"
            ;;
        centos|rhel|rocky|alma)
            if command -v dnf &> /dev/null; then
                echo "dnf"
            else
                echo "yum"
            fi
            ;;
        *)
            error_exit "Unsupported distribution: ${distro}"
            ;;
    esac
}

#######################################
# Module Loading
#######################################

load_module() {
    local module="$1"
    local module_file="${MODULES_DIR}/${module}.sh"
    
    if [ -f "${module_file}" ]; then
        log_info "Loading module: ${module}"
        # shellcheck source=/dev/null
        source "${module_file}"
    else
        log_warning "Module not found: ${module}"
        return 1
    fi
}

#######################################
# Main Installation Functions
#######################################

install_base_packages() {
    local distro="$1"
    local pkg_mgr="$2"
    
    log "Installing base packages for ${distro}..."
    
    case "${pkg_mgr}" in
        pacman)
            load_module "arch_packages"
            install_arch_base_packages
            ;;
        apt)
            load_module "debian_packages"
            install_debian_base_packages
            ;;
        dnf|yum)
            load_module "redhat_packages"
            install_redhat_base_packages
            ;;
    esac
}

setup_development_tools() {
    log "Setting up development tools..."
    
    load_module "dev_tools"
    install_mise
    install_devpod
    setup_distrobox
}

setup_dotfiles() {
    log "Setting up dotfiles with chezmoi..."
    
    load_module "dotfiles"
    
    # Setup BWS first (required for chezmoi templates)
    setup_bitwarden_integration
    
    # Bootstrap BWS token if needed
    bootstrap_bws_token
    
    setup_chezmoi
}

bootstrap_bws_token() {
    local user_home
    user_home=$(eval echo "~${SUDO_USER:-$USER}")
    local bws_token_file="${user_home}/.config/bws/token"
    
    # Skip if token already exists
    if [ -f "${bws_token_file}" ]; then
        log_info "BWS token already configured"
        return 0
    fi
    
    log "BWS (Bitwarden Secrets Manager) token required for secret management"
    
    # Check if BWS_ACCESS_TOKEN env var is set
    if [ -n "${BWS_ACCESS_TOKEN:-}" ]; then
        mkdir -p "$(dirname "${bws_token_file}")"
        echo "${BWS_ACCESS_TOKEN}" > "${bws_token_file}"
        chmod 600 "${bws_token_file}"
        log "BWS token configured from environment"
        return 0
    fi
    
    # Prompt for token
    echo ""
    log_info "To use BWS for secret management, you need a BWS access token."
    log_info "Get one from: https://vault.bitwarden.com → Secrets Manager → Access Tokens"
    echo ""
    
    read -rsp "Enter BWS access token (or press Enter to skip): " bws_token
    echo ""
    
    if [ -n "${bws_token}" ]; then
        mkdir -p "$(dirname "${bws_token_file}")"
        echo "${bws_token}" > "${bws_token_file}"
        chmod 600 "${bws_token_file}"
        log "BWS token configured"
    else
        log_warning "BWS token not provided. Some secrets may not be available."
        log_info "You can configure it later: echo 'YOUR_TOKEN' > ${bws_token_file}"
    fi
}

configure_system() {
    local distro="$1"
    
    log "Configuring system..."
    
    load_module "system_config"
    configure_firewall
    configure_security
    enable_services "${distro}"
}

#######################################
# Interactive Setup
#######################################

prompt_user() {
    local prompt="$1"
    local default="${2:-}"
    local response
    
    if [ -n "${default}" ]; then
        read -rp "${prompt} [${default}]: " response
        response="${response:-${default}}"
    else
        read -rp "${prompt}: " response
    fi
    
    echo "${response}"
}

interactive_setup() {
    log "Starting interactive setup..."
    
    echo ""
    echo "==================================="
    echo "  Multi-Distro Deployment Script  "
    echo "==================================="
    echo ""
    
    # Hostname
    HOSTNAME=$(prompt_user "Enter hostname" "$(hostname)")
    
    # User setup
    SETUP_USER=$(prompt_user "Setup dotfiles and user environment? (y/n)" "y")
    
    # Development tools
    INSTALL_DEV_TOOLS=$(prompt_user "Install development tools (mise, devpod, distrobox)? (y/n)" "y")
    
    # Container runtime
    CONTAINER_RUNTIME=$(prompt_user "Container runtime (podman/docker)" "podman")
    
    # Chezmoi repository
    if [[ "${SETUP_USER}" =~ ^[Yy]$ ]]; then
        CHEZMOI_REPO=$(prompt_user "Chezmoi repository URL (leave empty to skip)" "")
    fi
    
    echo ""
    log_info "Configuration:"
    log_info "  Hostname: ${HOSTNAME}"
    log_info "  Setup user: ${SETUP_USER}"
    log_info "  Install dev tools: ${INSTALL_DEV_TOOLS}"
    log_info "  Container runtime: ${CONTAINER_RUNTIME}"
    [ -n "${CHEZMOI_REPO:-}" ] && log_info "  Chezmoi repo: ${CHEZMOI_REPO}"
    echo ""
    
    read -rp "Continue with installation? (y/n): " confirm
    if [[ ! "${confirm}" =~ ^[Yy]$ ]]; then
        log "Installation cancelled by user"
        exit 0
    fi
}

#######################################
# Main Function
#######################################

main() {
    log "========================================="
    log "Starting Multi-Distro Deployment Script"
    log "========================================="
    
    # Check privileges
    check_privileges
    
    # Detect system
    DISTRO=$(detect_distro)
    INIT_SYSTEM=$(detect_init_system)
    PKG_MGR=$(get_package_manager "${DISTRO}")
    
    log "System Information:"
    log "  Distribution: ${DISTRO}"
    log "  Init System: ${INIT_SYSTEM}"
    log "  Package Manager: ${PKG_MGR}"
    log "  Script Directory: ${SCRIPT_DIR}"
    log "  Log File: ${LOG_FILE}"
    echo ""
    
    # Interactive setup
    interactive_setup
    
    # Installation phases
    log "Phase 1: Installing base packages"
    install_base_packages "${DISTRO}" "${PKG_MGR}"
    
    if [[ "${INSTALL_DEV_TOOLS}" =~ ^[Yy]$ ]]; then
        log "Phase 2: Installing development tools"
        setup_development_tools
    fi
    
    if [[ "${SETUP_USER}" =~ ^[Yy]$ ]]; then
        log "Phase 3: Setting up dotfiles"
        setup_dotfiles
    fi
    
    log "Phase 4: System configuration"
    configure_system "${DISTRO}"
    
    # Post-installation
    log "Phase 5: Post-installation tasks"
    load_module "post_install"
    post_install_tasks "${DISTRO}"
    
    log "========================================="
    log "Deployment completed successfully!"
    log "========================================="
    log ""
    log "Next steps:"
    log "  1. Review the log file: ${LOG_FILE}"
    log "  2. Reboot the system"
    log "  3. Configure your user-specific settings"
    log ""
}

# Run main function
main "$@"
