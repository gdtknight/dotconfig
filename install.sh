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
  zsh             Link Zsh & Powerlevel10k configuration (~/.zshrc, ~/.p10k.zsh)
  terminal        Link Terminal & utility configurations (Alacritty, WezTerm, Tmux)
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
  link_target "${REPO_DIR}/agents/claude/CLAUDE.md" "${HOME}/.claude/CLAUDE.md"
  link_target "${REPO_DIR}/agents/claude/settings.json" "${HOME}/.claude/settings.json"
  link_target "${REPO_DIR}/agents/claude/rules" "${HOME}/.claude/rules"
  link_target "${REPO_DIR}/agents/claude/agents" "${HOME}/.claude/agents"

  # Gemini (~/.gemini)
  mkdir -p "${HOME}/.gemini/config"
  link_target "${REPO_DIR}/agents/gemini/settings.json" "${HOME}/.gemini/settings.json"
  link_target "${REPO_DIR}/agents/gemini/config.json" "${HOME}/.gemini/config/config.json"
  link_target "${REPO_DIR}/agents/gemini/hooks.json" "${HOME}/.gemini/config/hooks.json"
  link_target "${REPO_DIR}/agents/gemini/mcp_config.json" "${HOME}/.gemini/config/mcp_config.json"

  # Codex (~/.codex)
  mkdir -p "${HOME}/.codex"
  link_target "${REPO_DIR}/agents/codex/config.toml" "${HOME}/.codex/config.toml"
  link_target "${REPO_DIR}/agents/codex/AGENTS.md" "${HOME}/.codex/AGENTS.md"
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
  log_info "Configuring Zsh (Shell, Powerlevel10k, Plugins)..."
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

  # Ensure Oh My Zsh custom plugins are installed if OMZ is present
  local omz_custom="${HOME}/.oh-my-zsh/custom/plugins"
  if [ -d "${HOME}/.oh-my-zsh" ]; then
    mkdir -p "$omz_custom"

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
  fi
}

link_terminal() {
  log_info "Configuring Terminal utilities (Alacritty, WezTerm, Tmux)..."
  link_target "${REPO_DIR}/alacritty" "${HOME}/.config/alacritty"
  link_target "${REPO_DIR}/wezterm/wezterm.lua" "${HOME}/.wezterm.lua"
  if [ "$IS_LINUX" = true ]; then
    mkdir -p "${HOME}/.config/wezterm"
    link_target "${REPO_DIR}/wezterm/wezterm.lua" "${HOME}/.config/wezterm/wezterm.lua"
  fi
  link_target "${REPO_DIR}/tmux/tmux.conf" "${HOME}/.tmux.conf"
}

install_packages() {
  log_info "Checking package manager & Brewfile..."

  local brew_cmd=""
  if command -v brew >/dev/null 2>&1; then
    brew_cmd="brew"
  elif [ -x "/opt/homebrew/bin/brew" ]; then
    brew_cmd="/opt/homebrew/bin/brew"
  elif [ -x "$HOME/.linuxbrew/bin/brew" ]; then
    brew_cmd="$HOME/.linuxbrew/bin/brew"
  elif [ -x "/home/linuxbrew/.linuxbrew/bin/brew" ]; then
    brew_cmd="/home/linuxbrew/.linuxbrew/bin/brew"
  fi

  if [ -n "$brew_cmd" ]; then
    log_info "Using Homebrew at: $("$brew_cmd" --prefix 2>/dev/null || echo "$brew_cmd")"
    if [ "$DRY_RUN" = true ]; then
      log_dry "Run command: '$brew_cmd bundle --file=${REPO_DIR}/Brewfile'"
    else
      "$brew_cmd" bundle --file="${REPO_DIR}/Brewfile"
      log_ok "Brewfile packages processed successfully."
    fi
  else
    log_warn "Homebrew is not detected on this system."
    if [ "$IS_LINUX" = true ]; then
      echo -e "${COLOR_YELLOW}[TIP: Ubuntu without sudo]${COLOR_RESET} You can install Homebrew into your home directory (zero root/sudo required):"
      echo "  1) git clone https://github.com/Homebrew/brew ~/.linuxbrew/Homebrew"
      echo "  2) mkdir -p ~/.linuxbrew/bin"
      echo "  3) ln -s ../Homebrew/bin/brew ~/.linuxbrew/bin"
      echo "  4) eval \$(\$HOME/.linuxbrew/bin/brew shellenv)"
      echo "  5) Re-run: $(basename "$0") packages"
    else
      echo -e "${COLOR_YELLOW}[TIP: macOS]${COLOR_RESET} Install Homebrew via:"
      echo "  /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
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
    nvim|agents|ide|git|zsh|terminal|packages|brew|all)
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
    packages|brew) install_packages ;;
    all)
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
