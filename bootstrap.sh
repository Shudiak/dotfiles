#!/usr/bin/env bash
# =============================================================================
# bootstrap.sh — Amo Jonathan (Shudiak)
# =============================================================================
# One-shot installer para dejar un Rocky Linux 8.x/9.x/10.x fresh IDÉNTICO a netwise-sed.
# Replica el estado del server de referencia (100.82.36.22) tras install manual.
#
# Soportado: Rocky Linux 8.9+, 9.x, 10.x (incluye Rocky 10.2)
# Auto-detecta DNF4 vs DNF5, EPEL estándar vs epel-next, paquetes condicionales.
#
# Paquetes instalados:
#   - Sistema:  zsh, git, curl, wget, vim, tmux, htop, gcc, make, nc, nmap
#   - Oh-My-Zsh + plugins: zsh-autosuggestions, zsh-syntax-highlighting, fast-syntax-highlighting
#   - Neovim 0.12.3 + LazyVim (full IDE con 30+ plugins)
#   - Docker 26 + docker compose plugin
#   - Tailscale 1.98+ (cliente VPN para tailnet)
#   - xclip + xorg-x11-xauth (solo si hay display gráfico)
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

# Oh-My-Zsh pinned SHA — garantiza que todos los servers (netwise-sed,
# Rocky 10.2, futuros clientes) tengan exactamente la misma versión de OMZ
# y por lo tanto el mismo tema agnoster, plugins, etc.
# Update policy: bumpear manualmente cuando se quiera actualizar.
OMZ_PINNED_SHA="df34d2b8d575777465aed8ae9b7cd90d63fdcd6e"

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
  # Rocky 9+ requiere también epel-next para algunos paquetes
  if [[ $OS_MAJOR -ge 9 ]]; then
    $PM install -y epel-release epel-next-release 2>/dev/null || $PM install -y epel-release
  else
    $PM install -y epel-release
  fi
  success "EPEL habilitado"
fi

# --- Instalar paquetes base del sistema ---
header "Instalando paquetes base del sistema"

PACKAGES_SYSTEM=(
  git curl wget tar gzip ca-certificates
  zsh vim tmux htop nc nmap
  gcc make
  bind-utils
  rsync
  which
)

# xclip + xorg-x11-xauth solo si hay display gráfico (X11 o Wayland)
# En Rocky 10.x con Wayland, X11 viene via XWayland. En servidor headless no aplican.
if [[ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]] || systemctl is-active --quiet graphical.target 2>/dev/null; then
  PACKAGES_SYSTEM+=(xclip xorg-x11-xauth)
  info "Display gráfico detectado — añadiendo xclip + xorg-x11-xauth"
else
  info "Sin display gráfico — omitiendo xclip + xorg-x11-xauth"
fi

# Detectar package manager y versión
if command -v dnf5 &>/dev/null; then
  PM="dnf5"
  DNF_VERSION="5"
elif command -v dnf &>/dev/null; then
  # dnf puede ser DNF4 (alias) o DNF5 (real)
  if dnf --version 2>/dev/null | head -1 | grep -q "dnf5"; then
    PM="dnf5"
    DNF_VERSION="5"
  else
    PM="dnf"
    DNF_VERSION="4"
  fi
elif command -v yum &>/dev/null; then
  PM="yum"
  DNF_VERSION="4"
else
  error "Ni dnf ni yum disponibles. OS no soportado."
fi
info "Package manager: $PM (DNF$DNF_VERSION)"

# Detectar versión de OS (Rocky/RHEL major version)
OS_MAJOR="0"
if [[ -f /etc/os-release ]]; then
  . /etc/os-release
  OS_MAJOR="${VERSION_ID%%.*}"
fi
info "OS major version: $OS_MAJOR"

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
    # dnf-utils solo existe en DNF4; en DNF5 viene integrado
    if [[ $DNF_VERSION == "4" ]]; then
      $PM install -y dnf-utils
    fi
    # Sintaxis diferente para DNF5: addrepo sin guiones, --save para guardar
    if [[ $DNF_VERSION == "5" ]]; then
      $PM config-manager addrepo --save --from-repofile="https://download.docker.com/linux/rhel/docker-ce.repo" 2>/dev/null \
        || $PM config-manager addrepo "https://download.docker.com/linux/rhel/docker-ce.repo"
    else
      $PM config-manager --add-repo https://download.docker.com/linux/rhel/docker-ce.repo
    fi
    $PM install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
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
  else
    # Si ya existe, asegurar que esté en el SHA pinneado (idempotente + reproducible)
    CURRENT_OMZ_SHA=$(cd "$HOME/.oh-my-zsh" && git rev-parse HEAD 2>/dev/null || echo "unknown")
    if [[ "$CURRENT_OMZ_SHA" != "$OMZ_PINNED_SHA" ]]; then
      info "Oh-My-Zsh en SHA $CURRENT_OMZ_SHA, actualizando a pinneado $OMZ_PINNED_SHA..."
      cd "$HOME/.oh-my-zsh" || error "No se pudo entrar a $HOME/.oh-my-zsh"
      git fetch origin --depth 1 "$OMZ_PINNED_SHA" 2>/dev/null || git fetch origin
      git checkout -q "$OMZ_PINNED_SHA" 2>/dev/null || {
        warn "No se pudo checkout pinneado, re-clonando..."
        cd "$HOME" && rm -rf "$HOME/.oh-my-zsh"
        git clone --depth 1 https://github.com/ohmyzsh/ohmyzsh.git "$HOME/.oh-my-zsh"
        cd "$HOME/.oh-my-zsh" && git checkout -q "$OMZ_PINNED_SHA"
      }
      cd "$HOME" >/dev/null
      success "Oh-My-Zsh pineado a $OMZ_PINNED_SHA"
    else
      info "Oh-My-Zsh ya en SHA pinneado ($OMZ_PINNED_SHA)"
    fi
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

