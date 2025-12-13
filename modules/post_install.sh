#!/usr/bin/env bash
#
# Post-Installation Tasks Module
#

post_install_tasks() {
    local distro="$1"
    
    log "Running post-installation tasks..."
    
    # Configure hostname and timezone
    configure_hostname
    configure_timezone
    
    # Check and setup swap if needed
    setup_swap
    
    # Configure shell for user
    configure_user_shell
    
    # Setup git configuration
    setup_git_global_config
    
    # Create useful aliases
    create_shell_aliases
    
    # Print system information
    print_system_info
    
    # Print next steps
    print_next_steps "${distro}"
}

configure_user_shell() {
    log "Configuring user shell..."
    
    local user_home
    user_home=$(eval echo "~${SUDO_USER:-$USER}")
    local current_shell
    current_shell=$(getent passwd "${SUDO_USER:-$USER}" | cut -d: -f7)
    
    log_info "Current shell: ${current_shell}"
    
    # Ask user if they want to change shell
    read -rp "Change default shell to zsh? (y/n): " change_shell
    if [[ "${change_shell}" =~ ^[Yy]$ ]]; then
        if command -v zsh &> /dev/null; then
            chsh -s "$(which zsh)" "${SUDO_USER:-$USER}"
            log "Default shell changed to zsh"
        else
            log_warning "zsh not found"
        fi
    fi
}

setup_git_global_config() {
    log "Setting up global git configuration..."
    
    local user_home
    user_home=$(eval echo "~${SUDO_USER:-$USER}")
    
    # Check if git is configured
    if [ ! -f "${user_home}/.gitconfig" ]; then
        log_info "Git not configured yet"
        
        read -rp "Configure git now? (y/n): " configure_git
        if [[ "${configure_git}" =~ ^[Yy]$ ]]; then
            read -rp "Enter your name: " git_name
            read -rp "Enter your email: " git_email
            
            if [ "$(id -u)" -eq 0 ]; then
                su - "${SUDO_USER}" -c "git config --global user.name '${git_name}'"
                su - "${SUDO_USER}" -c "git config --global user.email '${git_email}'"
                su - "${SUDO_USER}" -c "git config --global init.defaultBranch main"
                su - "${SUDO_USER}" -c "git config --global pull.rebase true"
            else
                git config --global user.name "${git_name}"
                git config --global user.email "${git_email}"
                git config --global init.defaultBranch main
                git config --global pull.rebase true
            fi
            
            log "Git configured"
        fi
    else
        log_info "Git already configured"
    fi
}

create_shell_aliases() {
    log "Creating useful shell aliases..."
    
    local user_home
    user_home=$(eval echo "~${SUDO_USER:-$USER}")
    local alias_file="${user_home}/.bash_aliases"
    
    if [ ! -f "${alias_file}" ]; then
        cat << 'EOF' > "${alias_file}"
# System aliases
alias update-system='sudo pacman -Syu || sudo apt update && sudo apt upgrade -y || sudo dnf upgrade -y'
alias cleanup='sudo pacman -Sc || sudo apt autoremove -y && sudo apt clean || sudo dnf autoremove -y'

# Modern CLI replacements
alias ls='eza --icons'
alias ll='eza -la --icons'
alias lt='eza --tree --icons'
alias cat='bat'
alias find='fd'
alias grep='rg'
alias top='btop'

# Git aliases
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git pull'
alias glog='git log --oneline --graph --all'
alias lg='lazygit'

# Docker/Podman aliases
alias dc='docker-compose'
alias dps='docker ps'
alias dim='docker images'

# Chezmoi aliases
alias cm='chezmoi'
alias cma='chezmoi apply'
alias cmd='chezmoi diff'
alias cme='chezmoi edit'

# System information
alias sysinfo='fastfetch'

# Distrobox aliases
alias dba='distrobox-assemble'
alias dbc='distrobox create'
alias dbe='distrobox enter'
alias dbl='distrobox list'

# Navigation
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'

# Safety
alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'
EOF
        
        chown "${SUDO_USER:-$USER}:${SUDO_USER:-$USER}" "${alias_file}"
        
        # Source in .bashrc if not already there
        if [ -f "${user_home}/.bashrc" ]; then
            if ! grep -q '.bash_aliases' "${user_home}/.bashrc"; then
                echo '' >> "${user_home}/.bashrc"
                echo '# Load custom aliases' >> "${user_home}/.bashrc"
                echo 'if [ -f ~/.bash_aliases ]; then' >> "${user_home}/.bashrc"
                echo '    . ~/.bash_aliases' >> "${user_home}/.bashrc"
                echo 'fi' >> "${user_home}/.bashrc"
            fi
        fi
        
        log "Shell aliases created"
    fi
}

