#!/usr/bin/env bash
# =============================================================================
# bootstrap.sh — Amo Jonathan (Shudiak)
# =============================================================================
# One-shot installer para dejar un Rocky Linux 8.10 fresh IDÉNTICO a netwise-sed.
# Replica el estado del server de referencia (100.82.36.22) tras install manual.
#
# Paquetes instalados:
#   - Sistema:  zsh, git, curl, wget, vim, tmux, htop, gcc, make, nc, nmap
#   - Oh-My-Zsh + plugins: zsh-autosuggestions, zsh-syntax-highlighting, fast-syntax-highlighting
#   - Neovim 0.12.3 + LazyVim (full IDE con 30+ plugins)
#   - Docker 26 + docker compose plugin
#   - Tailscale 1.98+ (cliente VPN para tailnet)
#   - xclip + xorg-x11-xauth (clipboard + X11 forwarding)
#
# Configuraciones aplicadas:
#   - SELinux: respeta Enforcing, configura contextos para Docker volumes
#   - DNS: workaround para Tailscale (8.8.8.8 + 1.1.1.1 + 100.100.100.100)
#   - TZ: America/Bogota
#   - zsh como shell default
#   - Dotfiles via symlinks (LazyVim config + .zshrc agnoster + aliases)
#
# Uso (primer inicio del SO, conectado a internet, como root):
#
#   sh -c "$(curl -fsSL https://raw.githubusercontent.com/Shudiak/dotfiles/master/bootstrap.sh)"
#
# Flags opcionales:
#   --no-docker         No instala Docker
#   --no-zsh            No instala zsh (deja bash)
#   --no-nvim           No instala Neovim
#   --no-tailscale      No instala Tailscale
#   --no-dns-fix        No aplica el workaround DNS
#   --ssh-keygen        Genera SSH key ED25519 y la muestra al final
#   --tailscale-key KEY Tailscale auth key pre-auth (evita login interactivo)
#   --neovim-version VER  v0.12.3 | stable | nightly (default v0.12.3)
#   -h | --help         Ayuda
#
# Re-ejecutable: detecta software ya instalado y lo salta.
# =============================================================================

set -euo pipefail

# --- Constantes ---
GITHUB_USER="Shudiak"
GITHUB_REPO="dotfiles"
GITHUB_BRANCH="master"
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
INSTALL_TAILSCALE=true
APPLY_DNS_FIX=true
GENERATE_SSH=false
NVIM_VERSION="v0.12.3"
TAILSCALE_AUTH_KEY=""

# --- Parse args ---
while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-docker)        INSTALL_DOCKER=false; shift ;;
    --no-zsh)           INSTALL_ZSH=false; shift ;;
    --no-nvim)          INSTALL_NVIM=false; shift ;;
    --no-tailscale)     INSTALL_TAILSCALE=false; shift ;;
    --no-dns-fix)       APPLY_DNS_FIX=false; shift ;;
    --ssh-keygen)       GENERATE_SSH=true; shift ;;
    --tailscale-key)    TAILSCALE_AUTH_KEY="$2"; shift 2 ;;
    --neovim-version)   NVIM_VERSION="$2"; shift 2 ;;
    -h|--help)
      sed -n "2,35p" "$0"
      exit 0 ;;
    *) error "Argumento desconocido: $1. Usa --help" ;;
  esac
done

# --- Pre-flight ---
header "Pre-flight checks"

if [[ $EUID -ne 0 ]]; then
  error "Este script debe ejecutarse como root (sudo -i)"
fi

if [[ -f /etc/os-release ]]; then
  . /etc/os-release
  info "OS detectado: ${PRETTY_NAME:-Linux desconocido}"
  if [[ "${ID:-}" != "rocky" && "${ID:-}" != "rhel" && "${ID:-}" != "almalinux" && "${ID:-}" != "centos" ]]; then
    warn "OS no es Rocky/RHEL/Alma/CentOS. Algunas cosas pueden fallar."
  fi
fi