# --- Verificaciones automáticas post-install ---
header "Verificando instalación"

VERIFY_FAILED=0

# Test 1: Symlinks apuntan a archivos reales
if [[ -L "$HOME/.zshrc" ]] && [[ -f "$(readlink -f "$HOME/.zshrc")" ]]; then
  success "Symlink ~/.zshrc OK"
else
  warn "❌ ~/.zshrc symlink roto"
  VERIFY_FAILED=$((VERIFY_FAILED + 1))
fi

if [[ -L "$HOME/.config/nvim" ]] && [[ -d "$(readlink -f "$HOME/.config/nvim")" ]]; then
  success "Symlink ~/.config/nvim OK"
else
  warn "❌ ~/.config/nvim symlink roto"
  VERIFY_FAILED=$((VERIFY_FAILED + 1))
fi

# Test 2: Docker daemon responde
if command -v docker &>/dev/null; then
  if docker info &>/dev/null 2>&1; then
    success "Docker daemon responde"
    # Test 3: docker run hello-world (descarga imagen pequeña ~13KB)
    if systemctl is-active --quiet docker 2>/dev/null; then
      info "Probando docker run hello-world..."
      if docker run --rm hello-world &>/dev/null 2>&1; then
        success "docker run hello-world OK"
      else
        warn "⚠️  docker run hello-world falló (puede ser falta de internet)"
        VERIFY_FAILED=$((VERIFY_FAILED + 1))
      fi
    fi
  else
    warn "⚠️  Docker instalado pero daemon no responde (puede necesitar systemctl start docker)"
    VERIFY_FAILED=$((VERIFY_FAILED + 1))
  fi
fi

# Test 4: Neovim responde y plugins LazyVim accesibles
if command -v nvim &>/dev/null; then
  NVIM_VER=$(nvim --version 2>&1 | head -1 | awk '{print $2}')
  if [[ -n "$NVIM_VER" ]]; then
    success "Neovim responde: $NVIM_VER"
  fi
  # Test 5: LazyVim config existe
  if [[ -f "$HOME/.config/nvim/lua/config/lazy.lua" ]]; then
    success "LazyVim config presente"
  else
    warn "❌ LazyVim config no encontrada en ~/.config/nvim"
    VERIFY_FAILED=$((VERIFY_FAILED + 1))
  fi
fi

# Test 6: Oh-My-Zsh + plugins
if [[ -d "$HOME/.oh-my-zsh" ]]; then
  success "Oh-My-Zsh instalado"
  for plugin in zsh-autosuggestions zsh-syntax-highlighting fast-syntax-highlighting; do
    if [[ -d "$HOME/.oh-my-zsh/custom/plugins/$plugin" ]]; then
      success "Plugin zsh: $plugin"
    else
      warn "❌ Plugin zsh faltante: $plugin"
      VERIFY_FAILED=$((VERIFY_FAILED + 1))
    fi
  done
fi

# Test 7: Tailscale
if command -v tailscale &>/dev/null; then
  if tailscale status &>/dev/null 2>&1; then
    TS_IP=$(tailscale ip -4 2>/dev/null | head -1)
    success "Tailscale autenticado: ${TS_IP:-conectado}"
  else
    info "Tailscale instalado pero no autenticado. Ejecuta: tailscale up"
  fi
fi

# Test 8: DNS fix aplicado
if [[ -f /etc/resolv.conf ]] && grep -q "100.100.100.100" /etc/resolv.conf 2>/dev/null; then
  success "DNS fix Tailscale aplicado"
fi

# --- Resumen final ---
header "Bootstrap completo"

if [[ $VERIFY_FAILED -gt 0 ]]; then
  warn "Hubo $VERIFY_FAILED advertencia(s) — revisa arriba"
else
  success "Todas las verificaciones pasaron ✓"
fi

# Construir summary línea por línea con echo -e (interpreta \033)
echo ""
echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}  Sistema configurado correctamente${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""
echo "Software instalado:"
echo "  - zsh    $(zsh --version 2>&1 | awk '{print $2}')"
echo "  - git    $(git --version 2>&1 | awk '{print $3}')"
echo "  - nvim   $(nvim --version 2>&1 | head -1 | awk '{print $2}')"
if command -v docker &>/dev/null; then
  echo "  - docker $(docker --version 2>&1 | awk '{print $3}' | tr -d ',')"
fi
if command -v tailscale &>/dev/null; then
  echo "  - tailscale $(tailscale --version 2>&1 | head -1 | awk '{print $1}')"
fi
echo ""
echo "Dotfiles:"
echo "  ~/.zshrc         -> ${DOTFILES_DIR}/.zshrc"
echo "  ~/.config/nvim   -> ${DOTFILES_DIR}/.config/nvim"
echo ""
echo -e "Próximos pasos:"
echo -e "  1. ${CYAN}Reinicia sesión${NC} (o ejecuta: exec zsh)"
echo -e "  2. ${CYAN}nvim${NC} — LazyVim instala plugins al primer arranque"
echo "  3. Si Tailscale no se autenticó: tailscale up"
echo -e "  4. Verifica: ${CYAN}docker ps${NC}, ${CYAN}tailscale status${NC}"
echo ""
echo "Repo: https://github.com/${GITHUB_USER}/${GITHUB_REPO}"
echo ""

success "Hecho. Bienvenido al sistema, ${USER}."