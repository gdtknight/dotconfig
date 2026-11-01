# Dotconfig

macOS 및 Ubuntu(루트/sudo 권한이 없는 환경 포함)에서 환경 설정을 단일 Git 리포지토리에서 관리하고, `install.sh` 스크립트를 통해 시스템 대상 경로에 안전한 심볼릭 링크와 패키지 설치 워크플로우를 제공합니다.

## 1. 아키텍처 및 심볼릭 링크 매핑

```text
dotconfig/
├── install.sh                  # 심볼릭 링크 자동 설치 및 패키지 관리 스크립트
├── Brewfile                    # 사용자가 직접 관리하는 패키지 설치 목록 (macOS & Linux)
├── README.md                   # 리포지토리 매뉴얼 및 매핑 테이블
├── CLAUDE.md / AGENTS.md       # 에이전트 작업 지침 및 스키마
├── nvim/                       # Neovim (LazyVim v14+, Obsidian.nvim, Snacks)
├── zsh/                        # Zsh 셸 및 프롬프트 (.zshrc, .zprofile, .p10k.zsh)
├── git/                        # Git 전역 설정 (.gitconfig, .gitignore)
├── agents/                     # LLM 에이전트 설정 (Claude, Gemini, Codex)
│   ├── claude/                 # CLAUDE.md, settings.json, rules/, agents/
│   ├── gemini/                 # settings.json, config.json, hooks.json, mcp_config.json
│   └── codex/                  # config.toml, AGENTS.md
├── ide/                        # IDE 설정 (macOS & Linux XDG 경로 자동 분기)
│   ├── antigravity-ide/        # settings.json, keybindings.json
│   └── intellij/               # keymaps/macOS.xml, idea.vmoptions, idea.properties
├── alacritty/                  # Alacritty 터미널 설정 및 테마
├── wezterm/                    # WezTerm 설정 (wezterm.lua)
└── tmux/                       # tmux.conf
```

### 매핑 상세 테이블

| 모듈 | 리포지토리 소스 (`dotconfig/`) | macOS 대상 경로 (`$HOME`) | Ubuntu/Linux 대상 경로 (`$HOME`) | 링크 방식 |
| :--- | :--- | :--- | :--- | :--- |
| **Neovim** | `nvim` | `~/.config/nvim` | `~/.config/nvim` | 디렉토리 심볼릭 링크 |
| **Zsh** | `zsh/.zshrc`<br>`zsh/.zprofile`<br>`zsh/.p10k.zsh` | `~/.zshrc`<br>`~/.zprofile`<br>`~/.p10k.zsh` | `~/.zshrc`<br>`~/.zprofile`<br>`~/.p10k.zsh` | 파일 심볼릭 링크<br>*(p10k/omz 플러그인 자동 보장)* |
| **Git** | `git/.gitconfig`<br>`git/.gitignore` | `~/.gitconfig`<br>`~/.gitignore` | `~/.gitconfig`<br>`~/.gitignore` | 파일 심볼릭 링크 |
| **Claude** | `agents/claude/*` | `~/.claude/*` | `~/.claude/*` | 선택적 파일 및 폴더 링크 |
| **Gemini** | `agents/gemini/*` | `~/.gemini/*` | `~/.gemini/*` | 파일 심볼릭 링크 |
| **Codex** | `agents/codex/*` | `~/.codex/*` | `~/.codex/*` | 파일 심볼릭 링크 |
| **Antigravity IDE** | `ide/antigravity-ide/*` | `~/Library/Application Support/Antigravity IDE/User/*` | `~/.config/Antigravity IDE/User/*` | 파일 심볼릭 링크 |
| **IntelliJ IDEA** | `ide/intellij/*` | `~/Library/Application Support/JetBrains/IntelliJIdea*/*` | `~/.config/JetBrains/IntelliJIdea*/*` | 파일 심볼릭 링크 |
| **Terminal** | `alacritty`<br>`wezterm/wezterm.lua`<br>`tmux/tmux.conf` | `~/.config/alacritty`<br>`~/.wezterm.lua`<br>`~/.tmux.conf` | `~/.config/alacritty`<br>`~/.wezterm.lua` 및 `~/.config/wezterm/`<br>`~/.tmux.conf` | 디렉토리 및 파일 링크 |

---

## 2. 사용법 (`install.sh`)

`install.sh`는 OS(macOS, Linux)를 자동으로 감지하며 **sudo 권한이 전혀 필요하지 않습니다.**

```bash
# 전체 설정 링크 미리보기 (실제 변경 없음)
./install.sh --dry-run all

# 전체 설정 실제 심볼릭 링크 연결
./install.sh all

# 특정 모듈만 선택 연결
./install.sh nvim       # Neovim만 연결
./install.sh zsh        # Zsh (.zshrc, .zprofile, .p10k.zsh) 및 플러그인 연결
./install.sh git        # Git 전역 설정(.gitconfig, .gitignore)만 연결
./install.sh agents     # Claude, Gemini, Codex 에이전트 설정만 연결
./install.sh ide        # Antigravity IDE, IntelliJ 설정만 연결
./install.sh terminal   # Alacritty, WezTerm, Tmux 연결

# 패키지 설치 (Brewfile 기반)
./install.sh packages   # (또는 ./install.sh brew)
```

---

## 3. 프로그램 패키지 관리 (`Brewfile`)

[`Brewfile`](./Brewfile)은 사용자가 직접 설치할 프로그램을 선언적으로 편집할 수 있는 파일입니다.

- **macOS 전용 애플리케이션 (GUI Cask)**은 `if OS.mac?` 블록으로 감싸져 있으므로, Linux 환경에서 실행해도 에러 없이 CLI 패키지만 정상 처리됩니다.
- 원하는 패키지를 `Brewfile`에 추가하거나 주석 처리하여 손쉽게 커스터마이징할 수 있습니다.

### 💡 Ubuntu 환경 (sudo 권한이 없는 경우)
Ubuntu 서버나 클러스터 등 sudo 권한이 없는 환경에서는 **사용자 홈 디렉토리(`~/.linuxbrew`)에 Homebrew를 설치**하여 패키지를 완벽히 관리할 수 있습니다:

```bash
# 1) sudo 없이 사용자 홈 디렉토리에 Homebrew 클론
git clone https://github.com/Homebrew/brew ~/.linuxbrew/Homebrew
mkdir -p ~/.linuxbrew/bin
ln -s ../Homebrew/bin/brew ~/.linuxbrew/bin

# 2) 셸 환경에 반영 (dotconfig/zsh/.zprofile에 이미 자동 감지 로직이 포함되어 있습니다)
eval "$($HOME/.linuxbrew/bin/brew shellenv)"

# 3) dotconfig 패키지 설치 실행
./install.sh packages
```
*(또한 `~/.local/bin` 경로가 셸 PATH에 기본 등록되어 있으므로, 직접 다운로드한 AppImage나 Standalone 바이너리를 `~/.local/bin`에 두고 바로 사용할 수도 있습니다.)*

---

## 4. 안전 백업 메커니즘
기존 사용자 파일/폴더가 감지되면 덮어쓰지 않고 타임스탬프 기반 백업 디렉토리로 자동 이동합니다:
```text
~/.dotconfig_backups/backup_YYYYMMDD_HHMMSS/
```
