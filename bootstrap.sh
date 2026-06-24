#!/usr/bin/env bash
# =============================================================================
# bootstrap.sh — Amo Jonathan (Shudiak)
# =============================================================================
# One-shot installer para Rocky Linux 8.9 / RHEL 8 / AlmaLinux 8 fresh.
# Deja el sistema listo para producción con:
#   - zsh + Oh-My-Zsh + plugins
#   - Neovim 0.12+ + LazyVim (full IDE)
#   - git, docker, docker-compose
#   - Dotfiles del repo (lazyvim config, .zshrc, aliases)
#   - SSH key generation + GitHub auth
#
# Uso (primer inicio del SO, conectado a internet):
#
#   sh -c "$(curl -fsSL https://raw.githubusercontent.com/Shudiak/dotfiles/main/bootstrap.sh)"
#
# Opciones:
#   --no-docker      No instala Docker
#   --no-zsh         No instala zsh (deja bash)
#   --no-nvim        No instala Neovim
#   --neovim-version VERSION   v0.12.1 | stable | nightly (default: v0.12.3)
#   --ssh-keygen     Genera nueva SSH key ED25519 y la muestra al final
#   --help           Mostrar ayuda
#
# Re-ejecutable: detecta qué ya está instalado y lo salta.
# =============================================================================

set -euo pipefail

# --- Constantes ---
GITHUB_USER="Shudiak"
GITHUB_REPO="dotfiles"
GITHUB_BRANCH="main"
RAW_URL="https://raw.githubusercontent.com/${GITHUB_USER}/${GITHUB_REPO}/${GITHUB_BRANCH}"

# --- Colores ---
if [[ -t 1 ]]; then
  RED="\033[0;31m"; GREEN="\033[0;32m"; YELLOW="\033[1;33m"
  CYAN="\033[0;36m"; BOLD="\033[1m"; NC="\033[0m"
else
  RED=""; GREEN=""; YELLOW=""; CYAN=""; BOLD=""; NC=""
fi

info()    { echo -e "${CYAN}[INFO]${NC} $*"; }
success() { echo -e "${GREEN}[OK]${NC}   $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $*"; }
error()   { echo -e "${RED}[ERR]${NC}  $*" >&2; exit 1; }
header()  { echo -e "\n${BOLD}${CYAN}==> $*${NC}\n"; }

# --- Defaults ---
INSTALL_DOCKER=true
INSTALL_ZSH=true
INSTALL_NVIM=true
GENERATE_SSH=false
NVIM_VERSION="v0.12.3"

# --- Parse args ---
while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-docker)      INSTALL_DOCKER=false; shift ;;
    --no-zsh)         INSTALL_ZSH=false; shift ;;
    --no-nvim)        INSTALL_NVIM=false; shift ;;
    --ssh-keygen)     GENERATE_SSH=true; shift ;;
    --neovim-version) NVIM_VERSION="$2"; shift 2 ;;
    -h|--help)
      sed -n "2,30p" "$0"
      exit 0 ;;
    *) error "Argumento desconocido: $1. Usa --help" ;;
  esac
done

# --- Pre-flight ---
header "Pre-flight checks"

if [[ $EUID -ne 0 ]]; then
  error "Este script debe ejecutarse como root (sudo)"
fi

# Detectar distro
if [[ -f /etc/os-release ]]; then
  . /etc/os-release
  info "OS detectado: ${PRETTY_NAME:-Linux desconocido}"
else
  warn "No se pudo detectar /etc/os-release. Continuando bajo riesgo."
fi

# Internet
if ! curl -fsS --max-time 5 https://github.com >/dev/null 2>&1; then
  error "Sin internet a GitHub. Verifica DNS (cat /etc/resolv.conf) y proxy."
fi
success "Internet OK"

# Disco libre (mínimo 2GB)
FREE_KB=$(df --output=avail / | tail -1)
FREE_GB=$((FREE_KB / 1024 / 1024))
if [[ $FREE_GB -lt 2 ]]; then
  warn "Disco bajo: ${FREE_GB} GB libres (recomendado 2+ GB)"
fi
success "Disco libre: ${FREE_GB} GB"

# --- Instalar paquetes base ---
header "Instalando paquetes base (git, curl, wget, tar, gzip)"

PACKAGES_BASE="git curl wget tar gzip ca-certificates"
if command -v dnf &>/dev/null; then
  dnf install -y $PACKAGES_BASE
elif command -v yum &>/dev/null; then
  yum install -y $PACKAGES_BASE
else
  error "Ni dnf ni yum disponibles. OS no soportado."
fi
success "Paquetes base instalados"

# --- Docker (opcional) ---
if [[ $INSTALL_DOCKER == true ]]; then
  header "Instalando Docker + docker-compose"
  if command -v docker &>/dev/null; then
    info "Docker ya instalado: $(docker --version)"
  else
    dnf install -y dnf-utils
    dnf config-manager --add-repo https://download.docker.com/linux/rhel/docker-ce.repo
    dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    systemctl enable --now docker
    success "Docker instalado y habilitado"
  fi
else
  info "Saltando instalación de Docker (--no-docker)"
fi

