#!/usr/bin/env bash
#
# System Configuration Module
#

configure_firewall() {
    log "Configuring firewall..."
    
    case "${DISTRO}" in
        arch|ubuntu|debian)
            configure_ufw
            ;;
        fedora|centos|rhel)
            configure_firewalld
            ;;
    esac
}

configure_ufw() {
    log "Configuring UFW (Uncomplicated Firewall)..."
    
    # Ensure UFW is installed
    case "${PKG_MGR}" in
        pacman)
            $SUDO pacman -S --needed --noconfirm ufw
            ;;
        apt)
            $SUDO apt-get install -y ufw
            ;;
    esac
    
    # Default policies
    $SUDO ufw default deny incoming
    $SUDO ufw default allow outgoing
    
    # Allow SSH
    $SUDO ufw allow ssh
    
    # Enable UFW
    echo "y" | $SUDO ufw enable
    
    # Enable UFW service
    $SUDO systemctl enable --now ufw
    
    log "UFW configured and enabled"
}

configure_firewalld() {
    log "Configuring firewalld..."
    
    # Ensure firewalld is installed
    $SUDO ${PKG_MGR} install -y firewalld
    
    # Enable and start
    $SUDO systemctl enable --now firewalld
    
    # Allow SSH
    $SUDO firewall-cmd --permanent --add-service=ssh
    
    # Reload
    $SUDO firewall-cmd --reload
    
    log "Firewalld configured"
}

configure_security() {
    log "Configuring system security..."
    
    # Configure SSH
    configure_ssh
    
    # Configure sudo timeout
    configure_sudo
    
    # Set up automatic security updates
    setup_automatic_updates
    
    # Configure system limits
    configure_system_limits
}

configure_ssh() {
    log "Hardening SSH configuration..."
    
    local sshd_config="/etc/ssh/sshd_config"
    
    if [ -f "${sshd_config}" ]; then
        # Backup original config
        $SUDO cp "${sshd_config}" "${sshd_config}.backup"
        
        # Disable root login
        $SUDO sed -i 's/^#*PermitRootLogin.*/PermitRootLogin no/' "${sshd_config}"
        
        # Disable password authentication (prefer key-based)
        # Uncomment this if you want to enforce key-based auth
        # $SUDO sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' "${sshd_config}"
        
        # Disable empty passwords
        $SUDO sed -i 's/^#*PermitEmptyPasswords.*/PermitEmptyPasswords no/' "${sshd_config}"
        
        # Set login grace time
        $SUDO sed -i 's/^#*LoginGraceTime.*/LoginGraceTime 60/' "${sshd_config}"
        
        # Maximum auth tries
        $SUDO sed -i 's/^#*MaxAuthTries.*/MaxAuthTries 3/' "${sshd_config}"
        
        # Use only SSH protocol 2
        if ! grep -q "^Protocol 2" "${sshd_config}"; then
            echo "Protocol 2" | $SUDO tee -a "${sshd_config}" > /dev/null
        fi
        
        # Restart SSH service
        $SUDO systemctl restart sshd || $SUDO systemctl restart ssh
        
        log "SSH hardened"
    else
        log_warning "SSH config file not found"
    fi
}

configure_sudo() {
    log "Configuring sudo timeout..."
    
    # Create custom sudoers file for timeout
    if [ ! -f /etc/sudoers.d/timeout ]; then
        echo "Defaults timestamp_timeout=15" | $SUDO tee /etc/sudoers.d/timeout > /dev/null
        $SUDO chmod 0440 /etc/sudoers.d/timeout
        log "Sudo timeout set to 15 minutes"
    fi
}

setup_automatic_updates() {
    log "Setting up automatic security updates..."
    
    case "${PKG_MGR}" in
        pacman)
            # Arch doesn't have automatic updates by default
            # Can be done with systemd timers or pacmatic
            log_info "Automatic updates not configured (manual intervention recommended for Arch)"
            ;;
        apt)
            setup_debian_automatic_updates
            ;;
        dnf|yum)
            setup_redhat_automatic_updates
            ;;
    esac
}

setup_debian_automatic_updates() {
    log "Configuring unattended-upgrades..."
    
    $SUDO apt-get install -y unattended-upgrades apt-listchanges
    
    # Configure unattended-upgrades
    cat << 'EOF' | $SUDO tee /etc/apt/apt.conf.d/50unattended-upgrades > /dev/null
Unattended-Upgrade::Allowed-Origins {
    "${distro_id}:${distro_codename}-security";
    "${distro_id}ESMApps:${distro_codename}-apps-security";
    "${distro_id}ESM:${distro_codename}-infra-security";
};
Unattended-Upgrade::AutoFixInterruptedDpkg "true";
Unattended-Upgrade::MinimalSteps "true";
Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "false";
EOF
    
    # Enable automatic updates
    cat << 'EOF' | $SUDO tee /etc/apt/apt.conf.d/20auto-upgrades > /dev/null
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::AutocleanInterval "7";
EOF
    
    log "Unattended upgrades configured"
}

