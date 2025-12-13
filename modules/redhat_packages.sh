#!/usr/bin/env bash
#
# RedHat/Fedora/CentOS Package Installation Module
#

install_redhat_base_packages() {
    log "Installing RedHat-based distribution packages..."
    
    # Detect specific package manager
    local pkg_cmd="${PKG_MGR}"
    
    # Update system
    $SUDO ${pkg_cmd} update -y
    
    # Base development tools
    local base_packages=(
        "@Development Tools"
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
        util-linux-user
    )
    
    # Modern CLI tools
    local modern_cli=(
        ripgrep
        fd-find
        fzf
        the_silver_searcher
        ncdu
    )
    
    # Editor tools
    local editor_packages=(
        vim-enhanced
        neovim
    )
    
    # Network tools
    local network_packages=(
        NetworkManager
        openssh-clients
        openssh-server
        rsync
        wget
        curl
        net-tools
        bind-utils
    )
    
    # System tools
    local system_tools=(
        htop
        iotop
        nethogs
        lm_sensors
        smartmontools
        sysstat
    )
    
    # Development tools
    local dev_tools=(
        nodejs
        npm
        python3
        python3-pip
        golang
    )
    
    # Install all packages
    log_info "Installing base packages..."
    $SUDO ${pkg_cmd} install -y "${base_packages[@]}"
    
    log_info "Installing shell packages..."
    $SUDO ${pkg_cmd} install -y "${shell_packages[@]}"
    
    log_info "Installing modern CLI tools..."
    $SUDO ${pkg_cmd} install -y "${modern_cli[@]}" || log_warning "Some CLI tools may not be available"
    
    log_info "Installing editors..."
    $SUDO ${pkg_cmd} install -y "${editor_packages[@]}"
    
    log_info "Installing network tools..."
    $SUDO ${pkg_cmd} install -y "${network_packages[@]}"
    
    log_info "Installing system tools..."
    $SUDO ${pkg_cmd} install -y "${system_tools[@]}"
    
    log_info "Installing development tools..."
    $SUDO ${pkg_cmd} install -y "${dev_tools[@]}" || log_warning "Some dev tools may need EPEL"
    
    # Install container tools
    install_redhat_container_tools
    
    # Install manually compiled tools
    install_redhat_manual_tools
    
    # Clean up
    $SUDO ${pkg_cmd} clean all
}

install_redhat_container_tools() {
    log "Installing container tools..."
    
    local pkg_cmd="${PKG_MGR}"
    
    # Podman and related tools
    local container_packages=(
        podman
        podman-compose
        buildah
        skopeo
    )
    
    $SUDO ${pkg_cmd} install -y "${container_packages[@]}"
    
    # Docker (if preferred)
    if [[ "${CONTAINER_RUNTIME}" == "docker" ]]; then
        setup_redhat_docker
    fi
}

setup_redhat_docker() {
    log "Setting up Docker on RedHat-based system..."
    
    local pkg_cmd="${PKG_MGR}"
    
    # Remove old versions
    $SUDO ${pkg_cmd} remove -y docker \
                                docker-client \
                                docker-client-latest \
                                docker-common \
                                docker-latest \
                                docker-latest-logrotate \
                                docker-logrotate \
                                docker-engine 2>/dev/null || true
    
    # Add Docker repository
    $SUDO ${pkg_cmd} install -y yum-utils
    $SUDO yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
    
    # Install Docker
    $SUDO ${pkg_cmd} install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
    
    # Start and enable Docker
    $SUDO systemctl enable --now docker
    
    # Add user to docker group
    $SUDO usermod -aG docker "${SUDO_USER:-$USER}"
    
    log "Docker installed and configured"
}

