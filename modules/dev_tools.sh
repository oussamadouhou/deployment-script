#!/usr/bin/env bash
#
# Development Tools Installation Module
# Installs: mise, devpod, distrobox, and related tools
#

install_mise() {
    if command -v mise &> /dev/null; then
        log_info "mise is already installed"
        return 0
    fi
    
    log "Installing mise (modern asdf alternative)..."
    
    # Install mise
    curl https://mise.run | sh
    
    # Add to shell configs
    setup_mise_shell_integration
    
    # Verify installation
    if command -v mise &> /dev/null; then
        log "mise installed successfully: $(mise --version)"
    else
        log_warning "mise installation may require shell restart"
    fi
}

setup_mise_shell_integration() {
    log_info "Setting up mise shell integration..."
    
    local user_home
    user_home=$(eval echo "~${SUDO_USER:-$USER}")
    
    # Bash
    if [ -f "${user_home}/.bashrc" ]; then
        if ! grep -q 'mise activate bash' "${user_home}/.bashrc"; then
            echo 'eval "$(mise activate bash)"' >> "${user_home}/.bashrc"
            log_info "Added mise to .bashrc"
        fi
    fi
    
    # Zsh
    if [ -f "${user_home}/.zshrc" ]; then
        if ! grep -q 'mise activate zsh' "${user_home}/.zshrc"; then
            echo 'eval "$(mise activate zsh)"' >> "${user_home}/.zshrc"
            log_info "Added mise to .zshrc"
        fi
    fi
    
    # Fish
    if [ -d "${user_home}/.config/fish" ]; then
        mkdir -p "${user_home}/.config/fish/conf.d"
        if [ ! -f "${user_home}/.config/fish/conf.d/mise.fish" ]; then
            echo 'mise activate fish | source' > "${user_home}/.config/fish/conf.d/mise.fish"
            log_info "Added mise to fish config"
        fi
    fi
}

install_mise_tools() {
    log "Installing development tools via mise..."
    
    # Check if mise is available
    if ! command -v mise &> /dev/null; then
        # Try to source it
        export PATH="$HOME/.local/bin:$PATH"
        if ! command -v mise &> /dev/null; then
            log_warning "mise not found, skipping tool installation"
            return 1
        fi
    fi
    
    # Install Node.js LTS
    log_info "Installing Node.js via mise..."
    mise use --global node@lts || log_warning "Failed to install Node.js"
    
    # Install Python
    log_info "Installing Python via mise..."
    mise use --global python@latest || log_warning "Failed to install Python"
    
    # Install Go
    log_info "Installing Go via mise..."
    mise use --global go@latest || log_warning "Failed to install Go"
    
    # Install Rust (via rustup is preferred, but mise can manage it too)
    log_info "Installing Rust via mise..."
    mise use --global rust@latest || log_warning "Failed to install Rust"
    
    # Install bun (modern JS runtime)
    log_info "Installing Bun via mise..."
    mise use --global bun@latest || log_warning "Failed to install Bun"
    
    # Install deno
    log_info "Installing Deno via mise..."
    mise use --global deno@latest || log_warning "Failed to install Deno"
    
    log "mise tools installed"
}

install_devpod() {
    if command -v devpod &> /dev/null; then
        log_info "DevPod is already installed"
        return 0
    fi
    
    log "Installing DevPod..."
    
    # Detect package manager and install accordingly
    case "${PKG_MGR}" in
        pacman)
            # Install from AUR or binary
            if command -v yay &> /dev/null; then
                yay -S --noconfirm devpod-bin
            else
                install_devpod_binary
            fi
            ;;
        apt)
            install_devpod_binary
            ;;
        dnf|yum)
            install_devpod_binary
            ;;
        *)
            install_devpod_binary
            ;;
    esac
    
    log "DevPod installed successfully"
}

install_devpod_binary() {
    log_info "Installing DevPod from binary release..."
    
    local version="latest"
    local arch
    arch=$(uname -m)
    
    case "${arch}" in
        x86_64)
            arch="amd64"
            ;;
        aarch64)
            arch="arm64"
            ;;
    esac
    
    local url="https://github.com/loft-sh/devpod/releases/latest/download/devpod-linux-${arch}"
    
    log_info "Downloading DevPod from ${url}"
    $SUDO curl -L -o /usr/local/bin/devpod "${url}"
    $SUDO chmod +x /usr/local/bin/devpod
    
    log "DevPod binary installed"
}

setup_distrobox() {
    log "Setting up Distrobox..."
    
    # Install distrobox if not already installed
    case "${PKG_MGR}" in
        pacman)
            $SUDO pacman -S --noconfirm distrobox
            ;;
        apt)
            $SUDO apt-get install -y distrobox
            ;;
        dnf)
            $SUDO dnf install -y distrobox
            ;;
        yum)
            # For older systems, install from curl
            curl -s https://raw.githubusercontent.com/89luca89/distrobox/main/install | sh -s -- --prefix ~/.local
            ;;
    esac
    
    # Create common distroboxes
    create_default_distroboxes
    
    log "Distrobox setup complete"
}

