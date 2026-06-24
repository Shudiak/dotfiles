# ~/.zshrc — Shudiak (Amo Jonathan)
# Compatible con Zsh 5.0.2+ (Rocky 8 default)
# Mantenido en repo: https://github.com/Shudiak/dotfiles

# === Oh-My-Zsh ===
export ZSH="$HOME/.oh-my-zsh"

# Tema simple y legible
ZSH_THEME="agnoster"

# Plugins
plugins=(git zsh-autosuggestions zsh-syntax-highlighting fast-syntax-highlighting)

source $ZSH/oh-my-zsh.sh

# === PATH additions ===
# Docker (RHEL/Rocky via docker-ce.repo)
export PATH="/usr/local/bin:/usr/bin:/bin:$PATH"

# Local user bin
export PATH="$HOME/.local/bin:$PATH"

# === Aliases ===
alias ll="ls -lah"
alias la="ls -A"
alias l="ls -CF"
alias ..="cd .."
alias ...="cd ../.."
alias g="git"
alias gs="git status"
alias gp="git push"
alias gpl="git pull"
alias gd="git diff"
alias gc="git commit"
alias gco="git checkout"
alias gb="git branch"
alias d="docker"
alias dc="docker compose"
alias dps="docker ps"
alias dcu="docker compose up -d"
alias dcd="docker compose down"
alias k="kubectl" 2>/dev/null

# === Environment ===
export EDITOR="nvim"
export VISUAL="nvim"
export TERM="xterm-256color"
export LANG="en_US.UTF-8"
export LC_ALL="en_US.UTF-8"

# === TZ (Colombia) ===
export TZ="America/Bogota"

# === History ===
HISTSIZE=10000
SAVEHIST=10000
HISTFILE=~/.zsh_history
setopt INC_APPEND_HISTORY
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_SPACE
setopt SHARE_HISTORY

# === Zsh options ===
setopt AUTOCD            # cd sin escribir "cd"
setopt CORRECT           # autocorrect comandos
setopt EXTENDED_GLOB     # glob avanzado
setopt NO_CASE_GLOB      # case-insensitive glob

# === Prompt customization (agnoster compatible) ===
# Muestra user@host en verde/negro según root
# black para root (limpio), green para usuarios normales
[ "$USER" = "root" ] && PROMPT_COLOR="black" || PROMPT_COLOR="green"
prompt_context() {
  if [[ "$USER" != "$DEFAULT_USER" || -n "$SSH_CLIENT" ]]; then
    prompt_segment $PROMPT_COLOR black "%(!.%{%F{yellow}%}.)%n@%m"
  fi
}

# === Tailscale helper (si está) ===
if command -v tailscale &>/dev/null; then
  alias ts="tailscale"
  alias tsip="tailscale ip"
fi

# === SSH agent (opcional) ===
if [[ -z "$SSH_AUTH_SOCK" ]] && [[ -S "$HOME/.ssh/ssh-agent.sock" ]]; then
  export SSH_AUTH_SOCK="$HOME/.ssh/ssh-agent.sock"
fi

# === Welcome message ===
if [[ -o interactive ]] && command -v neofetch &>/dev/null; then
  neofetch
fi
