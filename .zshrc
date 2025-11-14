# ~/.zshrc mínimo y compatible con Zsh 5.0.2

# Path de Oh-My-Zsh
export ZSH="$HOME/.oh-my-zsh"

# Tema simple
ZSH_THEME="agnoster"

# Plugins básicos
plugins=(git zsh-autosuggestions zsh-syntax-highlighting fast-syntax-highlighting)

# Cargar Oh-My-Zsh
source $ZSH/oh-my-zsh.sh

# Alias simples
alias ll='ls -lah'
alias ..='cd ..'

# Historial
HISTSIZE=1000
SAVEHIST=1000
HISTFILE=~/.zsh_history

# Opciones recomendadas
setopt AUTOCD
setopt HIST_IGNORE_DUPS
setopt SHARE_HISTORY
