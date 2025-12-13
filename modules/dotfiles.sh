#!/usr/bin/env bash
#
# Dotfiles Management Module
# Uses chezmoi for dotfile management
#

setup_chezmoi() {
    log "Setting up chezmoi for dotfile management..."
    
    local user_home
    user_home=$(eval echo "~${SUDO_USER:-$USER}")
    
    # Ensure chezmoi is installed
    if ! command -v chezmoi &> /dev/null; then
        install_chezmoi
    fi
    
    # Initialize chezmoi
    if [ -n "${CHEZMOI_REPO:-}" ]; then
        initialize_chezmoi_with_repo "${CHEZMOI_REPO}"
    else
        initialize_chezmoi_empty
    fi
    
    log "Chezmoi setup complete"
}

install_chezmoi() {
    log "Installing chezmoi..."
    
    case "${PKG_MGR}" in
        pacman)
            $SUDO pacman -S --noconfirm chezmoi
            ;;
        apt)
            $SUDO apt-get install -y chezmoi
            ;;
        dnf|yum)
            $SUDO dnf install -y chezmoi
            ;;
        *)
            # Install via script
            sh -c "$(curl -fsLS get.chezmoi.io)"
            ;;
    esac
}

initialize_chezmoi_with_repo() {
    local repo="$1"
    local user_home
    user_home=$(eval echo "~${SUDO_USER:-$USER}")
    
    log "Initializing chezmoi with repository: ${repo}"
    
    # Run as the actual user, not root
    if [ "$(id -u)" -eq 0 ]; then
        su - "${SUDO_USER}" -c "chezmoi init ${repo}"
    else
        chezmoi init "${repo}"
    fi
    
    # Optionally apply immediately
    read -rp "Apply dotfiles now? (y/n): " apply_now
    if [[ "${apply_now}" =~ ^[Yy]$ ]]; then
        if [ "$(id -u)" -eq 0 ]; then
            su - "${SUDO_USER}" -c "chezmoi apply"
        else
            chezmoi apply
        fi
    fi
}

initialize_chezmoi_empty() {
    local user_home
    user_home=$(eval echo "~${SUDO_USER:-$USER}")
    
    log "Initializing empty chezmoi repository"
    
    if [ "$(id -u)" -eq 0 ]; then
        su - "${SUDO_USER}" -c "chezmoi init"
    else
        chezmoi init
    fi
    
    log_info "Chezmoi initialized. Add files with: chezmoi add <file>"
}

setup_age_encryption() {
    log "Setting up age encryption for secrets..."
    
    local user_home
    user_home=$(eval echo "~${SUDO_USER:-$USER}")
    local age_key_file="${user_home}/.config/chezmoi/key.txt"
    
    # Ensure age is installed
    if ! command -v age &> /dev/null; then
        case "${PKG_MGR}" in
            pacman)
                $SUDO pacman -S --noconfirm age
                ;;
            apt)
                $SUDO apt-get install -y age
                ;;
            dnf|yum)
                $SUDO dnf install -y age
                ;;
        esac
    fi
    
    # Generate age key if it doesn't exist
    if [ ! -f "${age_key_file}" ]; then
        log_info "Generating age encryption key..."
        mkdir -p "$(dirname "${age_key_file}")"
        age-keygen -o "${age_key_file}"
        chmod 600 "${age_key_file}"
        
        log_info "Age public key:"
        grep "# public key:" "${age_key_file}"
        
        log_warning "IMPORTANT: Backup your age key from ${age_key_file}"
    fi
    
    # Configure chezmoi to use age
    local chezmoi_config="${user_home}/.config/chezmoi/chezmoi.toml"
    if [ ! -f "${chezmoi_config}" ]; then
        mkdir -p "$(dirname "${chezmoi_config}")"
        cat << EOF > "${chezmoi_config}"
encryption = "age"
[age]
    identity = "${age_key_file}"
    recipient = "$(grep "# public key:" "${age_key_file}" | awk '{print $4}')"
EOF
        log "Chezmoi configured to use age encryption"
    fi
}

setup_bitwarden_integration() {
    log "Setting up Bitwarden integration for secret management..."
    
    # Ensure bitwarden-cli is installed
    if ! command -v bw &> /dev/null; then
        case "${PKG_MGR}" in
            pacman)
                $SUDO pacman -S --noconfirm bitwarden-cli
                ;;
            apt)
                # Install via snap or download
                if command -v snap &> /dev/null; then
                    $SUDO snap install bw
                else
                    log_warning "Bitwarden CLI not available in apt, install manually"
                fi
                ;;
            dnf|yum)
                log_warning "Bitwarden CLI not in default repos, install manually"
                ;;
        esac
    fi
    
    # Configure chezmoi template functions for bitwarden
    local user_home
    user_home=$(eval echo "~${SUDO_USER:-$USER}")
    local chezmoi_config="${user_home}/.config/chezmoi/chezmoi.toml"
    
    log_info "Bitwarden CLI installed. Use in templates with:"
    log_info '  {{ (bitwardenFields "item-id").password.value }}'
}

create_example_dotfiles() {
    log "Creating example dotfile structure..."
    
    local user_home
    user_home=$(eval echo "~${SUDO_USER:-$USER}")
    
    # Example .zshrc template
    if [ "$(id -u)" -eq 0 ]; then
        su - "${SUDO_USER}" -c "chezmoi add ~/.zshrc" 2>/dev/null || true
    else
        chezmoi add ~/.zshrc 2>/dev/null || true
    fi
    
    log_info "Example dotfiles added. Edit with: chezmoi edit <file>"
    log_info "Apply changes with: chezmoi apply"
    log_info "See diff with: chezmoi diff"
}

setup_git_config_template() {
    log "Setting up git config template..."
    
    local user_home
    user_home=$(eval echo "~${SUDO_USER:-$USER}")
    local template_dir
    
    if [ "$(id -u)" -eq 0 ]; then
        template_dir="$(su - "${SUDO_USER}" -c "chezmoi source-path")"
    else
        template_dir="$(chezmoi source-path)"
    fi
    
    # Create templated gitconfig
    mkdir -p "${template_dir}"
    cat << 'EOF' > "${template_dir}/dot_gitconfig.tmpl"
[user]
    name = {{ .name }}
    email = {{ .email }}

[core]
    editor = {{ .editor | default "nvim" }}
    pager = delta

[interactive]
    diffFilter = delta --color-only

[delta]
    navigate = true
    light = false
    line-numbers = true
    side-by-side = true

[merge]
    conflictstyle = diff3

[diff]
    colorMoved = default

[init]
    defaultBranch = main

[pull]
    rebase = true

[push]
    autoSetupRemote = true

[alias]
    st = status
    co = checkout
    br = branch
    ci = commit
    unstage = reset HEAD --
    last = log -1 HEAD
    visual = log --graph --oneline --all
    lg = log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit
EOF
    
    log "Git config template created"
}

# Export functions
export -f setup_chezmoi
export -f install_chezmoi
export -f initialize_chezmoi_with_repo
export -f initialize_chezmoi_empty
export -f setup_age_encryption
export -f setup_bitwarden_integration
export -f create_example_dotfiles
export -f setup_git_config_template