create_default_distroboxes() {
    log "Creating default distroboxes..."
    
    # Check if podman is running
    if ! command -v podman &> /dev/null; then
        log_warning "Podman not found, skipping distrobox creation"
        return 1
    fi
    
    local user_home
    user_home=$(eval echo "~${SUDO_USER:-$USER}")
    
    # Create Ubuntu development box
    if ! distrobox list | grep -q "ubuntu-dev"; then
        log_info "Creating Ubuntu development distrobox..."
        su - "${SUDO_USER:-$USER}" -c "distrobox create --name ubuntu-dev --image ubuntu:latest" || true
    fi
    
    # Create Arch development box
    if ! distrobox list | grep -q "arch-dev"; then
        log_info "Creating Arch development distrobox..."
        su - "${SUDO_USER:-$USER}" -c "distrobox create --name arch-dev --image archlinux:latest" || true
    fi
    
    # Create Fedora development box
    if ! distrobox list | grep -q "fedora-dev"; then
        log_info "Creating Fedora development distrobox..."
        su - "${SUDO_USER:-$USER}" -c "distrobox create --name fedora-dev --image fedora:latest" || true
    fi
    
    log "Default distroboxes created"
}

setup_container_runtime() {
    log "Setting up container runtime: ${CONTAINER_RUNTIME}"
    
    case "${CONTAINER_RUNTIME}" in
        podman)
            setup_podman
            ;;
        docker)
            setup_docker
            ;;
        *)
            log_warning "Unknown container runtime: ${CONTAINER_RUNTIME}"
            ;;
    esac
}

setup_podman() {
    log "Configuring Podman..."
    
    # Enable podman socket for docker compatibility
    systemctl --user enable --now podman.socket
    
    # Create docker alias
    local user_home
    user_home=$(eval echo "~${SUDO_USER:-$USER}")
    
    if [ -f "${user_home}/.bashrc" ]; then
        if ! grep -q 'alias docker=podman' "${user_home}/.bashrc"; then
            echo 'alias docker=podman' >> "${user_home}/.bashrc"
        fi
    fi
    
    if [ -f "${user_home}/.zshrc" ]; then
        if ! grep -q 'alias docker=podman' "${user_home}/.zshrc"; then
            echo 'alias docker=podman' >> "${user_home}/.zshrc"
        fi
    fi
    
    # Configure registries
    mkdir -p /etc/containers/
    if [ ! -f /etc/containers/registries.conf ]; then
        cat << 'EOF' | $SUDO tee /etc/containers/registries.conf > /dev/null
unqualified-search-registries = ["docker.io", "quay.io", "ghcr.io"]

[[registry]]
prefix = "docker.io"
location = "docker.io"

[[registry]]
prefix = "quay.io"
location = "quay.io"

[[registry]]
prefix = "ghcr.io"
location = "ghcr.io"
EOF
    fi
    
    log "Podman configured"
}

setup_docker() {
    log "Configuring Docker..."
    
    # Add user to docker group
    $SUDO usermod -aG docker "${SUDO_USER:-$USER}"
    
    # Enable and start docker
    $SUDO systemctl enable --now docker
    
    log "Docker configured. User needs to re-login for group changes."
}

install_additional_dev_tools() {
    log "Installing additional development tools..."
    
    # lazygit
    if ! command -v lazygit &> /dev/null; then
        log_info "Installing lazygit..."
        case "${PKG_MGR}" in
            pacman)
                $SUDO pacman -S --noconfirm lazygit
                ;;
            apt)
                # Install from GitHub releases
                LAZYGIT_VERSION=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | grep -Po '"tag_name": "v\K[^"]*')
                curl -Lo lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${LAZYGIT_VERSION}_Linux_x86_64.tar.gz"
                tar xf lazygit.tar.gz lazygit
                $SUDO install lazygit /usr/local/bin
                rm lazygit lazygit.tar.gz
                ;;
        esac
    fi
    
    # lazydocker
    if ! command -v lazydocker &> /dev/null; then
        log_info "Installing lazydocker..."
        curl https://raw.githubusercontent.com/jesseduffield/lazydocker/master/scripts/install_update_linux.sh | bash
    fi
    
    # delta (better git diff)
    if ! command -v delta &> /dev/null; then
        log_info "Installing git-delta..."
        case "${PKG_MGR}" in
            pacman)
                $SUDO pacman -S --noconfirm git-delta
                ;;
            apt)
                $SUDO apt-get install -y git-delta
                ;;
        esac
    fi
    
    log "Additional dev tools installed"
}

# Export functions
export -f install_mise
export -f setup_mise_shell_integration
export -f install_mise_tools
export -f install_devpod
export -f install_devpod_binary
export -f setup_distrobox
export -f create_default_distroboxes
export -f setup_container_runtime
export -f setup_podman
export -f setup_docker
export -f install_additional_dev_tools
