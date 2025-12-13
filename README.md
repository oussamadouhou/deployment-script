# Multi-Distro Deployment Script

Een deployment-ready installatiescript voor het automatisch configureren van Linux laptops en werkstations met moderne development tools.

## 🎯 Ondersteunde Distributies

- **Arch Linux** (en varianten: Manjaro, EndeavourOS)
- **Ubuntu** (en varianten: Linux Mint, Pop!_OS)
- **Fedora**
- **Debian**
- **CentOS** / RHEL / Rocky Linux / AlmaLinux

## ✨ Features

### Development Tools
- **mise** - Modern runtime version manager (alternatief voor asdf)
- **DevPod** - Development environments in containers
- **distrobox** - Container-based ontwikkelomgevingen
- **chezmoi** - Dotfile management met encryptie
- **Podman/Docker** - Container runtime naar keuze

### Security
- **YubiKey** support (smartcard, U2F, FIDO2)
- **age** encryptie voor secrets
- **Bitwarden CLI** voor password management
- **UFW/firewalld** automatische configuratie
- **SSH hardening**
- **Automatische security updates**

### Modern CLI Tools
- `eza` - Modern ls replacement
- `bat` - Cat met syntax highlighting
- `ripgrep` - Snelle grep
- `fd` - Moderne find
- `fzf` - Fuzzy finder
- `btop` - Resource monitor
- `starship` - Cross-shell prompt
- `zoxide` - Smart cd

### System Management
- **BTRFS** snapshots met snapper (Arch)
- **Reflector** voor mirror management (Arch)
- **Package manager** optimalisatie
- **Firewall** configuratie
- **Swap** management

## 📋 Vereisten

- Linux distributie (zie supported distros)
- Sudo toegang
- Internet connectie
- Minimaal 20GB vrije schijfruimte

## 🚀 Snelstart

### Basis Installatie

```bash
# Clone het repository
git clone <repository-url>
cd deployment-script

# Maak het script uitvoerbaar
chmod +x deploy.sh

# Run de installatie
./deploy.sh
```

### Arch Linux Specifiek

Voor Arch Linux kun je eerst de basis installeren met archinstall:

```bash
# Gebruik de verbeterde archinstall configuratie
archinstall --config archlinux-config-improved.json
```

Na de basis installatie:

```bash
# Boot in het nieuwe systeem
# Run het deployment script
./deploy.sh
```

## 📁 Project Structuur

```
.
├── deploy.sh                          # Hoofd script
├── archlinux-config-improved.json     # Arch installatie configuratie
├── modules/                           # Modulaire componenten
│   ├── arch_packages.sh              # Arch Linux packages
│   ├── debian_packages.sh            # Debian/Ubuntu packages
│   ├── redhat_packages.sh            # Fedora/CentOS packages
│   ├── dev_tools.sh                  # Development tools
│   ├── dotfiles.sh                   # Dotfile management
│   ├── system_config.sh              # System configuratie
│   └── post_install.sh               # Post-installatie taken
├── config/                            # Configuratie bestanden
└── logs/                              # Installatie logs

```

## 🔧 Gebruik

### Interactieve Mode

Het script start in interactieve mode en stelt vragen over:

- Hostname
- Development tools installatie
- Container runtime (podman/docker)
- Dotfile repository
- User configuratie

### Environment Variables

Je kunt het script ook configureren via environment variables:

```bash
# Hostname instellen
export HOSTNAME="mijn-laptop"

# Container runtime kiezen
export CONTAINER_RUNTIME="podman"

# Chezmoi repository
export CHEZMOI_REPO="https://github.com/username/dotfiles.git"

# Run script
./deploy.sh
```

### Alleen Specifieke Modules

```bash
# Alleen development tools
./deploy.sh --dev-tools-only

# Alleen base packages
./deploy.sh --base-only

# Alleen dotfiles setup
./deploy.sh --dotfiles-only
```

## 📦 Geïnstalleerde Tools

### Arch Linux Specifiek

**AUR Helper:**
- yay

**BTRFS Tools:**
- snapper (snapshots)
- snap-pac (pacman hooks)

**Optimalisaties:**
- Reflector (mirror updates)
- Parallel downloads
- Multilib repository

### Alle Distributies

**Shells:**
- zsh
- fish
- bash

**Editors:**
- neovim
- vim
- helix (Arch)

**Version Managers:**
- mise (Node, Python, Go, Rust, etc.)

**Container Tools:**
- podman / docker
- distrobox
- DevPod

**Security:**
- age
- bitwarden-cli
- yubikey-manager
- pass

**Development:**
- git
- github-cli (optioneel)
- lazygit
- delta (git diff)

## 🔐 Security Hardening

Het script implementeert verschillende security best practices:

### SSH Hardening
- Root login disabled
- Password authentication configureerbaar
- Login grace time beperkt
- Max auth tries = 3
- Protocol 2 only

### Firewall
- Default deny incoming
- SSH toegestaan
- Outgoing verkeer toegestaan
- UFW (Debian/Ubuntu/Arch) of firewalld (Fedora/CentOS)

### System Limits
- Verhoogde file descriptors
- Inotify watches aangepast
- Network buffers geoptimaliseerd

### Automatic Updates
- Security updates automatisch (configureerbaar)
- Unattended-upgrades (Debian/Ubuntu)
- dnf-automatic (Fedora/CentOS)

## 🎨 Dotfile Management met Chezmoi

### Initialisatie

```bash
# Met een bestaande repository
chezmoi init https://github.com/username/dotfiles.git

# Lege repository
chezmoi init

# Bestanden toevoegen
chezmoi add ~/.zshrc
chezmoi add ~/.config/nvim/init.vim
```

