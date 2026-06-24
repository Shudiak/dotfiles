# Shudiak/dotfiles

Dotfiles y scripts de configuración para Rocky Linux 8.x / RHEL 8 / AlmaLinux 8 fresh installs.
Replican el estado del servidor **netwise-sed** (Rocky 8.10) en cualquier host nuevo en ~5-8 minutos.

![Status: Stable](https://img.shields.io/badge/status-stable-brightgreen)
![OS: Rocky 8.x](https://img.shields.io/badge/OS-Rocky%208.x-blue)
![Tested: 2026-06-23](https://img.shields.io/badge/tested-2026--06--23-success)

---

## 🚀 Bootstrap en un solo comando

Para configurar un servidor Rocky 8.x fresh (con internet) desde cero:

```bash
sh -c "$(curl -fsSL https://raw.githubusercontent.com/Shudiak/dotfiles/master/bootstrap.sh)"
```

> **Nota**: la URL usa `master` (no `main`) — este repo usa `master` como default branch.

---

## 📦 What gets installed

El script instala **29 paquetes + 1 servicio** distribuidos así:

### System base (8 paquetes)

| Paquete | Versión esperada | Propósito |
|---|---|---|
| `git` | ≥ 2.39 | Control de versiones |
| `curl` | ≥ 7.61 | HTTP client (bootstrap) |
| `wget` | ≥ 1.19 | HTTP client legacy |
| `tar`, `gzip`, `ca-certificates`, `rsync`, `which` | latest | Utilidades estándar |

### Shell + editor (4 paquetes + 3 plugins zsh)

| Paquete / Plugin | Versión | Propósito |
|---|---|---|
| `zsh` | 5.5.1 | Shell default (cambia con `chsh`) |
| `vim` | latest | Editor fallback |
| `Oh-My-Zsh` | pinned `df34d2b` (15 jun 2026) | Framework de zsh — versión fija para reproducibilidad |
| `zsh-autosuggestions` | plugin | Sugerencias inline basadas en history |
| `zsh-syntax-highlighting` | plugin | Coloreado de comandos en tiempo real |
| `fast-syntax-highlighting` | plugin | Syntax highlighting de URLs, paths, etc. |

### Neovim IDE (2 paquetes)

| Componente | Versión | Propósito |
|---|---|---|
| `neovim` | **0.12.3** | Editor principal (compilado desde source/AppImage) |
| `LazyVim` | latest | Distro Neovim con 30+ plugins pre-configurados |

Plugins incluidos: `blink.cmp`, `catppuccin`, `conform`, `flash`, `gitsigns`, `snacks`, `todo-comments`, `trouble`, `tokyonight`, `mason`, `lspconfig`, `nvim-treesitter`.

### Build tools (4 paquetes)

| Paquete | Propósito |
|---|---|
| `gcc` | Compilador C (para compilar plugins nvim) |
| `make` | Build automation |
| `gcc-c++` | Compilador C++ |
| `kernel-headers` | Headers para compilar módulos |

### Utilities (5 paquetes)

| Paquete | Propósito |
|---|---|
| `tmux` | Multiplexor de terminal |
| `htop` | Monitor de procesos interactivo |
| `nc` (nmap-ncat) | Netcat para debugging de red |
| `nmap` | Scanner de puertos/red |
| `bind-utils` | `dig`, `nslookup`, `host` para DNS debugging |

### Clipboard / X11 (2 paquetes)

| Paquete | Propósito |
|---|---|
| `xclip` | Clipboard de X11 (necesario para `+` register en vim) |
| `xorg-x11-xauth` | X11 authentication forwarding (para SSH X11 forwarding) |

### Containers (2 paquetes + 1 service)

| Paquete | Versión | Propósito |
|---|---|---|
| `docker-ce` | **26.1.3** | Container runtime |
| `docker-compose-plugin` | latest | `docker compose` v2 (substituye `docker-compose`) |
| `dockerd.service` | systemd | Servicio habilitado y arrancado |

### VPN / Networking (2 paquetes + 1 service)

| Paquete | Versión | Propósito |
|---|---|---|
| `tailscale` | **1.98.4** | VPN mesh (WireGuard) |
| `tailscaled.service` | systemd | Daemon habilitado y arrancado |
| `tailscale up` | — | Requiere autenticación interactiva o `--auth-key` |

---

## ⚙️ Configuraciones aplicadas

Además de los paquetes, el script aplica:

| Componente | Configuración |
|---|---|
| **SELinux** | Si está en `Enforcing` y existe `/home/docker/`, aplica contexto `container_file_t` recursivamente. Sin esto, Docker no arranca. |
| **DNS workaround** | Sobrescribe `/etc/resolv.conf` con `8.8.8.8 + 1.1.1.1 + 100.100.100.100` para evitar el bug de Tailscale + NetworkManager. |
| **Tailscale DNS** | `tailscale set --accept-dns=false` para que Tailscale NO controle DNS (evita perder acceso a internet en hosts de un solo nodo). |
| **Shell default** | `chsh -s /bin/zsh` para root. |
| **TZ** | `America/Bogota` configurado vía `.zshrc`. |
| **Symlinks** | `~/.zshrc` → `~/.dotfiles/.zshrc`, `~/.config/nvim` → `~/.dotfiles/.config/nvim`. |
| **Bash → zsh** | Si el usuario hace `bash`, recibe un mensaje recomendando usar `zsh`. |

---

## 🧩 LazyVim (Neovim IDE)

La config de Neovim está basada en [LazyVim](https://www.lazyvim.org/) con:

- **Clipboard**: OSC 52 nativo (compatible con iTerm2, kitty, wezterm, alacritty, tmux)
- **Themes**: tokyonight (default) + catppuccin
- **LSP**: mason + lspconfig + nvim-treesitter (auto-install al primer arranque)

Al primer arranque de `nvim`, LazyVim instala automáticamente todos los plugins.

---

## 🚩 Opciones del bootstrap

```bash
# Bootstrap completo (default)
sh -c "$(curl -fsSL https://raw.githubusercontent.com/Shudiak/dotfiles/master/bootstrap.sh)"

# Sin Tailscale (si no necesitas VPN)
... -- --no-tailscale

# Sin DNS workaround (si tu DNS ya funciona bien)
... -- --no-dns-fix

# Pre-autenticar Tailscale con auth key (no requiere login interactivo)
... -- --tailscale-key tskey-auth-xxxxxxxxxxxx

# Sin auto-arranque de Docker
... -- --no-docker-start

# Generar SSH key (ed25519) si no existe
... -- --ssh-keygen

# Verbose mode (debugging)
... -- --verbose
```

---

## 🔧 Uso individual

### Solo instalar Neovim

```bash
curl -fsSL https://raw.githubusercontent.com/Shudiak/dotfiles/master/install-nvim.sh | bash
```

### Solo aplicar dotfiles (sin instalar paquetes)

```bash
git clone https://github.com/Shudiak/dotfiles.git ~/.dotfiles
ln -sf ~/.dotfiles/.zshrc ~/.zshrc
ln -sfn ~/.dotfiles/.config/nvim ~/.config/nvim
```

---

## 📋 Requisitos

- **OS**: Rocky Linux 8.9+, RHEL 8, AlmaLinux 8, CentOS Stream 8 (también Rocky 9 funciona con ajustes menores)
- **Acceso a internet** (para descargar paquetes, plugins, etc.)
- **Privilegios root** (`sudo` sin password o ejecutar como root)
- **Para Tailscale**: una cuenta en [tailscale.com](https://tailscale.com) o auth key pre-pagada

---

## ✅ Verificar instalación

Después de correr el bootstrap:

```bash
# Versiones instaladas
zsh --version           # → zsh 5.5.1
git --version           # → git version 2.43.x
nvim --version | head -1 # → NVIM v0.12.3
docker --version        # → Docker version 26.1.3
docker compose version  # → Docker Compose version v2.x.x
tailscale version       # → 1.98.x
tailscale status        # → conectado a tailnet (si --no-tailscale no se usó)

# Servicios corriendo
systemctl is-active docker tailscaled
# → active active

# Symlinks aplicados
ls -la ~/.zshrc ~/.config/nvim
# → ~/.zshrc -> /root/.dotfiles/.zshrc
# → ~/.config/nvim -> /root/.dotfiles/.config/nvim
```

---

## 🐛 Troubleshooting

### "curl: (6) Could not resolve host: github.com"

DNS no resuelve. El script **normalmente** arregla esto automáticamente (workaround DNS). Si persiste:

```bash
echo "nameserver 8.8.8.8" > /etc/resolv.conf
echo "nameserver 1.1.1.1" >> /etc/resolv.conf
```

### "Permission denied" al instalar paquetes

Verificar que corres como root: `sudo -i` antes de ejecutar.

### Docker no arranca con "permission denied" en `/home/docker/`

SELinux está bloqueando. Verificar:

```bash
getenforce                     # → Enforcing
ls -laZ /home/docker/ | head   # → debe tener system_u:object_r:container_file_t:s0
```

Aplicar contexto manualmente:

```bash
semanage fcontext -a -t container_file_t "/home/docker(/.*)?"
restorecon -Rv /home/docker/
```

### Tailscale no se autentica tras bootstrap

```bash
tailscale up                   # Login interactivo
# o
tailscale up --authkey=tskey-xxxxx
```

Si Tailscale rompe DNS tras `tailscale up`:

```bash
tailscale set --accept-dns=false
echo "nameserver 8.8.8.8" > /etc/resolv.conf
```

### Neovim falla con "GLIBC not found"

Tu GLIBC es < 2.28 (CentOS 7). El script detecta esto y usa el build legacy de `neovim-releases`.

### LazyVim no instala plugins

Verificar internet y DNS. Si los plugins no se bajan:

```bash
nvim                            # Abre nvim, deja que LazyVim instale
:Lazy sync                      # Forzar sync
```

---

## 📁 Contenido del repo

| Archivo | Destino (via symlink) | Descripción |
|---|---|---|
| `bootstrap.sh` | (no se instala) | Script maestro de bootstrap |
| `install-nvim.sh` | (no se instala) | Instalador standalone de Neovim |
| `.zshrc` | `~/.zshrc` | Configuración zsh + Oh-My-Zsh |
| `.config/nvim/` | `~/.config/nvim/` | Config completa LazyVim |

---

## 📝 Notas

- **Idempotente**: puedes correr el script múltiples veces sin romper nada (detecta lo instalado).
- **No destructivo**: hace backup de `~/.dotfiles` si ya existe antes de clonar.
- **Symlinks, no copias**: edita los archivos en `~/.dotfiles/` y los cambios se reflejan en `~/`.
- **Reproducible**: Oh-My-Zsh está pineado a un SHA fijo (`df34d2b`, 15 jun 2026) para que todos los servers tengan la misma versión de agnoster y plugins. Cambiar manualmente cuando se quiera actualizar.
- **Tailscale requiere acción manual**: tras bootstrap, corre `tailscale up` o usa `--tailscale-key`.

---

## 🔗 Ver también

- [Shudiak/netwise](https://github.com/Shudiak/netwise) — Repo con stacks Docker (Zabbix, GLPI)
- [LazyVim](https://www.lazyvim.org/) — Starter config usada como base
- [Oh-My-Zsh](https://ohmyz.sh/) — Framework de zsh
- [Tailscale](https://tailscale.com/) — VPN mesh basada en WireGuard

---

**Mantenido por**: amo Jonathan (Shudiak) · Generado por Jarvis · Última actualización: 23 jun 2026