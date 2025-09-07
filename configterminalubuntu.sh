#!/usr/bin/env bash
# Pop!_OS / Ubuntu Zsh + Dev Terminal Setup
# Run: bash bootstrap-terminal.sh

set -euo pipefail

log() { echo -e "\033[1;32m[+] $*\033[0m"; }
warn(){ echo -e "\033[1;33m[!] $*\033[0m"; }
die(){ echo -e "\033[1;31m[x] $*\033[0m"; exit 1; }

log "Installing base packages..."
sudo apt update -y
sudo apt install -y \
  git curl wget unzip build-essential \
  kitty zsh fonts-firacode \
  bat fzf cmake pkg-config \
  ripgrep fd-find 2>/dev/null || true

# Prefer eza if available; otherwise install exa if repo has it
if apt-cache show eza >/dev/null 2>&1; then
  sudo apt install -y eza
else
  warn "Package 'eza' not found; attempting 'exa' (deprecated)."
  sudo apt install -y exa || true
fi

# Symlink batcat -> bat if needed
if command -v batcat >/dev/null && ! command -v bat >/dev/null; then
  log "Linking batcat → bat"
  sudo update-alternatives --install /usr/bin/bat bat /usr/bin/batcat 10 || true
fi

# Symlink fdfind -> fd (Ubuntu names it fdfind)
if command -v fdfind >/dev/null && ! command -v fd >/dev/null; then
  log "Linking fdfind → fd"
  sudo ln -sf "$(command -v fdfind)" /usr/local/bin/fd
fi

# Install Oh My Zsh (idempotent, no shell switch during install)
log "Installing Oh My Zsh..."
if [ ! -d "$HOME/.oh-my-zsh" ]; then
  RUNZSH=no KEEP_ZSHRC=yes \
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
else
  log "Oh My Zsh already present, skipping."
fi

ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

log "Installing Powerlevel10k theme..."
[ -d "$ZSH_CUSTOM/themes/powerlevel10k" ] || \
  git clone --depth=1 https://github.com/romkatv/powerlevel10k.git \
    "$ZSH_CUSTOM/themes/powerlevel10k"

log "Installing Zsh plugins..."
[ -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ] || \
  git clone https://github.com/zsh-users/zsh-autosuggestions \
    "$ZSH_CUSTOM/plugins/zsh-autosuggestions"

[ -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ] || \
  git clone https://github.com/zsh-users/zsh-syntax-highlighting.git \
    "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"

[ -d "$ZSH_CUSTOM/plugins/zsh-completions" ] || \
  git clone https://github.com/zsh-users/zsh-completions \
    "$ZSH_CUSTOM/plugins/zsh-completions"

# Write/update .zshrc (safe overwrite; re-runnable)
log "Writing baseline .zshrc..."
cat > "$HOME/.zshrc" <<'EOF'
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="powerlevel10k/powerlevel10k"

# NOTE: plugin order matters; syntax-highlighting MUST be last.
plugins=(
  git
  zsh-completions
  zsh-autosuggestions
  zsh-syntax-highlighting
)

source "$ZSH/oh-my-zsh.sh"

# Tools / aliases
if command -v eza >/dev/null; then
  alias ls="eza --icons --group-directories-first"
elif command -v exa >/dev/null; then
  alias ls="exa --icons"
fi
alias cat="bat"

# fzf keybindings (Debian/Ubuntu ships them in /usr/share/doc)
if [ -r /usr/share/doc/fzf/examples/key-bindings.zsh ]; then
  source /usr/share/doc/fzf/examples/key-bindings.zsh
fi
if [ -r /usr/share/doc/fzf/examples/completion.zsh ]; then
  source /usr/share/doc/fzf/examples/completion.zsh
fi

# Make less friendlier with colors via bat when available
export MANPAGER="sh -c 'col -bx | bat -l man -p'"

# Load Powerlevel10k config if present
[[ -f ~/.p10k.zsh ]] && source ~/.p10k.zsh
EOF

# Minimal P10k config (idempotent)
log "Installing default Powerlevel10k config..."
cat > "$HOME/.p10k.zsh" <<'EOF'
typeset -g POWERLEVEL9K_LEFT_PROMPT_ELEMENTS=(os_icon dir vcs)
typeset -g POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS=(status command_execution_time background_jobs time)

typeset -g POWERLEVEL9K_MODE=nerdfont-complete
typeset -g POWERLEVEL9K_PROMPT_ON_NEWLINE=true
typeset -g POWERLEVEL9K_MULTILINE_FIRST_PROMPT_PREFIX="↳ "
typeset -g POWERLEVEL9K_MULTILINE_LAST_PROMPT_PREFIX="❯ "

# Colors
typeset -g POWERLEVEL9K_DIR_FOREGROUND=110
typeset -g POWERLEVEL9K_OS_ICON_FOREGROUND=208
typeset -g POWERLEVEL9K_VCS_FOREGROUND=39
typeset -g POWERLEVEL9K_STATUS_ERROR_FOREGROUND=196
typeset -g POWERLEVEL9K_STATUS_OK_FOREGROUND=46
EOF

# Kitty config
log "Writing baseline Kitty config..."
mkdir -p "$HOME/.config/kitty"
cat > "$HOME/.config/kitty/kitty.conf" <<'EOF'
font_family           FiraCode Nerd Font
font_size             16.0
enable_audio_bell     no
cursor_shape          beam
scrollback_lines      20000
confirm_os_window_close 0
# Handy keys
map ctrl+shift+c copy_to_clipboard
map ctrl+shift+v paste_from_clipboard
EOF

# Default shell to zsh (idempotent)
log "Setting Zsh as default shell..."
if [ "${SHELL:-}" != "$(command -v zsh)" ]; then
  chsh -s "$(command -v zsh)"
fi

# Git sane defaults (only set if missing)
log "Configuring Git defaults..."
git config --global user.name     >/dev/null 2>&1 || git config --global user.name "Your Name"
git config --global user.email    >/dev/null 2>&1 || git config --global user.email "you@example.com"
git config --global init.defaultBranch main
git config --global pull.rebase false
git config --global color.ui auto

log "All set. Open Kitty or restart your terminal to load Zsh + Powerlevel10k."
