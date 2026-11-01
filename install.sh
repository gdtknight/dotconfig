#!/usr/bin/env bash
# ==============================================================================
# dotconfig symlink installer & manager
# ==============================================================================
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_BASE="${HOME}/.dotconfig_backups"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
BACKUP_DIR="${BACKUP_BASE}/backup_${TIMESTAMP}"

# Color codes
COLOR_RESET="\033[0m"
COLOR_GREEN="\033[32m"
COLOR_YELLOW="\033[33m"
COLOR_BLUE="\033[34m"
COLOR_RED="\033[31m"
COLOR_GRAY="\033[90m"

DRY_RUN=false
FORCE=false

# OS Detection
OS="$(uname -s)"
IS_MAC=false
IS_LINUX=false
case "$OS" in
  Darwin) IS_MAC=true ;;
  Linux)  IS_LINUX=true ;;
esac

log_info()    { echo -e "${COLOR_BLUE}[INFO]${COLOR_RESET} $*"; }
log_ok()      { echo -e "${COLOR_GREEN}[OK]${COLOR_RESET} $*"; }
log_dry()     { echo -e "${COLOR_YELLOW}[DRY-RUN]${COLOR_RESET} $*"; }
log_backup()  { echo -e "${COLOR_YELLOW}[BACKUP]${COLOR_RESET} $*"; }
log_warn()    { echo -e "${COLOR_RED}[WARN]${COLOR_RESET} $*"; }

usage() {
  cat << EOF
Usage: $(basename "$0") [OPTIONS] [MODULE...]

Modules:
  nvim            Link Neovim configuration (~/.config/nvim)
  agents          Link Agent configurations (Claude, Gemini, Codex)
  ide             Link IDE configurations (Antigravity IDE, IntelliJ)
  git             Link Git global configuration (~/.gitconfig, ~/.gitignore)
  zsh             Link Zsh, Oh My Zsh & Powerlevel10k configuration (~/.zshrc, ~/.p10k.zsh)
  terminal        Link Terminal & utility configurations (Alacritty, WezTerm, Tmux, Nerd Fonts)
  fonts           Install Nerd Fonts (D2Coding, ComicShannsMono)
  packages, brew  Install/sync user-curated packages from Brewfile (non-root compatible)
  all             Link all configurations (Default if no module specified)

Options:
  -n, --dry-run   Preview actions without creating symlinks or modifying files
  -f, --force     Force overwrite / relink even if destination symlink points elsewhere
  -h, --help      Display this help message and exit

Examples:
  $(basename "$0") --dry-run
  $(basename "$0") nvim
  $(basename "$0") agents
  $(basename "$0") all
EOF
}

# ------------------------------------------------------------------------------
# Core linking function
# ------------------------------------------------------------------------------
link_target() {
  local src="$1"
  local dst="$2"

  if [ ! -e "$src" ]; then
    log_warn "Source does not exist: $src"
    return 1
  fi

  local dst_dir
  dst_dir="$(dirname "$dst")"

  # Case 1: Destination is already a symbolic link
  if [ -L "$dst" ]; then
    local current_target
    current_target="$(readlink "$dst")"
    if [ "$current_target" = "$src" ]; then
      log_ok "Already linked: $dst -> $src"
      return 0
    else
      if [ "$DRY_RUN" = true ]; then
        log_dry "Relink $dst -> $src (currently points to: $current_target)"
        return 0
      fi
      rm -f "$dst"
      ln -s "$src" "$dst"
      log_ok "Updated symlink: $dst -> $src"
      return 0
    fi
  fi

  # Case 2: Destination exists as a regular file or directory
  if [ -e "$dst" ]; then
    if [ "$DRY_RUN" = true ]; then
      log_dry "Backup existing $dst to ${BACKUP_DIR} and link to $src"
      return 0
    fi

    # Create backup directory maintaining relative path structure under HOME
    local rel_to_home
    rel_to_home="${dst#$HOME/}"
    local backup_target="${BACKUP_DIR}/${rel_to_home}"
    mkdir -p "$(dirname "$backup_target")"
    mv "$dst" "$backup_target"
    log_backup "Backed up: $dst -> $backup_target"

    mkdir -p "$dst_dir"
    ln -s "$src" "$dst"
    log_ok "Linked: $dst -> $src"
    return 0
  fi

  # Case 3: Destination does not exist
  if [ "$DRY_RUN" = true ]; then
    log_dry "Create symlink: $dst -> $src"
    return 0
  fi

  mkdir -p "$dst_dir"
  ln -s "$src" "$dst"
  log_ok "Created link: $dst -> $src"
}