install_redhat_manual_tools() {
    log "Installing tools not in default repositories..."
    
    # bat
    if ! command -v bat &> /dev/null; then
        log_info "Installing bat..."
        local bat_version="0.24.0"
        wget -q "https://github.com/sharkdp/bat/releases/download/v${bat_version}/bat-v${bat_version}-x86_64-unknown-linux-musl.tar.gz"
        tar xzf "bat-v${bat_version}-x86_64-unknown-linux-musl.tar.gz"
        $SUDO cp "bat-v${bat_version}-x86_64-unknown-linux-musl/bat" /usr/local/bin/
        rm -rf "bat-v${bat_version}-x86_64-unknown-linux-musl"*
    fi
    
    # eza
    if ! command -v eza &> /dev/null; then
        log_info "Installing eza..."
        local eza_version="0.17.0"
        wget -q "https://github.com/eza-community/eza/releases/download/v${eza_version}/eza_x86_64-unknown-linux-gnu.tar.gz"
        tar xzf eza_x86_64-unknown-linux-gnu.tar.gz
        $SUDO cp eza /usr/local/bin/
        rm eza_x86_64-unknown-linux-gnu.tar.gz eza
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

setup_redhat_epel() {
    log "Setting up EPEL repository..."
    
    local pkg_cmd="${PKG_MGR}"
    
    # Install EPEL for additional packages
    if ! rpm -q epel-release &>/dev/null; then
        $SUDO ${pkg_cmd} install -y epel-release
        $SUDO ${pkg_cmd} update -y
    fi
    
    log "EPEL repository enabled"
}

setup_redhat_rpmfusion() {
    log "Setting up RPM Fusion repositories..."
    
    local pkg_cmd="${PKG_MGR}"
    
    # Only for Fedora
    if [ "${DISTRO}" = "fedora" ]; then
        $SUDO ${pkg_cmd} install -y \
            https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
            https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm
        
        $SUDO ${pkg_cmd} update -y
        log "RPM Fusion repositories enabled"
    else
        log_info "Skipping RPM Fusion (not Fedora)"
    fi
}

install_redhat_yubikey_support() {
    log "Installing YubiKey support..."
    
    local pkg_cmd="${PKG_MGR}"
    
    local yubikey_packages=(
        yubikey-manager
        yubikey-personalization
        yubikey-personalization-gui
        pcsc-lite
        pcsc-lite-ccid
        pcsc-tools
    )
    
    $SUDO ${pkg_cmd} install -y "${yubikey_packages[@]}"
    
    # Enable pcscd
    $SUDO systemctl enable --now pcscd
    
    log "YubiKey support installed"
}

setup_redhat_firewalld() {
    log "Configuring firewalld..."
    
    # Ensure firewalld is installed
    $SUDO ${PKG_MGR} install -y firewalld
    
    # Enable and start firewalld
    $SUDO systemctl enable --now firewalld
    
    # Allow SSH
    $SUDO firewall-cmd --permanent --add-service=ssh
    
    # Reload firewall
    $SUDO firewall-cmd --reload
    
    log "Firewalld configured"
}

setup_redhat_selinux() {
    log "Checking SELinux configuration..."
    
    local selinux_status
    selinux_status=$(getenforce)
    
    log_info "SELinux status: ${selinux_status}"
    
    # Optionally provide guidance on SELinux
    if [ "${selinux_status}" = "Enforcing" ]; then
        log_info "SELinux is enforcing. This is the recommended setting."
    elif [ "${selinux_status}" = "Permissive" ]; then
        log_warning "SELinux is in permissive mode. Consider enforcing for production."
    else
        log_warning "SELinux is disabled. Consider enabling for better security."
    fi
}

optimize_redhat_dnf() {
    log "Optimizing DNF configuration..."
    
    if [ "${PKG_MGR}" = "dnf" ]; then
        # Configure DNF for better performance
        if [ ! -f /etc/dnf/dnf.conf.d/99-custom.conf ]; then
            cat << 'EOF' | $SUDO tee /etc/dnf/dnf.conf.d/99-custom.conf > /dev/null
[main]
max_parallel_downloads=10
fastestmirror=True
deltarpm=True
EOF
        fi
        
        log "DNF optimized"
    fi
}

# Export functions
export -f install_redhat_base_packages
export -f install_redhat_container_tools
export -f setup_redhat_docker
export -f install_redhat_manual_tools
export -f setup_redhat_epel
export -f setup_redhat_rpmfusion
export -f install_redhat_yubikey_support
export -f setup_redhat_firewalld
export -f setup_redhat_selinux
export -f optimize_redhat_dnf
