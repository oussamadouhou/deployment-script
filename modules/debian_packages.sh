#!/usr/bin/env bash
#
# Debian/Ubuntu Package Installation Module
#

install_debian_base_packages() {
    log "Installing Debian/Ubuntu base packages..."
    
    # Update package lists
    $SUDO apt-get update
    
    # Upgrade system
    $SUDO apt-get upgrade -y
    
    # Base development tools
    local base_packages=(
        build-essential
        git
        curl
        wget
        rsync
        unzip
        p7zip-full
        man-db
        manpages
        software-properties-common
        apt-transport-https
        ca-certificates
        gnupg
        lsb-release
    )
    
    # Shell and terminal tools
    local shell_packages=(
        zsh
        fish
        tmux
    )
    
    # Modern CLI tools (need manual installation for some)
    local modern_cli=(
        ripgrep
        fd-find
        fzf
        ncdu
    )
    
    # Editor tools
    local editor_packages=(
        vim
        neovim
    )
    
    # Network tools
    local network_packages=(
        network-manager
        openssh-client
        openssh-server
        rsync
        wget
        curl
        net-tools
        dnsutils
    )
    
    # Container tools
    local container_packages=(
        podman
        docker.io
        docker-compose
    )
    
    # Security tools
    local security_packages=(
        ufw
        fail2ban
        gnupg2
        pass
    )
    
    # System tools
    local system_tools=(
        htop
        iotop
        nethogs
        lm-sensors
        smartmontools
    )
    
    # Development tools
    local dev_tools=(
        nodejs
        npm
        python3
        python3-pip
        python3-venv
        golang
    )
    
    # Install all packages
    log_info "Installing base packages..."
    $SUDO apt-get install -y "${base_packages[@]}"
    
    log_info "Installing shell packages..."
    $SUDO apt-get install -y "${shell_packages[@]}"
    
    log_info "Installing modern CLI tools..."
    $SUDO apt-get install -y "${modern_cli[@]}" || log_warning "Some CLI tools may not be available"
    
    log_info "Installing editors..."
    $SUDO apt-get install -y "${editor_packages[@]}"
    
    log_info "Installing network tools..."
    $SUDO apt-get install -y "${network_packages[@]}"
    
    log_info "Installing container tools..."
    $SUDO apt-get install -y "${container_packages[@]}" || log_warning "Some container tools may not be available"
    
    log_info "Installing security tools..."
    $SUDO apt-get install -y "${security_packages[@]}"
    
    log_info "Installing system tools..."
    $SUDO apt-get install -y "${system_tools[@]}"
    
    log_info "Installing development tools..."
    $SUDO apt-get install -y "${dev_tools[@]}"
    
    # Install manually compiled tools
    install_debian_manual_tools
    
    # Clean up
    $SUDO apt-get autoremove -y
    $SUDO apt-get clean
}

install_debian_manual_tools() {
    log "Installing tools not in default repositories..."
    
    # bat
    if ! command -v bat &> /dev/null && ! command -v batcat &> /dev/null; then
        log_info "Installing bat..."
        local bat_version="0.24.0"
        wget -q "https://github.com/sharkdp/bat/releases/download/v${bat_version}/bat_${bat_version}_amd64.deb"
        $SUDO dpkg -i "bat_${bat_version}_amd64.deb" || $SUDO apt-get install -f -y
        rm "bat_${bat_version}_amd64.deb"
    fi
    
    # eza (modern ls replacement)
    if ! command -v eza &> /dev/null; then
        log_info "Installing eza..."
        $SUDO mkdir -p /etc/apt/keyrings
        wget -qO- https://raw.githubusercontent.com/eza-community/eza/main/deb.asc | $SUDO gpg --dearmor -o /etc/apt/keyrings/gierens.gpg
        echo "deb [signed-by=/etc/apt/keyrings/gierens.gpg] http://deb.gierens.de stable main" | $SUDO tee /etc/apt/sources.list.d/gierens.list
        $SUDO chmod 644 /etc/apt/keyrings/gierens.gpg /etc/apt/sources.list.d/gierens.list
        $SUDO apt-get update
        $SUDO apt-get install -y eza
    fi
    
    # starship
    if ! command -v starship &> /dev/null; then
        log_info "Installing starship..."
        curl -sS https://starship.rs/install.sh | sh -s -- -y
    fi
    
    # zoxide
    if ! command -v zoxide &> /dev/null; then
        log_info "Installing zoxide..."
        curl -sS https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | bash
    fi
    
    # btop
    if ! command -v btop &> /dev/null; then
        log_info "Installing btop..."
        local btop_version="1.3.0"
        wget -q "https://github.com/aristocratos/btop/releases/download/v${btop_version}/btop-x86_64-linux-musl.tbz"
        tar xjf btop-x86_64-linux-musl.tbz
        cd btop || return
        $SUDO make install
        cd ..
        rm -rf btop btop-x86_64-linux-musl.tbz
    fi
}

