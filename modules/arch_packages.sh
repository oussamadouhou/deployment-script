#!/usr/bin/env bash
#
# Arch Linux Package Installation Module
#

install_arch_base_packages() {
    log "Installing Arch Linux base packages..."
    
    # Update system first
    $SUDO pacman -Syu --noconfirm
    
    # Base development tools
    local base_packages=(
        base-devel
        git
        curl
        wget
        rsync
        unzip
        p7zip
        man-db
        man-pages
    )
    
    # Shell and terminal tools
    local shell_packages=(
        zsh
        fish
        tmux
        starship
        htop
        btop
        fastfetch
    )
    
    # Modern CLI tools
    local modern_cli=(
        ripgrep
        fd
        bat
        eza
        fzf
        zoxide
        dust
        duf
        procs
    )
    
    # Editor tools
    local editor_packages=(
        vim
        neovim
        helix
    )
    
    # Network tools
    local network_packages=(
        networkmanager
        iwd
        openssh
        rsync
        wget
        curl
    )
    
    # Container and virtualization
    local container_packages=(
        podman
        podman-compose
        distrobox
        docker
        docker-compose
    )
    
    # Security tools
    local security_packages=(
        ufw
        fail2ban
        age
        gnupg
        pass
        bitwarden-cli
    )
    
    # Hardware security (YubiKey, etc.)
    local hw_security=(
        yubikey-manager
        yubikey-personalization
        opensc
        pcsc-lite
        ccid
        pcsclite
        fprintd
    )
    
    # Dotfile management
    local dotfile_tools=(
        chezmoi
        stow
    )
    
    # Development tools
    local dev_tools=(
        nodejs
        npm
        python
        python-pip
        python-pipx
        go
        rust
        rustup
    )
    
    # Monitoring and system tools
    local system_tools=(
        lm_sensors
        smartmontools
        iotop
        nethogs
        ncdu
    )
    
    # Install all packages
    log_info "Installing base packages..."
    $SUDO pacman -S --noconfirm "${base_packages[@]}"
    
    log_info "Installing shell packages..."
    $SUDO pacman -S --noconfirm "${shell_packages[@]}"
    
    log_info "Installing modern CLI tools..."
    $SUDO pacman -S --noconfirm "${modern_cli[@]}"
    
    log_info "Installing editors..."
    $SUDO pacman -S --noconfirm "${editor_packages[@]}"
    
    log_info "Installing network tools..."
    $SUDO pacman -S --noconfirm "${network_packages[@]}"
    
    log_info "Installing container tools..."
    $SUDO pacman -S --noconfirm "${container_packages[@]}"
    
    log_info "Installing security tools..."
    $SUDO pacman -S --noconfirm "${security_packages[@]}"
    
    log_info "Installing hardware security tools..."
    $SUDO pacman -S --noconfirm "${hw_security[@]}"
    
    log_info "Installing dotfile management tools..."
    $SUDO pacman -S --noconfirm "${dotfile_tools[@]}"
    
    log_info "Installing development tools..."
    $SUDO pacman -S --noconfirm "${dev_tools[@]}"
    
    log_info "Installing system monitoring tools..."
    $SUDO pacman -S --noconfirm "${system_tools[@]}"
    
    # Install yay (AUR helper)
    install_yay
    
    # Install AUR packages
    install_arch_aur_packages
}

install_yay() {
    if command -v yay &> /dev/null; then
        log_info "yay is already installed"
        return 0
    fi
    
    log "Installing yay AUR helper..."
    
    local temp_dir
    temp_dir=$(mktemp -d)
    cd "${temp_dir}" || error_exit "Failed to create temp directory"
    
    git clone https://aur.archlinux.org/yay.git
    cd yay || error_exit "Failed to clone yay repository"
    
    makepkg -si --noconfirm
    
    cd - > /dev/null || true
    rm -rf "${temp_dir}"
    
    log "yay installed successfully"
}

install_arch_aur_packages() {
    log "Installing AUR packages..."
    
    local aur_packages=(
        visual-studio-code-bin
        google-chrome
        slack-desktop
        1password
        1password-cli
        devpod-bin
        brave-bin
        postman-bin
        bws-bin
    )
    
    for package in "${aur_packages[@]}"; do
        log_info "Installing ${package}..."
        yay -S --noconfirm "${package}" || log_warning "Failed to install ${package}"
    done
}

setup_arch_btrfs() {
    log "Setting up BTRFS snapshots with snapper..."
    
    # Install snapper if not already installed
    $SUDO pacman -S --noconfirm snapper snap-pac
    
    # Create snapper configs
    if [ ! -d "/.snapshots" ]; then
        $SUDO snapper -c root create-config /
    fi
    
    if [ -d "/home" ]; then
        $SUDO snapper -c home create-config /home
    fi
    
    # Configure snapper timeline
    $SUDO systemctl enable --now snapper-timeline.timer
    $SUDO systemctl enable --now snapper-cleanup.timer
    
    log "Snapper configured successfully"
}

setup_arch_reflector() {
    log "Configuring reflector for automatic mirror updates..."
    
    $SUDO pacman -S --noconfirm reflector
    
    # Create reflector configuration
    cat << 'EOF' | $SUDO tee /etc/xdg/reflector/reflector.conf > /dev/null
--save /etc/pacman.d/mirrorlist
--protocol https
--country Netherlands,Germany,Belgium
--latest 10
--sort rate
EOF
    
    # Enable reflector timer
    $SUDO systemctl enable --now reflector.timer
    
    log "Reflector configured"
}

optimize_arch_pacman() {
    log "Optimizing pacman configuration..."
    
    # Backup original pacman.conf
    $SUDO cp /etc/pacman.conf /etc/pacman.conf.backup
    
    # Enable parallel downloads
    $SUDO sed -i 's/^#ParallelDownloads.*/ParallelDownloads = 10/' /etc/pacman.conf
    
    # Enable color
    $SUDO sed -i 's/^#Color/Color/' /etc/pacman.conf
    
    # Enable ILoveCandy (Pac-Man progress bar)
    $SUDO sed -i '/Color/a ILoveCandy' /etc/pacman.conf
    
    # Enable multilib repository
    $SUDO sed -i '/\[multilib\]/,/Include/ s/^#//' /etc/pacman.conf
    
    # Update package database
    $SUDO pacman -Sy
    
    log "Pacman optimized"
}

# Export functions
export -f install_arch_base_packages
export -f install_yay
export -f install_arch_aur_packages
export -f setup_arch_btrfs
export -f setup_arch_reflector
export -f optimize_arch_pacman
