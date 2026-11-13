#!/usr/bin/env bash
# ==============================================================================
# dotconfig symlink installer & manager
# ==============================================================================
set -euo pipefail

# ------------------------------------------------------------------------------
# 0. Self-Bootstrapping Guard (for curl/web one-line execution)
# ------------------------------------------------------------------------------
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-}")" 2>/dev/null && pwd || echo "")"
DEFAULT_TARGET_REPO="${DOTCONFIG_DIR:-${HOME}/.dotconfig}"
DOTCONFIG_REMOTE_URL="${DOTCONFIG_REMOTE_URL:-https://github.com/gdtknight/dotconfig.git}"

# Color codes
COLOR_RESET="\033[0m"
COLOR_GREEN="\033[32m"
COLOR_YELLOW="\033[33m"
COLOR_BLUE="\033[34m"
COLOR_RED="\033[31m"
COLOR_GRAY="\033[90m"

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

# TTY-safe input prompt (handles curl | bash pipes)
read_prompt() {
  local prompt="$1"
  local var_name="$2"
  if [ -c /dev/tty ]; then
    read -r -p "$prompt" "$var_name" < /dev/tty
  else
    read -r -p "$prompt" "$var_name"
  fi
}

# If executed directly from web (outside a valid dotconfig git repo)
if [ -z "$REPO_DIR" ] || [ ! -d "${REPO_DIR}/.git" ] || [ ! -f "${REPO_DIR}/git/.gitconfig" ]; then
  echo -e "${COLOR_BLUE}================================================================================${COLOR_RESET}"
  echo -e "${COLOR_GREEN}  dotconfig Web Bootstrapper${COLOR_RESET}"
  echo -e "${COLOR_BLUE}================================================================================${COLOR_RESET}"
  log_info "Running via web installer. Preparing local environment..."

  # 1. macOS Command Line Tools (git requirement)
  if [ "$IS_MAC" = true ]; then
    if ! xcode-select -p >/dev/null 2>&1; then
      log_info "Xcode Command Line Tools not found. Requesting installation..."
      xcode-select --install || true
      echo -e "${COLOR_YELLOW}Press enter after the Xcode Command Line Tools installation finishes...${COLOR_RESET}"
      read_prompt "Press [Enter] to continue..." _wait_xcode
    fi

    # 2. Check & Bootstrap Homebrew on macOS
    local_brew=""
    if command -v brew >/dev/null 2>&1; then
      local_brew="brew"
    elif [ -x "/opt/homebrew/bin/brew" ]; then
      local_brew="/opt/homebrew/bin/brew"
      eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [ -x "/usr/local/bin/brew" ]; then
      local_brew="/usr/local/bin/brew"
      eval "$(/usr/local/bin/brew shellenv)"
    fi

    if [ -z "$local_brew" ]; then
      log_info "Homebrew not detected. Installing Homebrew..."
      /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
      if [ -x "/opt/homebrew/bin/brew" ]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
      elif [ -x "/usr/local/bin/brew" ]; then
        eval "$(/usr/local/bin/brew shellenv)"
      fi
    fi
  fi

  # 3. Ensure git is available
  if ! command -v git >/dev/null 2>&1; then
    log_warn "'git' is required to clone dotconfig but was not found in PATH."
    exit 1
  fi

  # 4. Clone or update repository
  if [ -d "${DEFAULT_TARGET_REPO}/.git" ]; then
    log_info "Existing dotconfig repository found at ${DEFAULT_TARGET_REPO}. Pulling latest..."
    git -C "$DEFAULT_TARGET_REPO" pull --ff-only || true
  else
    log_info "Cloning dotconfig repository into ${DEFAULT_TARGET_REPO}..."
    mkdir -p "$(dirname "$DEFAULT_TARGET_REPO")"
    git clone "$DOTCONFIG_REMOTE_URL" "$DEFAULT_TARGET_REPO"
    log_ok "Successfully cloned dotconfig into ${DEFAULT_TARGET_REPO}"
  fi

  # 5. Hand over execution to local installer
  log_info "Handoff to local installer: ${DEFAULT_TARGET_REPO}/install.sh $*"
  echo ""
  exec /bin/bash "${DEFAULT_TARGET_REPO}/install.sh" "$@"
fi

