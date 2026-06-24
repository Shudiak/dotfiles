#!/usr/bin/env bash
# =============================================================================
# install-nvim.sh
# Instala Neovim en Rocky Linux 8 / CentOS 8 (GLIBC 2.28)
# Soporta el build oficial para GLIBC antiguo de Neovim 0.12+
#
# Uso:
#   curl -fsSL https://raw.githubusercontent.com/Shudiak/dotfiles/master/install-nvim.sh | bash
#   bash install-nvim.sh
#   bash install-nvim.sh --version v0.12.1
#   bash install-nvim.sh --version stable
#   bash install-nvim.sh --version nightly
# =============================================================================

set -euo pipefail

# --- Colores ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

info()    { echo -e "${CYAN}[INFO]${NC} $*"; }
success() { echo -e "${GREEN}[OK]${NC}   $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $*"; }
error()   { echo -e "${RED}[ERR]${NC}  $*"; exit 1; }

# --- Defaults ---
NVIM_VERSION="v0.12.3"
INSTALL_DIR="/opt/nvim"
BIN_LINK="/usr/local/bin/nvim"

# --- Parsear argumentos ---
while [[ $# -gt 0 ]]; do
  case "$1" in
    --version|-v)
      NVIM_VERSION="$2"
      shift 2
      ;;
    --install-dir)
      INSTALL_DIR="$2"
      shift 2
      ;;
    --help|-h)
      echo "Uso: $0 [--version v0.12.1|stable|nightly] [--install-dir /opt/nvim]"
      exit 0
      ;;
    *)
      error "Argumento desconocido: $1"
      ;;
  esac
done

# --- Verificar que corre como root ---
if [[ "$EUID" -ne 0 ]]; then
  error "Este script debe ejecutarse como root"
fi

echo ""
echo -e "${BOLD}================================================${NC}"
echo -e "${BOLD}  Instalador de Neovim — Rocky Linux 8 / CentOS 8${NC}"
echo -e "${BOLD}================================================${NC}"
echo ""
info "Versión a instalar : ${NVIM_VERSION}"
info "Directorio destino : ${INSTALL_DIR}"
info "Enlace binario     : ${BIN_LINK}"
echo ""

# --- Detectar versión de GLIBC ---
GLIBC_VERSION=$(ldd --version | head -1 | grep -oP '\d+\.\d+$' || echo "2.28")
info "GLIBC detectada    : ${GLIBC_VERSION}"

# Rocky 8 tiene 2.28 — necesita el build para GLIBC antiguo
USE_OLDER_GLIBC=false
GLIBC_MAJOR=$(echo "$GLIBC_VERSION" | cut -d. -f1)
GLIBC_MINOR=$(echo "$GLIBC_VERSION" | cut -d. -f2)
if [[ "$GLIBC_MAJOR" -lt 2 ]] || [[ "$GLIBC_MAJOR" -eq 2 && "$GLIBC_MINOR" -lt 29 ]]; then
  USE_OLDER_GLIBC=true
  warn "GLIBC < 2.29 detectada — usando build para sistemas legacy"
fi

# --- Construir URL de descarga ---
# neovim/neovim-releases publica builds compilados con GLIBC antigua (compatible Rocky 8)
BASE_RELEASE_URL="https://github.com/neovim/neovim/releases/download/${NVIM_VERSION}"
BASE_OLDER_URL="https://github.com/neovim/neovim-releases/releases/download/${NVIM_VERSION}"

if [[ "$USE_OLDER_GLIBC" == "true" ]]; then
  APPIMAGE_URL="${BASE_OLDER_URL}/nvim-linux-x86_64.appimage"
else
  APPIMAGE_URL="${BASE_RELEASE_URL}/nvim-linux-x86_64.appimage"
fi

info "URL de descarga    : ${APPIMAGE_URL}"
echo ""

# --- Limpiar instalación previa ---
if [[ -d "$INSTALL_DIR" ]]; then
  warn "Eliminando instalación previa en ${INSTALL_DIR}"
  rm -rf "$INSTALL_DIR"
fi
[[ -L "$BIN_LINK" ]] && rm -f "$BIN_LINK"

# --- Instalar dependencias mínimas ---
info "Verificando dependencias..."
command -v curl &>/dev/null || yum install -y curl
success "Dependencias listas"

# --- Descargar AppImage ---
TMP_DIR=$(mktemp -d)
APPIMAGE_PATH="${TMP_DIR}/nvim.appimage"

info "Descargando Neovim ${NVIM_VERSION}..."
if ! curl -L --progress-bar --fail -o "$APPIMAGE_PATH" "$APPIMAGE_URL"; then
  warn "Descarga principal falló, intentando repo alternativo..."
  ALT_URL="${BASE_OLDER_URL}/nvim-linux-x86_64.appimage"
  curl -L --progress-bar --fail -o "$APPIMAGE_PATH" "$ALT_URL" || \
    error "No se pudo descargar Neovim. Verifica la versión: ${NVIM_VERSION}"
fi
success "Descarga completa"

chmod +x "$APPIMAGE_PATH"

# --- Extraer AppImage (sin FUSE — compatible con Rocky 8) ---
info "Extrayendo AppImage (modo --appimage-extract, sin FUSE)..."
cd "$TMP_DIR"
"$APPIMAGE_PATH" --appimage-extract > /dev/null 2>&1 || \
  error "Falló la extracción. El AppImage puede estar corrupto."

# --- Mover a directorio final ---
mv "${TMP_DIR}/squashfs-root" "$INSTALL_DIR"
success "Instalado en ${INSTALL_DIR}"

# --- Crear symlink ---
ln -sf "${INSTALL_DIR}/usr/bin/nvim" "$BIN_LINK"
success "Symlink: ${BIN_LINK} -> ${INSTALL_DIR}/usr/bin/nvim"

# --- Limpiar temporales ---
rm -rf "$TMP_DIR"

# --- Verificar ---
echo ""
info "Verificando instalación..."
if INSTALLED_VERSION=$("$BIN_LINK" --version 2>&1 | head -1); then
  echo ""
  echo -e "${GREEN}${BOLD}✓ Neovim instalado correctamente${NC}"
  echo -e "  ${INSTALLED_VERSION}"
  echo ""
  echo -e "  Ejecuta: ${CYAN}nvim${NC}"
else
  error "El binario no responde. Revisa: ${INSTALL_DIR}/usr/bin/nvim"
fi

# --- Verificar PATH ---
if ! echo "$PATH" | grep -q "/usr/local/bin"; then
  warn "/usr/local/bin no está en tu PATH. Agrega a ~/.zshrc:"
  echo '  export PATH="/usr/local/bin:$PATH"'
fi