#!/usr/bin/env bash
# Pop!_OS / Ubuntu Zsh + Dev Terminal Setup
# Run: bash bootstrap-terminal.sh

set -euo pipefail

log() { echo -e "\033[1;32m[+] $*\033[0m"; }

log "Installing base packages..."
sudo apt update -y
sudo apt install -y \
    git curl wget unzip build-essential \
    kitty zsh fonts-firacode \
    bat fzf cmake pkg-config exa || true

# Fix bat naming on Ubuntu/Pop
if command -v batcat >/dev/null && ! command -v bat >/dev/null; then
  log "Linking batcat → bat"
  sudo update-alternatives --install /usr/bin/bat bat /usr/bin/batcat 10 || true
fi

log "Installing Oh My Zsh..."
if [ ! -d "$HOME/.oh-my-zsh" ]; then
  RUNZSH=no KEEP_ZSHRC=yes \
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
else
  log "Oh My Zsh already present, skipping."
fi

ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

log "Installing Powerlevel10k theme..."
if [ ! -d "$ZSH_CUSTOM/themes/powerlevel10k" ]; then
  git clone --depth=1 https://github.com/romkatv/powerlevel10k.git \
    "$ZSH_CUSTOM/themes/powerlevel10k"
fi

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

log "Writing baseline .zshrc..."
cat > "$HOME/.zshrc" <<'EOF'
export ZSH="$HOME/.oh-my-zsh"

ZSH_THEME="powerlevel10k/powerlevel10k"
plugins=(git zsh-autosuggestions zsh-syntax-highlighting zsh-completions)

source $ZSH/oh-my-zsh.sh

# Tools
alias cat="bat"
alias ls="exa --icons"

# Load Powerlevel10k config if present
[[ -f ~/.p10k.zsh ]] && source ~/.p10k.zsh
EOF

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

log "Writing baseline Kitty config..."
mkdir -p ~/.config/kitty
cat > ~/.config/kitty/kitty.conf <<'EOF'
font_family      FiraCode Nerd Font
font_size        16.0
enable_audio_bell no
cursor_shape     beam
scrollback_lines 20000
confirm_os_window_close 0
EOF

log "Setting Zsh as default shell..."
if [ "$SHELL" != "$(which zsh)" ]; then
  chsh -s "$(which zsh)"
fi

log "Configuring Git defaults..."
git config --global user.name >/dev/null 2>&1 || git config --global user.name "Your Name"
git config --global user.email >/dev/null 2>&1 || git config --global user.email "you@example.com"
git config --global init.defaultBranch main
git config --global pull.rebase false
git config --global color.ui auto

log "Setup complete! Open Kitty or restart terminal to see Zsh + Powerlevel10k."