### Met Age Encryptie

```bash
# Age key is automatisch gegenereerd
# Locatie: ~/.config/chezmoi/key.txt

# Secrets encrypten
chezmoi add --encrypt ~/.ssh/config
chezmoi add --encrypt ~/.config/secrets.env
```

### Met Bitwarden

```bash
# Login
bw login

# In templates:
# {{ (bitwardenFields "item-id").password.value }}
```

## 🐳 Distrobox Gebruik

### Standaard Containers

Het script maakt automatisch de volgende containers aan:

- `ubuntu-dev` - Ubuntu latest
- `arch-dev` - Arch Linux latest
- `fedora-dev` - Fedora latest

### Gebruik

```bash
# Enter container
distrobox enter ubuntu-dev

# Run command in container
distrobox enter ubuntu-dev -- npm install

# Export app from container
distrobox enter ubuntu-dev
export-app code  # Visual Studio Code beschikbaar op host
```

### Custom Container

```bash
# Create custom container
distrobox create --name nodejs-env \
                 --image node:18 \
                 --home ~/Projects/nodejs

# Enter
distrobox enter nodejs-env
```

## 🔄 Mise (Runtime Management)

### Installatie van Runtimes

```bash
# Node.js LTS
mise use -g node@lts

# Python latest
mise use -g python@latest

# Go latest
mise use -g go@latest

# Rust
mise use -g rust@latest

# Bun
mise use -g bun@latest

# Deno
mise use -g deno@latest
```

### Project-specifieke Versies

```bash
# In project directory
cd my-project

# Maak .mise.toml
mise use node@18
mise use python@3.11

# Automatisch activeren bij cd
```

### Lijst van Geïnstalleerde Runtimes

```bash
mise list
mise list --current
```

## 🛠️ Post-Installatie

### Arch Linux

```bash
# Snapper configureren
sudo snapper -c root create-config /
sudo snapper -c home create-config /home

# Eerste snapshot maken
sudo snapper -c root create --description "Fresh install"

# Automatische snapshots controleren
systemctl status snapper-timeline.timer
systemctl status snapper-cleanup.timer
```

### Git Configuratie

```bash
# Basis configuratie
git config --global user.name "Jouw Naam"
git config --global user.email "jouw@email.com"

# Delta als diff tool (automatisch geconfigureerd)
git config --global core.pager delta

# GPG signing (optioneel)
git config --global user.signingkey YOUR_KEY_ID
git config --global commit.gpgsign true
```

### SSH Keys

```bash
# Genereer ED25519 key
ssh-keygen -t ed25519 -C "your_email@example.com"

# Start ssh-agent
eval "$(ssh-agent -s)"

# Voeg key toe
ssh-add ~/.ssh/id_ed25519

# Kopieer public key
cat ~/.ssh/id_ed25519.pub
```

## 📊 Logging

Alle installatie logs worden opgeslagen in:
```
logs/deployment-YYYYMMDD-HHMMSS.log
```

## 🐛 Troubleshooting

### Arch Linux

**Problem:** yay installatie faalt
```bash
# Handmatige installatie
git clone https://aur.archlinux.org/yay.git
cd yay
makepkg -si
```

**Problem:** Mirrors zijn traag
```bash
# Update mirrors met reflector
sudo reflector --country Netherlands,Germany,Belgium \
               --latest 10 --sort rate \
               --save /etc/pacman.d/mirrorlist
```

### Ubuntu/Debian

**Problem:** Package not found
```bash
# Update package lists
sudo apt update

# Enable universe/multiverse
sudo add-apt-repository universe
sudo add-apt-repository multiverse
```

### Fedora/CentOS

**Problem:** EPEL repository issues
```bash
# Reinstall EPEL
sudo dnf remove epel-release
sudo dnf install epel-release
sudo dnf update
```

### Algemeen

**Problem:** Permissie fouten
```bash
# Check of je in de juiste groepen zit
groups

# Voeg jezelf toe aan docker/podman groep
sudo usermod -aG docker $USER
# OF
sudo usermod -aG podman $USER

# Log uit en in voor group changes
```

## 🔄 Updates

### Script Updaten

```bash
cd deployment-script
git pull
./deploy.sh
```

### System Updaten

```bash
# Arch
sudo pacman -Syu
yay -Syu

# Ubuntu/Debian
sudo apt update && sudo apt upgrade

# Fedora
sudo dnf upgrade
```

## 📝 Configuratie Aanpassen

### Eigen Packages Toevoegen

Edit de relevante module in `modules/`:

```bash
# Voor Arch
vim modules/arch_packages.sh

# Voeg packages toe aan array:
local custom_packages=(
    package1
    package2
)

$SUDO pacman -S --noconfirm "${custom_packages[@]}"
```

### Services Aanpassen

Edit `modules/system_config.sh`:

```bash
vim modules/system_config.sh

# Voeg services toe in enable_services functie
```

## 🤝 Contributing

Pull requests zijn welkom! Voor grote wijzigingen, open eerst een issue.

## 📄 Licentie

MIT

## 🙏 Acknowledgments

- Arch Linux community
- Chezmoi project
- Mise project
- DevPod project
- Distrobox project

## 📚 Referenties

- [Arch Linux Wiki](https://wiki.archlinux.org/)
- [Chezmoi Documentation](https://www.chezmoi.io/)
- [Mise Documentation](https://mise.jdx.dev/)
- [DevPod Documentation](https://devpod.sh/)
- [Distrobox Documentation](https://distrobox.it/)

---

**Tip:** Voor NextJS development met audits, zie de Web Development Guide in `docs/nextjs-setup.md`