if ! curl -fsS --max-time 5 https://github.com >/dev/null 2>&1; then
  error "Sin internet a GitHub. Verifica DNS (cat /etc/resolv.conf) y proxy."
fi
success "Internet OK"

FREE_KB=$(df --output=avail / | tail -1)
FREE_GB=$((FREE_KB / 1024 / 1024))
if [[ $FREE_GB -lt 3 ]]; then
  warn "Disco bajo: ${FREE_GB} GB libres (recomendado 3+ GB)"
fi
success "Disco libre: ${FREE_GB} GB"

# --- Habilitar EPEL (necesario para xclip, xauth, htop, tmux, nmap) ---
header "Habilitando EPEL"

if rpm -q epel-release &>/dev/null; then
  info "EPEL ya instalado"
else
  dnf install -y epel-release
  success "EPEL habilitado"
fi

# --- Instalar paquetes base del sistema ---
header "Instalando paquetes base del sistema"

PACKAGES_SYSTEM=(
  git curl wget tar gzip ca-certificates
  zsh vim tmux htop nc nmap
  gcc make
  xclip xorg-x11-xauth
  bind-utils
  rsync
  which
)

# Detectar package manager
if command -v dnf &>/dev/null; then
  PM="dnf"
elif command -v yum &>/dev/null; then
  PM="yum"
else
  error "Ni dnf ni yum disponibles. OS no soportado."
fi

info "Instalando: ${PACKAGES_SYSTEM[*]}"
$PM install -y "${PACKAGES_SYSTEM[@]}"
success "Paquetes base instalados"

# --- Tailscale ---
if [[ $INSTALL_TAILSCALE == true ]]; then
  header "Instalando Tailscale"
  
  if command -v tailscale &>/dev/null; then
    info "Tailscale ya instalado: $(tailscale --version | head -1)"
  else
    info "Descargando script oficial de Tailscale..."
    curl -fsSL https://tailscale.com/install.sh | sh
    success "Tailscale instalado"
  fi
  
  systemctl enable tailscaled
  systemctl start tailscaled
  sleep 2
  
  if tailscale status &>/dev/null; then
    info "Tailscale ya autenticado"
  else
    info "Autenticando Tailscale..."
    if [[ -n "$TAILSCALE_AUTH_KEY" ]]; then
      tailscale up --authkey="$TAILSCALE_AUTH_KEY"
      success "Tailscale autenticado con auth key"
    else
      warn "Tailscale requiere autenticación interactiva."
      echo ""
      echo -e "  ${BOLD}Para completar manualmente:${NC}"
      echo -e "  ${CYAN}tailscale up${NC}"
      echo ""
      if [[ -t 0 ]]; then
        (tailscale up --timeout=60s &)
        sleep 5
        if tailscale status &>/dev/null; then
          success "Tailscale autenticado"
        else
          warn "Completa la autenticación manualmente con: tailscale up"
        fi
      else
        warn "No hay TTY. Ejecuta: tailscale up"
      fi
    fi
  fi
fi

# --- Docker (opcional) ---
if [[ $INSTALL_DOCKER == true ]]; then
  header "Instalando Docker + compose plugin"
  
  if command -v docker &>/dev/null; then
    info "Docker ya instalado: $(docker --version)"
  else
    dnf install -y dnf-utils
    dnf config-manager --add-repo https://download.docker.com/linux/rhel/docker-ce.repo
    dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    systemctl enable --now docker
    success "Docker instalado y habilitado"
  fi
fi