print_system_info() {
    log "System Information:"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Distribution: ${DISTRO}"
    echo "  Kernel: $(uname -r)"
    echo "  Hostname: $(hostname)"
    echo "  Architecture: $(uname -m)"
    echo "  Uptime: $(uptime -p)"
    if command -v fastfetch &> /dev/null; then
        fastfetch --pipe false
    fi
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
}

print_next_steps() {
    local distro="$1"
    
    echo ""
    log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log "Next Steps:"
    log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    echo "1. Reboot your system:"
    echo "   sudo reboot"
    echo ""
    
    echo "2. Setup your dotfiles with chezmoi:"
    echo "   chezmoi init <your-repo-url>"
    echo "   chezmoi apply"
    echo ""
    
    echo "3. Install runtime versions with mise:"
    echo "   mise use -g node@lts"
    echo "   mise use -g python@latest"
    echo "   mise use -g go@latest"
    echo ""
    
    echo "4. Create development containers with distrobox:"
    echo "   distrobox create --name dev-ubuntu --image ubuntu:latest"
    echo "   distrobox enter dev-ubuntu"
    echo ""
    
    echo "5. Setup SSH keys for GitHub/GitLab:"
    echo "   ssh-keygen -t ed25519 -C 'your_email@example.com'"
    echo "   cat ~/.ssh/id_ed25519.pub"
    echo ""
    
    if [ "${distro}" = "arch" ]; then
        echo "6. Configure snapper for BTRFS snapshots:"
        echo "   sudo snapper -c root create-config /"
        echo "   sudo snapper -c home create-config /home"
        echo ""
    fi
    
    echo "7. Review security settings:"
    echo "   - SSH configuration: /etc/ssh/sshd_config"
    echo "   - Firewall status: sudo ufw status (or firewall-cmd --list-all)"
    echo "   - SELinux status: sestatus (RHEL/Fedora/CentOS only)"
    echo ""
    
    echo "8. Install additional AUR packages (Arch) or PPAs (Ubuntu):"
    echo "   yay -S <package>  # Arch"
    echo "   sudo add-apt-repository ppa:...  # Ubuntu"
    echo ""
    
    log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log "Installation log saved to: ${LOG_FILE}"
    log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
}

create_post_install_checklist() {
    local checklist_file="${SCRIPT_DIR}/POST_INSTALL_CHECKLIST.md"
    
    cat << 'EOF' > "${checklist_file}"
# Post-Installation Checklist

## Security
- [ ] Review SSH configuration
- [ ] Setup SSH keys for remote access
- [ ] Configure firewall rules
- [ ] Setup fail2ban (optional)
- [ ] Configure YubiKey for authentication (if applicable)
- [ ] Setup 2FA for critical services

## Development Environment
- [ ] Initialize chezmoi with dotfiles repository
- [ ] Configure git (name, email, GPG signing)
- [ ] Install language runtimes via mise
- [ ] Setup development containers with distrobox
- [ ] Configure IDE/Editor preferences
- [ ] Setup container registry authentication

## System Configuration
- [ ] Configure automatic backups
- [ ] Setup BTRFS snapshots (Arch)
- [ ] Configure monitoring (optional)
- [ ] Setup log rotation
- [ ] Configure system limits for development

## User Configuration
- [ ] Change default shell to zsh/fish
- [ ] Configure starship prompt
- [ ] Setup terminal emulator preferences
- [ ] Configure keyboard shortcuts
- [ ] Setup clipboard managers

## Network & Services
- [ ] Configure VPN (if needed)
- [ ] Setup DNS over HTTPS (optional)
- [ ] Configure network shares
- [ ] Setup SSH tunnels/proxies (if needed)

## Backup & Recovery
- [ ] Test BTRFS snapshots and restore
- [ ] Backup SSH keys
- [ ] Backup GPG keys
- [ ] Document recovery procedures
- [ ] Export package list for easy reinstall

## Optional Enhancements
- [ ] Setup Nvidia drivers (if applicable)
- [ ] Configure power management
- [ ] Setup printer drivers
- [ ] Configure bluetooth
- [ ] Setup media codecs
- [ ] Install additional GUI applications

## Documentation
- [ ] Document custom configurations
- [ ] Create system maintenance schedule
- [ ] Document installed services and ports
- [ ] Create disaster recovery plan
EOF
    
    log "Post-installation checklist created: ${checklist_file}"
}

# Export functions
export -f post_install_tasks
export -f configure_user_shell
export -f setup_git_global_config
export -f create_shell_aliases
export -f print_system_info
export -f print_next_steps
export -f create_post_install_checklist