setup_redhat_automatic_updates() {
    log "Configuring dnf-automatic..."
    
    $SUDO ${PKG_MGR} install -y dnf-automatic
    
    # Configure for security updates only
    $SUDO sed -i 's/^upgrade_type.*/upgrade_type = security/' /etc/dnf/automatic.conf
    $SUDO sed -i 's/^apply_updates.*/apply_updates = yes/' /etc/dnf/automatic.conf
    
    # Enable timer
    $SUDO systemctl enable --now dnf-automatic.timer
    
    log "DNF automatic updates configured"
}

configure_system_limits() {
    log "Configuring system limits..."
    
    # Increase file descriptor limits
    if [ ! -f /etc/security/limits.d/99-custom.conf ]; then
        cat << 'EOF' | $SUDO tee /etc/security/limits.d/99-custom.conf > /dev/null
* soft nofile 65536
* hard nofile 65536
* soft nproc 32768
* hard nproc 32768
EOF
        log "System limits configured"
    fi
    
    # Configure sysctl parameters
    if [ ! -f /etc/sysctl.d/99-custom.conf ]; then
        cat << 'EOF' | $SUDO tee /etc/sysctl.d/99-custom.conf > /dev/null
# Increase inotify watches
fs.inotify.max_user_watches = 524288
fs.inotify.max_user_instances = 512

# Increase file descriptors
fs.file-max = 2097152

# Network optimization
net.core.rmem_max = 134217728
net.core.wmem_max = 134217728
net.ipv4.tcp_rmem = 4096 87380 67108864
net.ipv4.tcp_wmem = 4096 65536 67108864
EOF
        
        # Apply sysctl settings
        $SUDO sysctl -p /etc/sysctl.d/99-custom.conf
        
        log "Sysctl parameters configured"
    fi
}

enable_services() {
    local distro="$1"
    
    log "Enabling and starting services..."
    
    # Common services
    local services=(
        "sshd"
        "NetworkManager"
    )
    
    # Distro-specific services
    case "${distro}" in
        arch)
            services+=("pcscd" "reflector.timer")
            ;;
        fedora|centos|rhel)
            services+=("pcscd" "firewalld")
            ;;
        ubuntu|debian)
            services+=("ssh" "ufw")
            ;;
    esac
    
    for service in "${services[@]}"; do
        if systemctl list-unit-files | grep -q "^${service}"; then
            log_info "Enabling ${service}..."
            $SUDO systemctl enable "${service}" 2>/dev/null || true
            $SUDO systemctl start "${service}" 2>/dev/null || log_warning "Could not start ${service}"
        fi
    done
    
    log "Services configured"
}

configure_hostname() {
    if [ -n "${HOSTNAME:-}" ]; then
        log "Setting hostname to ${HOSTNAME}..."
        $SUDO hostnamectl set-hostname "${HOSTNAME}"
        log "Hostname set"
    fi
}

configure_timezone() {
    log "Configuring timezone..."
    
    # Default to Europe/Amsterdam if not set
    local timezone="${TIMEZONE:-Europe/Amsterdam}"
    
    $SUDO timedatectl set-timezone "${timezone}"
    $SUDO timedatectl set-ntp true
    
    log "Timezone set to ${timezone}"
}

setup_swap() {
    log "Checking swap configuration..."
    
    if ! swapon --show | grep -q swap; then
        log_info "No swap detected"
        
        # Ask if user wants to create swap
        read -rp "Create swapfile? (y/n): " create_swap
        if [[ "${create_swap}" =~ ^[Yy]$ ]]; then
            create_swapfile
        fi
    else
        log_info "Swap already configured"
    fi
}

create_swapfile() {
    log "Creating swapfile..."
    
    # Calculate swap size (1.5x RAM, max 32GB)
    local mem_total
    mem_total=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    local swap_size=$(( mem_total * 3 / 2 / 1024 )) # in MB
    
    # Cap at 32GB
    if [ ${swap_size} -gt 32768 ]; then
        swap_size=32768
    fi
    
    log_info "Creating ${swap_size}MB swapfile..."
    
    # Create swapfile
    $SUDO fallocate -l "${swap_size}M" /swapfile || \
        $SUDO dd if=/dev/zero of=/swapfile bs=1M count="${swap_size}"
    
    $SUDO chmod 600 /swapfile
    $SUDO mkswap /swapfile
    $SUDO swapon /swapfile
    
    # Add to fstab
    if ! grep -q '/swapfile' /etc/fstab; then
        echo '/swapfile none swap defaults 0 0' | $SUDO tee -a /etc/fstab
    fi
    
    log "Swapfile created and enabled"
}

# Export functions
export -f configure_firewall
export -f configure_ufw
export -f configure_firewalld
export -f configure_security
export -f configure_ssh
export -f configure_sudo
export -f setup_automatic_updates
export -f setup_debian_automatic_updates
export -f setup_redhat_automatic_updates
export -f configure_system_limits
export -f enable_services
export -f configure_hostname
export -f configure_timezone
export -f setup_swap
export -f create_swapfile