# --- DNS fix (para clones git via Tailscale) ---
if [[ $APPLY_DNS_FIX == true ]]; then
  header "Aplicando DNS fix (Tailscale workaround)"
  
  if [[ -f /etc/resolv.conf ]]; then
    cp /etc/resolv.conf /etc/resolv.conf.bak 2>/dev/null || true
    
    SEARCH_DOMAIN=""
    if command -v tailscale &>/dev/null && tailscale status &>/dev/null; then
      TAIL_DOMAIN=$(tailscale status --json 2>/dev/null | grep -oP '"MagicDNSSuffix":"[^"]+"' | cut -d\" -f4)
      [[ -n "$TAIL_DOMAIN" ]] && SEARCH_DOMAIN="$TAIL_DOMAIN"
    fi
    
    cat > /etc/resolv.conf <<DNSEOF
# Managed by Jarvis bootstrap — DNS fix para Tailscale
nameserver 8.8.8.8
nameserver 1.1.1.1
nameserver 100.100.100.100
DNSEOF
    [[ -n "$SEARCH_DOMAIN" ]] && echo "search $SEARCH_DOMAIN" >> /etc/resolv.conf
    success "DNS configurado: 8.8.8.8 + 1.1.1.1 + 100.100.100.100"
    
    if command -v tailscale &>/dev/null; then
      tailscale set --accept-dns=false 2>&1 | head -1 || warn "No se pudo desactivar Tailscale DNS (no es crítico)"
      info "Tailscale DNS management desactivado"
    fi
  fi
fi

# --- Zsh + Oh-My-Zsh ---
if [[ $INSTALL_ZSH == true ]]; then
  header "Instalando Zsh + Oh-My-Zsh + plugins"
  
  if ! command -v zsh &>/dev/null; then
    $PM install -y zsh
  fi
  success "zsh: $(zsh --version)"
  
  if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
    info "Instalando Oh-My-Zsh..."
    RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
  fi
  success "Oh-My-Zsh en $HOME/.oh-my-zsh"
  
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
  
  CURRENT_SHELL=$(getent passwd "$USER" | cut -d: -f7)
  if [[ "$CURRENT_SHELL" != "$(command -v zsh)" ]]; then
    chsh -s "$(command -v zsh)" "$USER" 2>/dev/null || \
      warn "No se pudo cambiar shell default (ejecuta: chsh -s \$(which zsh))"
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

info "Creando symlinks para config files..."
mkdir -p "$HOME/.config"
[[ -f "$DOTFILES_DIR/.zshrc" ]] && ln -sf "$DOTFILES_DIR/.zshrc" "$HOME/.zshrc"
[[ -d "$DOTFILES_DIR/.config/nvim" ]] && ln -sfn "$DOTFILES_DIR/.config/nvim" "$HOME/.config/nvim"
success "Dotfiles aplicados (symlinks en ~/)"

# --- SELinux: contexto para volúmenes Docker ---
if command -v getenforce &>/dev/null && [[ "$(getenforce)" == "Enforcing" ]]; then
  header "Configurando SELinux contexts para Docker"
  
  if [[ -d /home/docker ]]; then
    info "Aplicando contexto container_file_t a /home/docker/"
    chcon -R -t container_file_t /home/docker/ 2>/dev/null || \
      warn "No se pudo aplicar SELinux (puede no ser necesario)"
    success "SELinux configurado"
  fi
fi

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

Software instalado:
  - zsh $(zsh --version 2>&1 | awk '{print $2}')
  - git $(git --version 2>&1 | awk '{print $3}')
  - nvim $(nvim --version 2>&1 | head -1 | awk '{print $2}')
  - docker $(docker --version 2>&1 | awk '{print $3}' | tr -d ',')
  - tailscale $(tailscale --version 2>&1 | head -1 | awk '{print $1}')

Dotfiles:
  ~/.zshrc         -> ${DOTFILES_DIR}/.zshrc
  ~/.config/nvim   -> ${DOTFILES_DIR}/.config/nvim

Próximos pasos:
  1. ${CYAN}Reinicia sesión${NC} (o exec zsh)
  2. ${CYAN}nvim${NC} — LazyVim instala plugins automáticamente
  3. Si Tailscale no se autenticó: ${CYAN}tailscale up${NC}
  4. Verifica: ${CYAN}docker ps${NC}, ${CYAN}tailscale status${NC}

Repo: https://github.com/${GITHUB_USER}/${GITHUB_REPO}
SUMMARY

success "Hecho. Bienvenido al sistema, ${USER}."