setup_debian_repositories() {
    log "Setting up additional repositories..."
    
    # Get Ubuntu/Debian version
    local distro_version
    distro_version=$(lsb_release -cs)
    
    # Add Docker repository
    if ! grep -q "docker" /etc/apt/sources.list.d/*.list 2>/dev/null; then
        log_info "Adding Docker repository..."
        $SUDO mkdir -p /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | $SUDO gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu ${distro_version} stable" | \
            $SUDO tee /etc/apt/sources.list.d/docker.list > /dev/null
    fi
    
    # Add Node.js repository (NodeSource)
    if ! command -v node &> /dev/null; then
        log_info "Adding Node.js repository..."
        curl -fsSL https://deb.nodesource.com/setup_lts.x | $SUDO -E bash -
    fi
    
    # Update package lists
    $SUDO apt-get update
}

install_debian_yubikey_support() {
    log "Installing YubiKey support..."
    
    local yubikey_packages=(
        yubikey-manager
        yubikey-personalization
        yubikey-personalization-gui
        pcscd
        pcsc-tools
        libpam-u2f
        libpam-yubico
    )
    
    $SUDO apt-get install -y "${yubikey_packages[@]}"
    
    # Enable pcscd
    $SUDO systemctl enable --now pcscd
    
    log "YubiKey support installed"
}

install_debian_bitwarden() {
    log "Installing Bitwarden CLI..."
    
    if command -v snap &> /dev/null; then
        $SUDO snap install bw
    else
        # Install via npm
        $SUDO npm install -g @bitwarden/cli
    fi
}

setup_debian_chezmoi() {
    log "Installing chezmoi..."
    
    if ! command -v chezmoi &> /dev/null; then
        sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "$HOME/.local/bin"
        
        # Add to PATH if not already there
        local user_home
        user_home=$(eval echo "~${SUDO_USER:-$USER}")
        
        if [ -f "${user_home}/.bashrc" ]; then
            if ! grep -q '.local/bin' "${user_home}/.bashrc"; then
                echo 'export PATH="$HOME/.local/bin:$PATH"' >> "${user_home}/.bashrc"
            fi
        fi
    fi
}

optimize_debian_apt() {
    log "Optimizing APT configuration..."
    
    # Enable parallel downloads
    if [ ! -f /etc/apt/apt.conf.d/99parallel ]; then
        echo 'APT::Acquire::Queue-Mode "host";' | $SUDO tee /etc/apt/apt.conf.d/99parallel > /dev/null
        echo 'APT::Acquire::Retries "3";' | $SUDO tee -a /etc/apt/apt.conf.d/99parallel > /dev/null
    fi
    
    # Disable recommended packages by default
    if [ ! -f /etc/apt/apt.conf.d/99norecommends ]; then
        echo 'APT::Install-Recommends "false";' | $SUDO tee /etc/apt/apt.conf.d/99norecommends > /dev/null
        echo 'APT::Install-Suggests "false";' | $SUDO tee -a /etc/apt/apt.conf.d/99norecommends > /dev/null
    fi
    
    log "APT optimized"
}

# Export functions
export -f install_debian_base_packages
export -f install_debian_manual_tools
export -f setup_debian_repositories
export -f install_debian_yubikey_support
export -f install_debian_bitwarden
export -f setup_debian_chezmoi
export -f optimize_debian_apt