# ------------------------------------------------------------------------------
# Module linkers
# ------------------------------------------------------------------------------
link_nvim() {
  log_info "Configuring Neovim..."
  link_target "${REPO_DIR}/nvim" "${HOME}/.config/nvim"
}

link_agents() {
  log_info "Configuring Agents (Claude, Gemini, Codex)..."

  # Claude (~/.claude)
  mkdir -p "${HOME}/.claude"
  link_target "${REPO_DIR}/agents/shared/INSTRUCTIONS.md" "${HOME}/.claude/CLAUDE.md"
  link_target "${REPO_DIR}/agents/claude/settings.json" "${HOME}/.claude/settings.json"
  link_target "${REPO_DIR}/agents/shared/rules" "${HOME}/.claude/rules"
  link_target "${REPO_DIR}/agents/shared/agents" "${HOME}/.claude/agents"

  # Gemini (~/.gemini)
  mkdir -p "${HOME}/.gemini/config/skills"
  link_target "${REPO_DIR}/agents/shared/INSTRUCTIONS.md" "${HOME}/.gemini/GEMINI.md"
  link_target "${REPO_DIR}/agents/shared/rules" "${HOME}/.gemini/config/rules"
  link_target "${REPO_DIR}/agents/shared/agents" "${HOME}/.gemini/agents"
  link_target "${REPO_DIR}/agents/gemini/settings.json" "${HOME}/.gemini/settings.json"
  link_target "${REPO_DIR}/agents/gemini/config.json" "${HOME}/.gemini/config/config.json"
  link_target "${REPO_DIR}/agents/gemini/hooks.json" "${HOME}/.gemini/config/hooks.json"
  link_target "${REPO_DIR}/agents/gemini/mcp_config.json" "${HOME}/.gemini/config/mcp_config.json"

  # Codex (~/.codex)
  mkdir -p "${HOME}/.codex/skills"
  link_target "${REPO_DIR}/agents/shared/INSTRUCTIONS.md" "${HOME}/.codex/AGENTS.md"
  link_target "${REPO_DIR}/agents/codex/config.toml" "${HOME}/.codex/config.toml"
  link_target "${REPO_DIR}/agents/codex/agents" "${HOME}/.codex/agents"

  # Link shared agent markdowns as Skills for Gemini and Codex
  local agent_md
  local agent_name
  for agent_md in "${REPO_DIR}/agents/shared/agents"/*.md; do
    if [ -f "$agent_md" ]; then
      agent_name="$(basename "$agent_md" .md)"
      link_target "$agent_md" "${HOME}/.gemini/config/skills/${agent_name}/SKILL.md"
      link_target "$agent_md" "${HOME}/.codex/skills/${agent_name}/SKILL.md"
    fi
  done

  # Ensure Agent CLIs (Antigravity, Claude, Codex) are installed
  # 1) Antigravity CLI (agy)
  if command -v agy >/dev/null 2>&1 || [ -x "${HOME}/.local/bin/agy" ]; then
    log_ok "Antigravity CLI (agy) is installed"
  else
    if [ "$DRY_RUN" = true ]; then
      log_dry "Install Antigravity CLI via: curl -fsSL https://antigravity.google/cli/install.sh | bash"
    else
      log_info "Installing Antigravity CLI (agy)..."
      curl -fsSL https://antigravity.google/cli/install.sh | bash
      log_ok "Installed Antigravity CLI (agy)"
    fi
  fi

  # 2) Claude CLI (claude)
  if command -v claude >/dev/null 2>&1 || [ -x "${HOME}/.local/bin/claude" ]; then
    log_ok "Claude CLI (claude) is installed"
  else
    if [ "$DRY_RUN" = true ]; then
      log_dry "Install Claude CLI via: curl -fsSL https://claude.ai/install.sh | bash"
    else
      log_info "Installing Claude CLI (claude)..."
      curl -fsSL https://claude.ai/install.sh | bash
      log_ok "Installed Claude CLI (claude)"
    fi
  fi

  # 3) Codex CLI (codex)
  if command -v codex >/dev/null 2>&1 || [ -x "${HOME}/.local/bin/codex" ]; then
    log_ok "Codex CLI (codex) is installed"
  else
    if [ "$DRY_RUN" = true ]; then
      log_dry "Install Codex CLI via: curl -fsSL https://chatgpt.com/codex/install.sh | sh"
    else
      log_info "Installing Codex CLI (codex)..."
      curl -fsSL https://chatgpt.com/codex/install.sh | sh
      log_ok "Installed Codex CLI (codex)"
    fi
  fi
}

link_ide() {
  log_info "Configuring IDEs (Antigravity IDE, IntelliJ)..."

  local antigravity_user
  local jetbrains_base
  if [ "$IS_MAC" = true ]; then
    antigravity_user="${HOME}/Library/Application Support/Antigravity IDE/User"
    jetbrains_base="${HOME}/Library/Application Support/JetBrains"
  else
    # Linux (Ubuntu without sudo)
    antigravity_user="${HOME}/.config/Antigravity IDE/User"
    jetbrains_base="${HOME}/.config/JetBrains"
  fi

  mkdir -p "$antigravity_user"
  link_target "${REPO_DIR}/ide/antigravity-ide/settings.json" "${antigravity_user}/settings.json"
  link_target "${REPO_DIR}/ide/antigravity-ide/keybindings.json" "${antigravity_user}/keybindings.json"

  if [ -d "$jetbrains_base" ]; then
    # Find all IntelliJ IDEA installations
    for idea_dir in "${jetbrains_base}"/IntelliJIdea*; do
      if [ -d "$idea_dir" ]; then
        log_info "Found IntelliJ installation: $(basename "$idea_dir")"
        mkdir -p "${idea_dir}/keymaps"
        link_target "${REPO_DIR}/ide/intellij/keymaps/macOS.xml" "${idea_dir}/keymaps/macOS.xml"
        link_target "${REPO_DIR}/ide/intellij/idea.vmoptions" "${idea_dir}/idea.vmoptions"
        link_target "${REPO_DIR}/ide/intellij/idea.properties" "${idea_dir}/idea.properties"
      fi
    done
  fi
}

link_git() {
  log_info "Configuring Git (Global .gitconfig, .gitignore)..."
  link_target "${REPO_DIR}/git/.gitconfig" "${HOME}/.gitconfig"
  link_target "${REPO_DIR}/git/.gitignore" "${HOME}/.gitignore"
}

link_zsh() {
  log_info "Configuring Zsh (Shell, Oh My Zsh, Powerlevel10k, Plugins)..."

  # Ensure Oh My Zsh is installed first so it does not overwrite ~/.zshrc
  local omz_dir="${HOME}/.oh-my-zsh"
  if [ ! -d "$omz_dir" ]; then
    if [ "$DRY_RUN" = true ]; then
      log_dry "Clone Oh My Zsh into ${omz_dir}"
    else
      log_info "Cloning Oh My Zsh..."
      git clone --depth=1 https://github.com/ohmyzsh/ohmyzsh.git "$omz_dir"
      log_ok "Installed Oh My Zsh at: ${omz_dir}"
    fi
  else
    log_ok "Oh My Zsh is installed at: ${omz_dir}"
  fi

  link_target "${REPO_DIR}/zsh/.zshrc" "${HOME}/.zshrc"
  link_target "${REPO_DIR}/zsh/.zprofile" "${HOME}/.zprofile"
  link_target "${REPO_DIR}/zsh/.p10k.zsh" "${HOME}/.p10k.zsh"

  # Ensure powerlevel10k theme is installed
  local p10k_dir="${HOME}/powerlevel10k"
  if [ ! -d "$p10k_dir" ]; then
    if [ "$DRY_RUN" = true ]; then
      log_dry "Clone powerlevel10k into ${p10k_dir}"
    else
      log_info "Cloning powerlevel10k..."
      git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$p10k_dir"
      log_ok "Installed powerlevel10k"
    fi
  else
    log_ok "Powerlevel10k is installed at: ${p10k_dir}"
  fi

  # Link powerlevel10k into Oh My Zsh custom themes for ZSH_THEME="powerlevel10k/powerlevel10k"
  local omz_themes="${omz_dir}/custom/themes"
  if [ "$DRY_RUN" = true ] && [ ! -d "$p10k_dir" ]; then
    log_dry "Create symlink: ${omz_themes}/powerlevel10k -> ${p10k_dir}"
  else
    if [ "$DRY_RUN" = false ]; then
      mkdir -p "$omz_themes"
    fi
    link_target "$p10k_dir" "${omz_themes}/powerlevel10k"
  fi

  # Ensure Oh My Zsh custom plugins are installed
  local omz_custom="${omz_dir}/custom/plugins"
  if [ "$DRY_RUN" = false ]; then
    mkdir -p "$omz_custom"
  fi

  # zsh-autosuggestions
  if [ ! -d "${omz_custom}/zsh-autosuggestions" ]; then
    if [ "$DRY_RUN" = true ]; then
      log_dry "Clone zsh-autosuggestions into ${omz_custom}/zsh-autosuggestions"
    else
      log_info "Cloning zsh-autosuggestions..."
      git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions.git "${omz_custom}/zsh-autosuggestions"
      log_ok "Installed zsh-autosuggestions"
    fi
  else
    log_ok "zsh-autosuggestions is installed"
  fi

  # zsh-syntax-highlighting
  if [ ! -d "${omz_custom}/zsh-syntax-highlighting" ]; then
    if [ "$DRY_RUN" = true ]; then
      log_dry "Clone zsh-syntax-highlighting into ${omz_custom}/zsh-syntax-highlighting"
    else
      log_info "Cloning zsh-syntax-highlighting..."
      git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting.git "${omz_custom}/zsh-syntax-highlighting"
      log_ok "Installed zsh-syntax-highlighting"
    fi
  else
    log_ok "zsh-syntax-highlighting is installed"
  fi
}

install_nerd_font() {
  local font_name="$1"
  local cask_name="$2"
  local zip_name="$3"
  local check_pattern="$4"
  local font_dir

  if [ "$IS_MAC" = true ]; then
    font_dir="${HOME}/Library/Fonts"
  else
    font_dir="${HOME}/.local/share/fonts"
  fi

  if compgen -G "${font_dir}/${check_pattern}" >/dev/null 2>&1; then
    log_ok "Nerd Font (${font_name}) is installed in ${font_dir}"
    return 0
  fi

  if [ "$DRY_RUN" = true ]; then
    if [ "$IS_MAC" = true ] && command -v brew >/dev/null 2>&1; then
      log_dry "Install Nerd Font (${font_name}) via: brew install --cask ${cask_name}"
    else
      log_dry "Download and extract ${zip_name}.zip from Nerd Fonts release into ${font_dir}"
    fi
    return 0
  fi

  mkdir -p "$font_dir"
  if [ "$IS_MAC" = true ] && command -v brew >/dev/null 2>&1; then
    log_info "Installing Nerd Font (${font_name}) via Homebrew Cask..."
    brew install --cask "$cask_name"
    log_ok "Installed Nerd Font (${font_name})"
  else
    log_info "Downloading Nerd Font (${font_name}) to ${font_dir}..."
    local tmp_zip
    tmp_zip="$(mktemp /tmp/nerdfont_XXXXXX.zip)"
    curl -fsSL "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/${zip_name}.zip" -o "$tmp_zip"
    unzip -qo "$tmp_zip" "*.ttf" "*.otf" -d "$font_dir" 2>/dev/null || unzip -qo "$tmp_zip" -d "$font_dir"
    rm -f "$tmp_zip"
    if [ "$IS_LINUX" = true ] && command -v fc-cache >/dev/null 2>&1; then
      fc-cache -f "$font_dir"
    fi
    log_ok "Installed Nerd Font (${font_name}) at: ${font_dir}"
  fi
}

install_fonts() {
  log_info "Checking Nerd Fonts (D2Coding, ComicShannsMono)..."
  install_nerd_font "D2Coding" "font-d2coding-nerd-font" "D2Coding" "D2*NerdFont*"
  install_nerd_font "ComicShannsMono" "font-comic-shanns-mono-nerd-font" "ComicShannsMono" "ComicShannsMonoNerdFont*"

  # Ensure macOS CoreText registers user fonts and strips quarantine attributes
  if [ "$IS_MAC" = true ] && [ "$DRY_RUN" = false ] && [ -d "${HOME}/Library/Fonts" ]; then
    xattr -dr com.apple.quarantine "${HOME}/Library/Fonts" 2>/dev/null || true
    if command -v python3 >/dev/null 2>&1 || command -v swift >/dev/null 2>&1; then
      swift -e '
import CoreText
import Foundation
let dir = URL(fileURLWithPath: NSHomeDirectory() + "/Library/Fonts")
if let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) {
  for f in files where ["otf", "ttf"].contains(f.pathExtension.lowercased()) {
    CTFontManagerRegisterFontsForURL(f as CFURL, .user, nil)
  }
}
' >/dev/null 2>&1 || true
    fi
  fi
}

link_terminal() {
  log_info "Configuring Terminal utilities (Alacritty, WezTerm, Tmux, Nerd Fonts)..."
  install_fonts
  link_target "${REPO_DIR}/alacritty" "${HOME}/.config/alacritty"
  link_target "${REPO_DIR}/wezterm/wezterm.lua" "${HOME}/.wezterm.lua"
  if [ "$IS_LINUX" = true ]; then
    mkdir -p "${HOME}/.config/wezterm"
    link_target "${REPO_DIR}/wezterm/wezterm.lua" "${HOME}/.config/wezterm/wezterm.lua"
  fi
  link_target "${REPO_DIR}/tmux/tmux.conf" "${HOME}/.tmux.conf"

  # Ensure Tmux Plugin Manager (tpm) is installed
  local tpm_dir="${HOME}/.tmux/plugins/tpm"
  if [ ! -d "$tpm_dir" ]; then
    if [ "$DRY_RUN" = true ]; then
      log_dry "Clone tpm into ${tpm_dir}"
    else
      log_info "Cloning Tmux Plugin Manager (tpm)..."
      mkdir -p "$(dirname "$tpm_dir")"
      git clone --depth=1 https://github.com/tmux-plugins/tpm "$tpm_dir"
      log_ok "Installed tpm at: ${tpm_dir}"
    fi
  else
    log_ok "tpm is installed at: ${tpm_dir}"
  fi
}

install_packages() {
  log_info "Checking package manager & Brewfile..."

  local brew_cmd=""
  if command -v brew >/dev/null 2>&1; then
    brew_cmd="brew"
  elif [ -x "/opt/homebrew/bin/brew" ]; then
    brew_cmd="/opt/homebrew/bin/brew"
  elif [ -x "/usr/local/bin/brew" ]; then
    brew_cmd="/usr/local/bin/brew"
  elif [ -x "$HOME/.linuxbrew/bin/brew" ]; then
    brew_cmd="$HOME/.linuxbrew/bin/brew"
  elif [ -x "/home/linuxbrew/.linuxbrew/bin/brew" ]; then
    brew_cmd="/home/linuxbrew/.linuxbrew/bin/brew"
  fi

  # Auto-install Homebrew if not detected
  if [ -z "$brew_cmd" ]; then
    log_warn "Homebrew is not detected on this system."
    if [ "$IS_LINUX" = true ]; then
      if [ "$DRY_RUN" = true ]; then
        log_dry "Install Homebrew (rootless) into ${HOME}/.linuxbrew"
        log_dry "Run command: '${HOME}/.linuxbrew/bin/brew bundle --file=${REPO_DIR}/Brewfile'"
        return 0
      fi
      log_info "Installing Homebrew into ${HOME}/.linuxbrew (no sudo required)..."
      git clone https://github.com/Homebrew/brew "${HOME}/.linuxbrew/Homebrew"
      mkdir -p "${HOME}/.linuxbrew/bin"
      ln -sf ../Homebrew/bin/brew "${HOME}/.linuxbrew/bin/brew"
      eval "$("${HOME}/.linuxbrew/bin/brew" shellenv)"
      brew_cmd="${HOME}/.linuxbrew/bin/brew"
      log_ok "Installed Homebrew at: ${HOME}/.linuxbrew"
    else
      if [ "$DRY_RUN" = true ]; then
        log_dry "Install Homebrew via official macOS installer"
        log_dry "Run command: 'brew bundle --file=${REPO_DIR}/Brewfile'"
        return 0
      fi
      log_info "Installing Homebrew on macOS..."
      /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
      if [ -x "/opt/homebrew/bin/brew" ]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
        brew_cmd="/opt/homebrew/bin/brew"
      elif [ -x "/usr/local/bin/brew" ]; then
        eval "$(/usr/local/bin/brew shellenv)"
        brew_cmd="/usr/local/bin/brew"
      elif command -v brew >/dev/null 2>&1; then
        brew_cmd="brew"
      fi
      log_ok "Installed Homebrew"
    fi
  fi

  if [ -n "$brew_cmd" ]; then
    log_info "Using Homebrew at: $("$brew_cmd" --prefix 2>/dev/null || echo "$brew_cmd")"
    if [ "$DRY_RUN" = true ]; then
      log_dry "Run command: '$brew_cmd bundle --file=${REPO_DIR}/Brewfile'"
    else
      "$brew_cmd" bundle --file="${REPO_DIR}/Brewfile"
      log_ok "Brewfile packages processed successfully."
    fi
  fi
}

# ------------------------------------------------------------------------------
# Argument Parsing
# ------------------------------------------------------------------------------
MODULES=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    -n|--dry-run)
      DRY_RUN=true
      shift
      ;;
    -f|--force)
      FORCE=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    nvim|agents|ide|git|zsh|terminal|fonts|packages|brew|all)
      MODULES+=("$1")
      shift
      ;;
    *)
      log_warn "Unknown option or module: $1"
      usage
      exit 1
      ;;
  esac
done

if [ ${#MODULES[@]} -eq 0 ]; then
  MODULES=("all")
fi

log_info "Starting dotconfig installation from: ${REPO_DIR}"
if [ "$DRY_RUN" = true ]; then
  log_dry "DRY RUN MODE ENABLED - No changes will be written to disk."
fi

for mod in "${MODULES[@]}"; do
  case "$mod" in
    nvim)          link_nvim ;;
    agents)        link_agents ;;
    ide)           link_ide ;;
    git)           link_git ;;
    zsh)           link_zsh ;;
    terminal)      link_terminal ;;
    fonts)         install_fonts ;;
    packages|brew) install_packages ;;
    all)
      install_packages
      link_nvim
      link_agents
      link_ide
      link_git
      link_zsh
      link_terminal
      ;;
  esac
done

log_ok "Completed dotconfig installation tasks."