# --- Zsh + Oh-My-Zsh ---
if [[ $INSTALL_ZSH == true ]]; then
  header "Instalando Zsh + Oh-My-Zsh + plugins"
  
  # zsh
  if ! command -v zsh &>/dev/null; then
    dnf install -y zsh
  fi
  success "zsh: $(zsh --version)"
  
  # Oh-My-Zsh
  if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
    info "Instalando Oh-My-Zsh..."
    # Descarga no interactiva
    RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
  fi
  success "Oh-My-Zsh en $HOME/.oh-my-zsh"
  
  # Plugins custom (no vienen en OMZ default)
  ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
  PLUGINS=(
    "zsh-autosuggestions|https://github.com/zsh-users/zsh-autosuggestions"
    "zsh-syntax-highlighting|https://github.com/zsh-users/zsh-syntax-highlighting"
    "fast-syntax-highlighting|https://github.com/zdharma-continuum/fast-syntax-highlighting"
  )
  for entry in "${PLUGINS[@]}"; do
    name="${entry%%|*}"
    url="${entry##*|}"
    if [[ ! -d "$ZSH_CUSTOM/plugins/$name" ]]; then
      git clone --depth 1 "$url" "$ZSH_CUSTOM/plugins/$name"
    fi
  done
  success "Plugins zsh instalados"
  
  # Cambiar shell default a zsh
  CURRENT_SHELL=$(getent passwd "$USER" | cut -d: -f7)
  if [[ "$CURRENT_SHELL" != "$(command -v zsh)" ]]; then
    chsh -s "$(command -v zsh)" "$USER"
    info "Shell default cambiado a zsh (efectivo tras próximo login)"
  fi
fi

# --- Neovim + LazyVim ---
if [[ $INSTALL_NVIM == true ]]; then
  header "Instalando Neovim ${NVIM_VERSION}"
  
  if command -v nvim &>/dev/null; then
    INSTALLED_VER=$(nvim --version | head -1 | grep -oP "v\d+\.\d+\.\d+")
    info "Neovim ya instalado: ${INSTALLED_VER}"
  else
    bash <(curl -fsSL "${RAW_URL}/install-nvim.sh") --version "${NVIM_VERSION}"
    success "Neovim ${NVIM_VERSION} instalado"
  fi
fi

# --- Aplicar dotfiles del repo ---
header "Aplicando dotfiles desde ${GITHUB_USER}/${GITHUB_REPO}"

DOTFILES_DIR="$HOME/.dotfiles"
if [[ -d "$DOTFILES_DIR" ]]; then
  warn "$DOTFILES_DIR ya existe, haciendo backup"
  mv "$DOTFILES_DIR" "${DOTFILES_DIR}.bak.$(date +%Y%m%d_%H%M%S)"
fi

git clone --depth 1 --branch "${GITHUB_BRANCH}" \
  "https://github.com/${GITHUB_USER}/${GITHUB_REPO}.git" "$DOTFILES_DIR"

# Symlinks (stow-style)
info "Creando symlinks para config files..."
mkdir -p "$HOME/.config"
[[ -f "$DOTFILES_DIR/.zshrc" ]] && ln -sf "$DOTFILES_DIR/.zshrc" "$HOME/.zshrc"
[[ -d "$DOTFILES_DIR/.config/nvim" ]] && ln -sfn "$DOTFILES_DIR/.config/nvim" "$HOME/.config/nvim"

success "Dotfiles aplicados (symlinks en ~/)"

# --- SSH Key (opcional) ---
if [[ $GENERATE_SSH == true ]]; then
  header "Generando SSH key ED25519"
  
  if [[ -f "$HOME/.ssh/id_ed25519" ]]; then
    warn "Ya existe ~/.ssh/id_ed25519, saltando"
  else
    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"
    ssh-keygen -t ed25519 -C "${USER}@$(hostname)" -f "$HOME/.ssh/id_ed25519" -N ""
    chmod 600 "$HOME/.ssh/id_ed25519"
    chmod 644 "$HOME/.ssh/id_ed25519.pub"
    success "SSH key generada"
    
    echo ""
    echo -e "${BOLD}=== AGREGA ESTA CLAVE PÚBLICA A GITHUB ===${NC}"
    echo -e "${YELLOW}https://github.com/settings/keys${NC}"
    echo ""
    cat "$HOME/.ssh/id_ed25519.pub"
    echo ""
    echo -e "${BOLD}===========================================${NC}"
  fi
fi

# --- Resumen final ---
header "Bootstrap completo"

cat <<SUMMARY
${GREEN}============================================${NC}
${GREEN}  Sistema configurado correctamente${NC}
${GREEN}============================================${NC}

Próximos pasos:
  1. ${CYAN}Reinicia la sesión${NC} (o ejecuta: ${CYAN}exec zsh${NC})
  2. ${CYAN}Abre nvim${NC} — LazyVim instalará plugins automáticamente
  3. ${CYAN}Verifica Docker${NC}: docker ps
  4. ${CYAN}Tu dotfiles repo${NC}: ${DOTFILES_DIR}

Dotfiles en:
  ~/.zshrc         -> ${DOTFILES_DIR}/.zshrc
  ~/.config/nvim   -> ${DOTFILES_DIR}/.config/nvim

Repositorio: https://github.com/${GITHUB_USER}/${GITHUB_REPO}
SUMMARY

success "Hecho. Bienvenido al sistema, ${USER}."
