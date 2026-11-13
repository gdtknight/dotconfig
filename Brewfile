# ==============================================================================
# Brewfile - User-managed packages (macOS & Linux)
# ==============================================================================
# 사용자가 직접 설치할 대상을 편집할 수 있는 파일입니다.
# 불필요한 패키지는 주석(#) 처리하거나 삭제하고, 필요한 패키지를 추가하세요.

# ------------------------------------------------------------------------------
# 1. Essential Core CLI
# ------------------------------------------------------------------------------
brew "bash"
brew "git"
brew "neovim"
brew "tmux"
brew "zsh"

# ------------------------------------------------------------------------------
# 2. Modern CLI Productivity Tools
# ------------------------------------------------------------------------------
brew "eza"               # modern ls alternative
brew "zoxide"            # smarter cd command
brew "fzf"               # command-line fuzzy finder
brew "ripgrep"           # fast grep
brew "bat"               # cat with syntax highlighting
brew "lazygit"           # terminal UI for git
brew "gh"                # GitHub CLI

# ------------------------------------------------------------------------------
# 3. macOS-only Applications (Cask)
# (Ubuntu/Linux 환경에서는 자동으로 무시되므로 안전하게 동작합니다)
# ------------------------------------------------------------------------------
if OS.mac?
  brew "terminal-notifier" # command-line notification with app activation
  cask "google-chrome"
  cask "alfred"
  cask "rectangle"
  cask "orbstack"
  cask "wezterm"
  # cask "alacritty"
  # cask "ghostty"
  cask "font-d2coding-nerd-font"
  cask "font-comic-shanns-mono-nerd-font"
end
