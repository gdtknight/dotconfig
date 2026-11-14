# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:$HOME/.local/bin:/usr/local/bin:$PATH

# Path to your Oh My Zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Set name of the theme to load --- if set to "random", it will
# load a random theme each time Oh My Zsh is loaded, in which case,
# to know which specific one was loaded, run: echo $RANDOM_THEME
# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
ZSH_THEME="powerlevel10k/powerlevel10k"

# Set list of themes to pick from when loading at random
# Setting this variable when ZSH_THEME=random will cause zsh to load
# a theme from this variable instead of looking in $ZSH/themes/
# If set to an empty array, this variable will have no effect.
# ZSH_THEME_RANDOM_CANDIDATES=( "robbyrussell" "agnoster" )

# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Uncomment the following line to use hyphen-insensitive completion.
# Case-sensitive completion must be off. _ and - will be interchangeable.
# HYPHEN_INSENSITIVE="true"

# Uncomment one of the following lines to change the auto-update behavior
# zstyle ':omz:update' mode disabled  # disable automatic updates
# zstyle ':omz:update' mode auto      # update automatically without asking
# zstyle ':omz:update' mode reminder  # just remind me to update when it's time

# Uncomment the following line to change how often to auto-update (in days).
# zstyle ':omz:update' frequency 13

# Uncomment the following line if pasting URLs and other text is messed up.
# DISABLE_MAGIC_FUNCTIONS="true"

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
# ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
# You can also set it to another string to have that shown instead of the default red dots.
# e.g. COMPLETION_WAITING_DOTS="%F{yellow}waiting...%f"
# Caution: this setting can cause issues with multiline prompts in zsh < 5.7.1 (see #5765)
# COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# You can set one of the optional three formats:
# "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# or set a custom format using the strftime function format specifications,
# see 'man strftime' for details.
# HIST_STAMPS="mm/dd/yyyy"

# Would you like to use another custom folder than $ZSH/custom?
# ZSH_CUSTOM=/path/to/new-custom-folder

# Which plugins would you like to load?
# Standard plugins can be found in $ZSH/plugins/
# Custom plugins may be added to $ZSH_CUSTOM/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
plugins=(
  git
  zsh-syntax-highlighting
  zsh-autosuggestions
)

source $ZSH/oh-my-zsh.sh

# User configuration

# export MANPATH="/usr/local/man:$MANPATH"

# You may need to manually set your language environment
# export LANG=en_US.UTF-8

# Preferred editor for local and remote sessions
if [[ -n $SSH_CONNECTION ]]; then
  export EDITOR='vim'
  export VISUAL='vim'
else
  export EDITOR='nvim'
  export VISUAL='nvim'
fi

# Compilation flags
# export ARCHFLAGS="-arch $(uname -m)"

# Set personal aliases, overriding those provided by Oh My Zsh libs,
# plugins, and themes. Aliases can be placed here, though Oh My Zsh
# users are encouraged to define aliases within a top-level file in
# the $ZSH_CUSTOM folder, with .zsh extension. Examples:
# - $ZSH_CUSTOM/aliases.zsh
# - $ZSH_CUSTOM/macos.zsh
# For a full list of active aliases, run `alias`.
#
# Example aliases
# alias zshconfig="mate ~/.zshrc"
# alias ohmyzsh="mate ~/.oh-my-zsh"
source ~/powerlevel10k/powerlevel10k.zsh-theme

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

alias cd="z"
#alias ll="eza -alD --icons --blocksize && eza -alf --icons --show-symlinks"
alias ll="eza -al --sort type --icons always"
eval "$(zoxide init zsh)"
export PATH="$HOME/.local/bin:$PATH"

# android
export ANDROID_HOME=$HOME/Library/Android/sdk
export PATH=$PATH:$ANDROID_HOME/emulator
export PATH=$PATH:$ANDROID_HOME/tools
export PATH=$PATH:$ANDROID_HOME/tools/bin
export PATH=$PATH:$ANDROID_HOME/platform-tools

# Added by Antigravity IDE
export PATH="$HOME/.antigravity-ide/antigravity-ide/bin:$PATH"

# Local private environment variables and secrets (Never committed)
[[ -f ~/.zshrc.local ]] && source ~/.zshrc.local

# Dev Container Template Initializer 2.0 (Dual-Mode: Interactive Wizard & Scriptable Flags)
devcontainer-init() {
  local dotconfig_repo="${DOTCONFIG_REPO:-$HOME/dev/dotconfig}"
  local script_path="${dotconfig_repo}/devcontainers/scripts/init_devcontainer.py"

  if [ ! -f "$script_path" ]; then
    echo "Error: Devcontainer init script not found at: $script_path"
    return 1
  fi

  python3 "$script_path" "$@"
}

# Zsh auto-completion for devcontainer-init 2.0
_devcontainer_init_completion() {
  local dotconfig_repo="${DOTCONFIG_REPO:-$HOME/dev/dotconfig}"
  local template_dir="${dotconfig_repo}/devcontainers"
  local -a templates
  if [ -d "$template_dir" ]; then
    templates=("$template_dir"/*(N/:t))
    # 'scripts', 'modules', '.cache' 같은 관리용 디렉터리 제외
    templates=(${templates:#scripts})
    templates=(${templates:#modules})
    templates=(${templates:#.cache})
  fi

  _arguments -s \
    '1:template:->templates' \
    '(-v --version)'{-v,--version}'[SDK/언어 버전 지정 (예: 22, 3.12, 1.23)]:version:' \
    '(-p --pkg)'{-p,--pkg}'[패키지 매니저 지정 (pnpm, bun, yarn, uv, poetry)]:package_manager:(pnpm bun yarn npm uv poetry gradle maven cargo)' \
    '(-d --db)'{-d,--db}'[로컬 DB 사이드카 (쉼표 구분: postgres,redis,mysql,mongo)]:database:(postgres redis mysql mongo postgres,redis)' \
    '--port[호스트 노출 포트 (예: 3000,8080)]:ports:' \
    '--docker-socket[호스트 Docker 소켓 바인딩 (Docker-outside-of-Docker)]' \
    '--ai[컨테이너 내부 AI Agent CLI 사전 설치]' \
    '--no-install[컨테이너 기동 시 의존성 자동 설치 건너뛰기]' \
    '(-i --interactive)'{-i,--interactive}'[대화형 마법사 모드 실행]' \
    '(-y --yes)'{-y,--yes}'[확인 프롬프트 생략 (기본값으로 즉시 생성)]' \
    '*::args:->args' && return 0

  case "$state" in
    templates)
      _describe -t templates 'Dev Container Templates' templates
      ;;
  esac
}
compdef _devcontainer_init_completion devcontainer-init 2>/dev/null || true