BACKUP_BASE="${HOME}/.dotconfig_backups"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
BACKUP_DIR="${BACKUP_BASE}/backup_${TIMESTAMP}"

DRY_RUN=false
FORCE=false

usage() {
  cat << EOF
Usage: $(basename "$0") [OPTIONS] [MODULE...]

Web One-Line Quickstart:
  /bin/bash -c "\$(curl -fsSL https://raw.githubusercontent.com/gdtknight/dotconfig/main/install.sh)"
  /bin/bash -c "\$(curl -fsSL https://raw.githubusercontent.com/gdtknight/dotconfig/main/install.sh)" -- nvim git
  /bin/bash -c "\$(curl -fsSL https://raw.githubusercontent.com/gdtknight/dotconfig/main/install.sh)" -- --dry-run

Modules:
  nvim            Link Neovim configuration (~/.config/nvim)
  agents          Link Agent configurations (Claude, Gemini, Codex)
  ide             Link IDE configurations (Antigravity IDE, IntelliJ) & sync extensions
  git             Link Git global configuration & multi-account workspaces (~/Projects)
  zsh             Link Zsh, Oh My Zsh & Powerlevel10k configuration (~/.zshrc, ~/.p10k.zsh)
  terminal        Link Terminal & utility configurations (Alacritty, WezTerm, Tmux, Nerd Fonts)
  fonts           Install Nerd Fonts (D2Coding, ComicShannsMono)
  formatter, docker Build the dotconfig-formatter Docker image (Prettier, Ruff, Clang-format, StyLua, Google-Java-Format)
  packages, brew  Install/sync user-curated packages from Brewfile (non-root compatible)
  all             Link all configurations (Default if no module specified)

Options:
  -n, --dry-run   Preview actions without creating symlinks or modifying files
  -f, --force     Force overwrite / relink even if destination symlink points elsewhere
  --dump-extensions Dump currently installed Antigravity IDE extensions to extensions.txt
  -h, --help      Display this help message and exit

Environment Variables:
  DOTCONFIG_DIR   Target repository directory (Default: ~/.dotconfig)
  NONINTERACTIVE  Set to 1 to bypass interactive prompts in automated/CI setups

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
  link_target "${REPO_DIR}/agents/shared/hooks" "${HOME}/.claude/hooks"

  # Gemini (~/.gemini)
  mkdir -p "${HOME}/.gemini/config/skills"
  link_target "${REPO_DIR}/agents/shared/INSTRUCTIONS.md" "${HOME}/.gemini/GEMINI.md"
  link_target "${REPO_DIR}/agents/shared/rules" "${HOME}/.gemini/config/rules"
  link_target "${REPO_DIR}/agents/shared/agents" "${HOME}/.gemini/agents"
  link_target "${REPO_DIR}/agents/gemini/settings.json" "${HOME}/.gemini/settings.json"
  link_target "${REPO_DIR}/agents/gemini/config.json" "${HOME}/.gemini/config/config.json"
  link_target "${REPO_DIR}/agents/gemini/hooks.json" "${HOME}/.gemini/config/hooks.json"
  link_target "${REPO_DIR}/agents/shared/hooks" "${HOME}/.gemini/config/hooks"
  link_target "${REPO_DIR}/agents/gemini/mcp_config.json" "${HOME}/.gemini/config/mcp_config.json"

  # Codex (~/.codex)
  mkdir -p "${HOME}/.codex/skills"
  link_target "${REPO_DIR}/agents/shared/INSTRUCTIONS.md" "${HOME}/.codex/AGENTS.md"
  link_target "${REPO_DIR}/agents/codex/config.toml" "${HOME}/.codex/config.toml"
  link_target "${REPO_DIR}/agents/codex/agents" "${HOME}/.codex/agents"
  link_target "${REPO_DIR}/agents/shared/hooks" "${HOME}/.codex/hooks"

  # Clean up stale/dangling skill symlinks in Gemini and Codex
  local skill_file
  for skill_file in "${HOME}/.gemini/config/skills"/*/SKILL.md "${HOME}/.codex/skills"/*/SKILL.md; do
    if [ -L "$skill_file" ] && [ ! -e "$skill_file" ]; then
      if [ "$DRY_RUN" = true ]; then
        log_dry "Remove broken skill symlink: $skill_file"
      else
        rm -f "$skill_file"
        rmdir "$(dirname "$skill_file")" 2>/dev/null || true
        log_ok "Removed stale skill symlink: $skill_file"
      fi
    fi
  done

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

find_ide_cli() {
  if [ "$IS_LINUX" = true ]; then
    # On Linux (Ubuntu), prioritize default system-installed VS Code ('code')
    if command -v code >/dev/null 2>&1; then
      echo "code"
      return 0
    fi
  fi

  # Prioritize Antigravity IDE (primary on macOS)
  if command -v antigravity-ide >/dev/null 2>&1; then
    echo "antigravity-ide"
  elif [ -x "${HOME}/.antigravity-ide/antigravity-ide/bin/antigravity-ide" ]; then
    echo "${HOME}/.antigravity-ide/antigravity-ide/bin/antigravity-ide"
  elif [ -x "/Applications/Antigravity IDE.app/Contents/Resources/app/bin/antigravity-ide" ]; then
    echo "/Applications/Antigravity IDE.app/Contents/Resources/app/bin/antigravity-ide"
  elif [ -x "${HOME}/.local/bin/antigravity-ide" ]; then
    echo "${HOME}/.local/bin/antigravity-ide"
  elif command -v code >/dev/null 2>&1; then
    # Fallback to standard VS Code
    echo "code"
  elif [ -x "/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code" ]; then
    echo "/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code"
  fi
}

find_antigravity_cli() {
  find_ide_cli
}

setup_goinfre_symlink() {
  local target_home="$1"
  local rel_path="$2"

  local goinfre_dir="${HOME}/goinfre/${rel_path}"
  local home_dest="${HOME}/${rel_path}"

  if [ ! -d "${HOME}/goinfre" ]; then
    return 0
  fi

  if [ -L "$home_dest" ] && [ "$(readlink "$home_dest")" = "$goinfre_dir" ]; then
    log_ok "Goinfre link active: ${home_dest} -> ${goinfre_dir}"
    return 0
  fi

  if [ "$DRY_RUN" = true ]; then
    log_dry "Relocate ${home_dest} to ${goinfre_dir} (NFS Quota Protection)"
    return 0
  fi

  mkdir -p "$goinfre_dir"
  if [ -d "$home_dest" ] && [ ! -L "$home_dest" ]; then
    log_info "Moving existing ${home_dest} to ${goinfre_dir}..."
    cp -rn "${home_dest}"/* "$goinfre_dir/" 2>/dev/null || true
    rm -rf "$home_dest"
  fi

  mkdir -p "$(dirname "$home_dest")"
  ln -sfn "$goinfre_dir" "$home_dest"
  log_ok "Linked to goinfre: ${home_dest} -> ${goinfre_dir}"
}

install_antigravity_extensions() {
  local ext_file="${REPO_DIR}/ide/antigravity-ide/extensions.txt"
  if [ ! -f "$ext_file" ]; then
    return 0
  fi

  local ide_bin
  ide_bin="$(find_ide_cli)"
  if [ -z "$ide_bin" ]; then
    log_warn "IDE CLI (code/antigravity-ide) not found; skipping extensions sync."
    return 0
  fi

  log_info "Syncing extensions for ${ide_bin} from ${ext_file}..."

  local installed_raw
  installed_raw="$("$ide_bin" --list-extensions 2>/dev/null | grep -v "^\\[" | tr '[:upper:]' '[:lower:]' || true)"

  local ext
  local ext_clean
  local ext_lower
  local missing_count=0

  while IFS= read -r ext || [ -n "$ext" ]; do
    # Strip comments and whitespace
    ext_clean="$(echo "$ext" | sed -e 's/#.*$//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
    [ -z "$ext_clean" ] && continue

    ext_lower="$(echo "$ext_clean" | tr '[:upper:]' '[:lower:]')"
    if echo "$installed_raw" | grep -qx "$ext_lower"; then
      continue
    fi

    missing_count=$((missing_count + 1))
    if [ "$DRY_RUN" = true ]; then
      log_dry "Install ${ide_bin} extension: $ext_clean"
    else
      log_info "Installing ${ide_bin} extension: $ext_clean..."
      if ! "$ide_bin" --install-extension "$ext_clean" --force >/dev/null 2>&1; then
        log_warn "Failed to install extension: $ext_clean"
      fi
      log_ok "Installed extension: $ext_clean"
    fi
  done < "$ext_file"

  if [ "$missing_count" -eq 0 ]; then
    log_ok "All extensions for ${ide_bin} are up-to-date."
  fi
}

dump_antigravity_extensions() {
  local ext_file="${REPO_DIR}/ide/antigravity-ide/extensions.txt"
  local ide_bin
  ide_bin="$(find_ide_cli)"
  if [ -z "$ide_bin" ]; then
    log_warn "IDE CLI (code/antigravity-ide) not found. Cannot export extensions."
    return 1
  fi

  log_info "Exporting installed extensions from ${ide_bin} to ${ext_file}..."
  local exts
  exts="$("$ide_bin" --list-extensions 2>/dev/null | grep -v "^\\[" | sort)"
  if [ -z "$exts" ]; then
    log_warn "No extensions found to export."
    return 0
  fi

  if [ "$DRY_RUN" = true ]; then
    log_dry "Would write $(echo "$exts" | wc -l | tr -d ' ') extensions to ${ext_file}"
    return 0
  fi

  mkdir -p "$(dirname "$ext_file")"
  echo "$exts" > "$ext_file"
  log_ok "Exported $(wc -l < "$ext_file" | tr -d ' ') extensions to ${ext_file}"
}

link_ide() {
  log_info "Configuring IDEs (VS Code / Antigravity IDE, IntelliJ)..."

  # 1. 42 Goinfre Quota Protection: Relocate extension storage to goinfre if available
  if [ -d "${HOME}/goinfre" ]; then
    log_info "Detected ~/goinfre. Configuring quota-safe extension storage..."
    setup_goinfre_symlink "${HOME}" ".vscode/extensions"
    setup_goinfre_symlink "${HOME}" ".antigravity-ide/extensions"
  fi

  # 2. Setup user settings and keybindings per platform
  local target_user_dirs=()

  if [ "$IS_MAC" = true ]; then
    target_user_dirs+=("${HOME}/Library/Application Support/Antigravity IDE/User")
    if [ -d "${HOME}/Library/Application Support/Code/User" ] || command -v code >/dev/null 2>&1; then
      target_user_dirs+=("${HOME}/Library/Application Support/Code/User")
    fi
  else
    # Linux (Ubuntu): Prioritize system VS Code ('Code')
    target_user_dirs+=("${HOME}/.config/Code/User")
    if [ -d "${HOME}/.config/Antigravity IDE/User" ] || command -v antigravity-ide >/dev/null 2>&1; then
      target_user_dirs+=("${HOME}/.config/Antigravity IDE/User")
    fi
  fi

  for user_dir in "${target_user_dirs[@]}"; do
    mkdir -p "$user_dir"
    link_target "${REPO_DIR}/ide/antigravity-ide/settings.json" "${user_dir}/settings.json"
    link_target "${REPO_DIR}/ide/antigravity-ide/keybindings.json" "${user_dir}/keybindings.json"
  done

  # 3. Synchronize extensions
  install_antigravity_extensions

  # 4. IntelliJ configurations (if present)
  local jetbrains_base
  if [ "$IS_MAC" = true ]; then
    jetbrains_base="${HOME}/Library/Application Support/JetBrains"
  else
    jetbrains_base="${HOME}/.config/JetBrains"
  fi

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

guide_github_ssh_key() {
  local user="$1"
  local email="$2"
  local pub_key="${HOME}/.ssh/id_ed25519_${user}.pub"

  if [ ! -f "$pub_key" ]; then
    return 0
  fi

  local copied=false
  if command -v pbcopy >/dev/null 2>&1; then
    pbcopy < "$pub_key"
    copied=true
  fi

  echo ""
  echo -e "${COLOR_GREEN}================================================================================${COLOR_RESET}"
  if [ "$copied" = true ]; then
    echo -e "${COLOR_GREEN}[GitHub SSH Key 등록 안내] ${COLOR_RESET}${COLOR_YELLOW}${user} (${email})${COLOR_RESET} 공개키가 클립보드에 복사되었습니다! (pbcopy)"
  else
    echo -e "${COLOR_GREEN}[GitHub SSH Key 등록 안내] ${COLOR_RESET}${COLOR_YELLOW}${user} (${email})${COLOR_RESET}"
    echo -e "공개키 내용: $(cat "$pub_key")"
  fi
  echo -e "👉 GitHub 등록 링크: ${COLOR_BLUE}https://github.com/settings/ssh/new${COLOR_RESET}"
  echo -e "   - Title: MacBook (${user})"
  echo -e "   - Key type: Authentication Key (또는 Signing Key)"
  echo -e "   - Key: Cmd + V (붙여넣기)"
  echo -e "${COLOR_GREEN}================================================================================${COLOR_RESET}"
}

setup_git_accounts() {
  log_info "Configuring Multi-account Git workspaces and SSH keys..."

  local local_env="${HOME}/.config/dotconfig/git-accounts.env"
  local can_prompt=false
  if [ "${NONINTERACTIVE:-0}" != "1" ] && { [ -t 0 ] || [ -c /dev/tty ]; }; then
    can_prompt=true
  fi

  if [ -f "$local_env" ]; then
    # shellcheck disable=SC1090
    . "$local_env"
  else
    if [ "$can_prompt" = true ]; then
      echo ""
      echo -e "${COLOR_BLUE}============================================================${COLOR_RESET}"
      echo -e "${COLOR_BLUE}[Git 다중 계정 설정]${COLOR_RESET} 계정 분기 설정을 위해 2개 계정 정보를 입력해주세요."
      echo -e "${COLOR_BLUE}============================================================${COLOR_RESET}"
      read_prompt "계정 1 GitHub Username (예: personal): " ACCOUNT1_USER
      read_prompt "계정 1 Git 작성자 이름 (예: Hong Gildong): " ACCOUNT1_NAME
      read_prompt "계정 1 이메일 (예: user@example.com): " ACCOUNT1_EMAIL
      echo ""
      read_prompt "계정 2 GitHub Username (예: work): " ACCOUNT2_USER
      read_prompt "계정 2 Git 작성자 이름 (예: Gildong Hong): " ACCOUNT2_NAME
      read_prompt "계정 2 이메일 (예: work@company.com): " ACCOUNT2_EMAIL
      echo -e "${COLOR_BLUE}============================================================${COLOR_RESET}"
    fi

    # Check if accounts are provided
    if [ -z "${ACCOUNT1_USER:-}" ] || [ -z "${ACCOUNT2_USER:-}" ]; then
      log_warn "Git accounts configuration not found or incomplete."
      log_info "Create ${local_env} to enable multi-account Git workspaces."
      return 0
    fi

    if [ "$DRY_RUN" = true ]; then
      log_dry "Initialize git accounts config at: ${local_env}"
    else
      mkdir -p "$(dirname "$local_env")"
      cat > "$local_env" << EOF
ACCOUNT1_USER="${ACCOUNT1_USER}"
ACCOUNT1_NAME="${ACCOUNT1_NAME}"
ACCOUNT1_EMAIL="${ACCOUNT1_EMAIL}"

ACCOUNT2_USER="${ACCOUNT2_USER}"
ACCOUNT2_NAME="${ACCOUNT2_NAME}"
ACCOUNT2_EMAIL="${ACCOUNT2_EMAIL}"
EOF
      log_ok "Saved git accounts config to: ${local_env}"
    fi
  fi

  local ssh_dir="${HOME}/.ssh"

  # Process Account 1 and Account 2
  local u n e k p cfg
  local idx=1
  while [ "$idx" -le 2 ]; do
    if [ "$idx" -eq 1 ]; then
      u="$ACCOUNT1_USER"
      n="$ACCOUNT1_NAME"
      e="$ACCOUNT1_EMAIL"
    else
      u="$ACCOUNT2_USER"
      n="$ACCOUNT2_NAME"
      e="$ACCOUNT2_EMAIL"
    fi

    k="${ssh_dir}/id_ed25519_${u}"
    p="${HOME}/Projects/${u}"
    cfg="${HOME}/.gitconfig-${u}"

    # 1. Project Directory
    if [ ! -d "$p" ]; then
      if [ "$DRY_RUN" = true ]; then
        log_dry "Create workspace: ${p}"
      else
        mkdir -p "$p"
        log_ok "Created workspace: ${p}"
      fi
    else
      log_ok "Workspace exists: ${p}"
    fi

    # 2. SSH Key Pair
    if [ ! -f "$k" ]; then
      if [ "$DRY_RUN" = true ]; then
        log_dry "Generate ed25519 SSH key: ${k} (${e})"
      else
        mkdir -p "$ssh_dir"
        chmod 700 "$ssh_dir"
        log_info "Generating SSH key for ${u} (${e})..."
        ssh-keygen -t ed25519 -C "$e" -f "$k" -N "" >/dev/null 2>&1
        chmod 600 "$k"
        chmod 644 "${k}.pub"
        log_ok "Generated SSH key: ${k}"
      fi
    else
      log_ok "SSH key already exists: ${k}"
    fi

    # 3. Dedicated .gitconfig-<user>
    if [ "$DRY_RUN" = true ]; then
      log_dry "Create git config ${cfg} (user=${n}, email=${e})"
    else
      cat > "$cfg" << EOF
[user]
	name = ${n}
	email = ${e}
	signingkey = ${k}.pub
[core]
	sshCommand = ssh -i ${k} -F /dev/null
EOF
      log_ok "Configured: ${cfg}"
    fi

    idx=$((idx + 1))
  done

  # 4. Generate ~/.gitconfig.local with includeIf rules
  local local_gitconfig="${HOME}/.gitconfig.local"
  if [ "$DRY_RUN" = true ]; then
    log_dry "Configure ${local_gitconfig} with includeIf rules for ${ACCOUNT1_USER} and ${ACCOUNT2_USER}"
  else
    cat > "$local_gitconfig" << EOF
# Auto-generated by dotconfig install.sh (Never committed)
# Default fallback user
[user]
	name = ${ACCOUNT1_NAME}
	email = ${ACCOUNT1_EMAIL}

# Multi-account directory includes
[includeIf "gitdir:~/Projects/${ACCOUNT1_USER}/"]
	path = ~/.gitconfig-${ACCOUNT1_USER}

[includeIf "gitdir:~/dev/"]
	path = ~/.gitconfig-${ACCOUNT1_USER}

[includeIf "gitdir:~/Projects/${ACCOUNT2_USER}/"]
	path = ~/.gitconfig-${ACCOUNT2_USER}
EOF
    log_ok "Configured: ${local_gitconfig}"
  fi

  # 5. GitHub SSH Key Guide (Option A)
  if [ "$DRY_RUN" = false ]; then
    guide_github_ssh_key "$ACCOUNT1_USER" "$ACCOUNT1_EMAIL"
    if [ "$can_prompt" = true ]; then
      echo ""
      read_prompt "엔터를 누르면 두 번째 계정 (${ACCOUNT2_USER}) 키를 클립보드에 복사합니다..." _prompt_enter || true
    fi
    guide_github_ssh_key "$ACCOUNT2_USER" "$ACCOUNT2_EMAIL"
  fi
}

link_git() {
  log_info "Configuring Git (Global .gitconfig, .gitignore)..."
  link_target "${REPO_DIR}/git/.gitconfig" "${HOME}/.gitconfig"
  link_target "${REPO_DIR}/git/.gitignore" "${HOME}/.gitignore"
  setup_git_accounts
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

build_formatter() {
  log_info "Building Formatter Docker Image (dotconfig-formatter:latest)..."
  if ! command -v docker >/dev/null 2>&1; then
    log_warn "Docker is not installed or not in PATH; skipping formatter build."
    return 1
  fi

  if [ "$DRY_RUN" = true ]; then
    log_dry "Build docker image: dotconfig-formatter:latest from ${REPO_DIR}/docker/formatter"
    return 0
  fi

  "${REPO_DIR}/docker/formatter/build.sh"
  log_ok "Formatter Docker Image built successfully."
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
    --dump-extensions)
      dump_antigravity_extensions
      exit 0
      ;;
    nvim|agents|ide|git|zsh|terminal|fonts|formatter|docker|packages|brew|all)
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
    nvim)             link_nvim ;;
    agents)           link_agents ;;
    ide)              link_ide ;;
    git)              link_git ;;
    zsh)              link_zsh ;;
    terminal)         link_terminal ;;
    fonts)            install_fonts ;;
    formatter|docker) build_formatter ;;
    packages|brew)    install_packages ;;
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
