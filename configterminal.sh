#!/usr/bin/env bash
# Pop!_OS / Ubuntu Zsh + Dev Terminal Setup (Ubuntu-friendly)
# Installs: Zsh, Oh-My-Zsh, Powerlevel10k, Kitty, Nerd Fonts (Meslo + FiraCode),
#           plugins (autosuggestions, syntax-highlighting, completions), eza, bat, fzf, etc.
# Writes:   ~/.zshrc, ~/.p10k.zsh, ~/.config/kitty/kitty.conf
# Run:      bash bootstrap-terminal.sh

set -euo pipefail

log() { echo -e "\033[1;32m[+] $*\033[0m"; }
warn() { echo -e "\033[1;33m[!] $*\033[0m"; }
err() { echo -e "\033[1;31m[✗] $*\033[0m" 1>&2; }

export DEBIAN_FRONTEND=noninteractive

log "Installing base packages..."
sudo apt update -y
sudo apt install -y \
  git curl wget unzip ca-certificates \
  build-essential pkg-config cmake \
  kitty zsh fonts-firacode \
  bat fzf eza \
  fonts-powerline fonts-noto-core fonts-noto-mono fonts-noto-color-emoji || true

# Fix bat naming on Ubuntu
if command -v batcat >/dev/null 2>&1 && ! command -v bat >/dev/null 2>&1; then
  log "Linking batcat → bat"
  sudo update-alternatives --install /usr/bin/bat bat /usr/bin/batcat 10 || true
fi

# --- Nerd Fonts (MesloLGS + FiraCode) ---------------------------------------
install_nf_zip() {
  local name="$1" zipurl="$2" target="$HOME/.local/share/fonts/NerdFonts/$1"
  if fc-list | grep -qi "$1 Nerd Font"; then
    log "Nerd Font '$1' already installed."
    return 0
  fi
  log "Installing Nerd Font: $1"
  mkdir -p "$target"
  ( cd "$target" && curl -fsSLO "$zipurl" && unzip -o "$(basename "$zipurl")" >/dev/null )
  fc-cache -fv >/dev/null || true
}

install_nf_zip "MesloLGS" "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/Meslo.zip"
install_nf_zip "FiraCode"  "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/FiraCode.zip"

# --- Oh My Zsh ---------------------------------------------------------------
log "Installing Oh My Zsh..."
if [ ! -d "$HOME/.oh-my-zsh" ]; then
  RUNZSH=no KEEP_ZSHRC=yes \
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
else
  log "Oh My Zsh already present, skipping."
fi

ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

# --- Powerlevel10k theme -----------------------------------------------------
log "Installing Powerlevel10k theme..."
if [ ! -d "$ZSH_CUSTOM/themes/powerlevel10k" ]; then
  git clone --depth=1 https://github.com/romkatv/powerlevel10k.git \
    "$ZSH_CUSTOM/themes/powerlevel10k"
fi

# --- Zsh plugins -------------------------------------------------------------
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

# --- .zshrc ------------------------------------------------------------------
log "Writing baseline .zshrc..."
cp -f "$HOME/.zshrc" "$HOME/.zshrc.bak.$(date +%Y%m%d-%H%M%S)" 2>/dev/null || true
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
if command -v eza >/dev/null 2>&1; then
  alias ls="eza --icons"
elif command -v exa >/dev/null 2>&1; then
  alias ls="exa --icons"
else
  alias ls="ls --color=auto"
fi

if command -v bat >/dev/null 2>&1; then
  alias cat="bat"
fi

# fzf keybindings (Debian/Ubuntu ship examples in /usr/share/doc)
[ -r /usr/share/doc/fzf/examples/key-bindings.zsh ] && source /usr/share/doc/fzf/examples/key-bindings.zsh
[ -r /usr/share/doc/fzf/examples/completion.zsh ] && source /usr/share/doc/fzf/examples/completion.zsh

# Color man pages through bat if available
if command -v bat >/dev/null 2>&1; then
  export MANPAGER="sh -c 'col -bx | bat -l man -p'"
fi

# Load Powerlevel10k config if present
[[ -f ~/.p10k.zsh ]] && source ~/.p10k.zsh
EOF

# --- .p10k.zsh ---------------------------------------------------------------
log "Installing default Powerlevel10k config..."
cat > "$HOME/.p10k.zsh" <<'EOF'
# Minimal but pretty Powerlevel10k prompt config
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

# --- Kitty config ------------------------------------------------------------
log "Writing baseline Kitty config..."
mkdir -p "$HOME/.config/kitty"
# Prefer MesloLGS Nerd Font Mono; fall back to FiraCode Nerd Font Mono
cat > "$HOME/.config/kitty/kitty.conf" <<'EOF'
font_family      MesloLGS Nerd Font Mono
# alt: FiraCode Nerd Font Mono
font_size        16.0
enable_audio_bell no
cursor_shape     beam
scrollback_lines 20000
confirm_os_window_close 0
EOF

# --- Default shell -----------------------------------------------------------
log "Setting Zsh as default shell (for new sessions)..."
if [ "${SHELL:-}" != "$(command -v zsh)" ]; then
  if ! grep -qx "$(command -v zsh)" /etc/shells 2>/dev/null; then
    echo | sudo tee -a /etc/shells >/dev/null <<< "$(command -v zsh)"
  fi
  chsh -s "$(command -v zsh)" || warn "chsh failed (non-interactive?). You may need to run: chsh -s $(command -v zsh)"
fi

# --- Git defaults ------------------------------------------------------------
log "Configuring Git defaults..."
# Only set name/email if not already set
if ! git config --global user.name >/dev/null 2>&1; then
  git config --global user.name "Your Name"
fi
if ! git config --global user.email >/dev/null 2>&1; then
  git config --global user.email "you@example.com"
fi

git config --global init.defaultBranch main
git config --global pull.rebase false
git config --global color.ui auto

log "Setup complete! Restart Kitty (or run: exec zsh) to see Zsh + Powerlevel10k with full glyphs."
