-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

-- === Clipboard via OSC 52 (Neovim 0.10+ nativo, sin xclip/wl-copy) ===
-- Funciona en terminales compatibles: iTerm2, kitty, wezterm, alacritty,
-- foot, tmux (con set-clipboard on), gnome-terminal reciente.
-- Compatible con SSH headless: no requiere X11 forwarding ni xclip.
vim.g.clipboard = "osc52"
