# Shudiak/dotfiles

Dotfiles y scripts de configuración para Rocky Linux 8.9 / RHEL 8 / AlmaLinux 8 fresh installs.

## 🚀 Bootstrap en un solo comando

Para configurar un servidor Rocky 8.9 fresh (con internet) desde cero:

```bash
sh -c "$(curl -fsSL https://raw.githubusercontent.com/Shudiak/dotfiles/main/bootstrap.sh)"
```

Esto instala:
- ✅ **zsh** + Oh-My-Zsh + plugins (`zsh-autosuggestions`, `zsh-syntax-highlighting`, `fast-syntax-highlighting`)
- ✅ **Neovim 0.12+** + LazyVim (config completa de IDE)
- ✅ **Git, curl, wget**, etc.
- ✅ **Docker** + docker compose plugin
- ✅ **Dotfiles** del repo via symlinks

### Opciones

```bash
# Sin Docker (para servidores de app pura)
sh -c "$(curl -fsSL https://raw.githubusercontent.com/Shudiak/dotfiles/main/bootstrap.sh)" -- --no-docker

# Versión específica de Neovim
... -- --neovim-version v0.12.1

# Generar SSH key automáticamente
... -- --ssh-keygen
```

## 📦 Contenido del repo

| Archivo | Destino (via symlink) | Descripción |
|---|---|---|
| `bootstrap.sh` | (no se instala) | Script maestro de bootstrap |
| `install-nvim.sh` | (no se instala) | Instalador standalone de Neovim |
| `.zshrc` | `~/.zshrc` | Configuración zsh + Oh-My-Zsh |
| `.config/nvim/` | `~/.config/nvim/` | Config completa LazyVim |

## 🧩 LazyVim (Neovim IDE)

La config de Neovim está basada en [LazyVim](https://www.lazyvim.org/) con:

- **Plugins incluidos**: blink.cmp, catppuccin, conform, flash, gitsigns, snacks, todo-comments, trouble, etc.
- **LSP**: mason + lspconfig + nvim-treesitter
- **Clipboard**: OSC 52 nativo (compatible con iTerm2, kitty, wezterm, alacritty, tmux)
- **Themes**: tokyonight (default) + catppuccin

Al primer arranque de `nvim`, LazyVim instala automáticamente todos los plugins.

## 🔧 Uso individual

### Solo instalar Neovim

```bash
curl -fsSL https://raw.githubusercontent.com/Shudiak/dotfiles/main/install-nvim.sh | bash
```

### Solo aplicar dotfiles (sin instalar paquetes)

```bash
git clone https://github.com/Shudiak/dotfiles.git ~/.dotfiles
ln -sf ~/.dotfiles/.zshrc ~/.zshrc
ln -sfn ~/.dotfiles/.config/nvim ~/.config/nvim
```

## 📋 Requisitos

- **OS**: Rocky Linux 8.9+, RHEL 8, AlmaLinux 8, CentOS Stream 8
- **Acceso a internet** (para descargar paquetes, plugins, etc.)
- **Privilegios root** (`sudo` sin password o ejecutar como root)

## 🐛 Troubleshooting

### "curl: (6) Could not resolve host: github.com"

DNS no resuelve. Configurar DNS público:
```bash
echo "nameserver 8.8.8.8" > /etc/resolv.conf
echo "nameserver 1.1.1.1" >> /etc/resolv.conf
```

### "Permission denied" al instalar paquetes

Verificar que corres como root: `sudo -i` antes de ejecutar.

### Neovim falla con "GLIBC not found"

Tu GLIBC es < 2.28 (CentOS 7). El script detecta esto y usa el build legacy de `neovim-releases`.

### LazyVim no instala plugins

Verificar internet y DNS. Si usas Tailscale y desactiva DNS management:
```bash
tailscale set --accept-dns=false
echo "nameserver 8.8.8.8" > /etc/resolv.conf
```

## 📝 Notas

- **Idempotente**: puedes correr el script múltiples veces sin romper nada (detecta lo instalado).
- **No destructivo**: hace backup de `~/.dotfiles` si ya existe antes de clonar.
- **Symlinks, no copias**: edita los archivos en `~/.dotfiles/` y los cambios se reflejan en `~/`.

## 🔗 Ver también

- [Shudiak/netwise](https://github.com/Shudiak/netwise) — Repo privado con stacks Docker (Zabbix, GLPI)
- [LazyVim](https://www.lazyvim.org/) — Starter config usada como base
- [Oh-My-Zsh](https://ohmyz.sh/) — Framework de zsh

---

**Mantenido por**: amo Jonathan (Shudiak) · Generado por Jarvis
