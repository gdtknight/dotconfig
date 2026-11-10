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
├── agents/                     # LLM 에이전트 설정 (Claude, Gemini, Codex 통합 관리)
│   ├── shared/                 # 3사 에이전트 공통 원본 (INSTRUCTIONS.md, rules/, agents/*.md, hooks/)
│   ├── claude/                 # settings.json (Claude 전용 설정 및 훅 연동)
│   ├── gemini/                 # settings.json, config.json, hooks.json, mcp_config.json
│   └── codex/                  # config.toml, agents/*.toml (shared/agents 참조 래퍼)
├── ide/                        # IDE 설정 (macOS & Linux XDG 경로 자동 분기)
│   ├── antigravity-ide/        # settings.json, keybindings.json, extensions.txt
│   └── intellij/               # keymaps/macOS.xml, idea.vmoptions, idea.properties
├── alacritty/                  # Alacritty 터미널 설정 및 테마
├── wezterm/                    # WezTerm 설정 (wezterm.lua)
├── tmux/                       # tmux.conf
└── docker/                     # 컨테이너화 도구 정의
    └── formatter/              # Dockerfile, build.sh (단발성 코드 포매터 컨테이너)
```

### 매핑 상세 테이블

| 모듈                | 리포지토리 소스 (`dotconfig/`)                                                        | macOS 대상 경로 (`$HOME`)                                                            | Ubuntu/Linux 대상 경로 (`$HOME`)                                                                              | 링크 방식                                                                           |
| :------------------ | :------------------------------------------------------------------------------------ | :----------------------------------------------------------------------------------- | :------------------------------------------------------------------------------------------------------------ | :---------------------------------------------------------------------------------- |
| **Neovim**          | `nvim`                                                                                | `~/.config/nvim`                                                                     | `~/.config/nvim`                                                                                              | 디렉토리 심볼릭 링크                                                                |
| **Zsh**             | `zsh/.zshrc`<br>`zsh/.zprofile`<br>`zsh/.p10k.zsh`                                    | `~/.zshrc`<br>`~/.zprofile`<br>`~/.p10k.zsh`                                         | `~/.zshrc`<br>`~/.zprofile`<br>`~/.p10k.zsh`                                                                  | 파일 심볼릭 링크<br>_(oh-my-zsh, p10k, 플러그인 자동 보장)_                         |
| **Git**             | `git/.gitconfig`<br>`git/.gitignore`                                                  | `~/.gitconfig`<br>`~/.gitignore`                                                     | `~/.gitconfig`<br>`~/.gitignore`                                                                              | 파일 심볼릭 링크                                                                    |
| **Claude**          | `agents/shared/{INSTRUCTIONS.md,rules,agents,hooks}`<br>`agents/claude/settings.json` | `~/.claude/{CLAUDE.md,rules,agents,hooks}`<br>`~/.claude/settings.json`              | `~/.claude/{CLAUDE.md,rules,agents,hooks}`<br>`~/.claude/settings.json`                                       | 공통 마크다운/폴더 및 설정 링크<br>_(claude CLI 자동 설치 보장)_                    |
| **Gemini / AGY**    | `agents/shared/{INSTRUCTIONS.md,rules,agents,hooks}`<br>`agents/gemini/*`             | `~/.gemini/{GEMINI.md,agents}`<br>`~/.gemini/config/{rules,hooks,skills/*/SKILL.md}` | `~/.gemini/{GEMINI.md,agents}`<br>`~/.gemini/config/{rules,hooks,skills/*/SKILL.md}`                          | 공통 마크다운/스킬 및 설정 링크<br>_(agy CLI 자동 설치 보장)_                       |
| **Codex**           | `agents/shared/{INSTRUCTIONS.md,agents,hooks}`<br>`agents/codex/{config.toml,agents}` | `~/.codex/{AGENTS.md,config.toml,agents,hooks}`<br>`~/.codex/skills/*/SKILL.md`      | `~/.codex/{AGENTS.md,config.toml,agents,hooks}`<br>`~/.codex/skills/*/SKILL.md`                               | 공통 마크다운/스킬 및 TOML 링크<br>_(codex CLI 자동 설치 보장)_                     |
| **Antigravity IDE** | `ide/antigravity-ide/*`                                                               | `~/Library/Application Support/Antigravity IDE/User/*`                               | `~/.config/Antigravity IDE/User/*`                                                                            | 파일 심볼릭 링크<br>_(extensions.txt 기반 확장 자동 설치/동기화)_                   |
| **IntelliJ IDEA**   | `ide/intellij/*`                                                                      | `~/Library/Application Support/JetBrains/IntelliJIdea*/*`                            | `~/.config/JetBrains/IntelliJIdea*/*`                                                                         | 파일 심볼릭 링크                                                                    |
| **Terminal**        | `alacritty`<br>`wezterm/wezterm.lua`<br>`tmux/tmux.conf`                              | `~/.config/alacritty`<br>`~/.wezterm.lua`<br>`~/.tmux.conf`<br>`~/Library/Fonts`     | `~/.config/alacritty`<br>`~/.wezterm.lua` 및 `~/.config/wezterm/`<br>`~/.tmux.conf`<br>`~/.local/share/fonts` | 디렉토리 및 파일 링크<br>_(tpm 및 Nerd Fonts: D2Coding, ComicShannsMono 자동 보장)_ |

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
./install.sh zsh        # Zsh (.zshrc, .zprofile, .p10k.zsh), Oh My Zsh, p10k 및 플러그인 설정
./install.sh git        # Git 전역 설정(.gitconfig, .gitignore)만 연결
./install.sh agents     # Claude, Gemini, Codex 에이전트 설정만 연결
./install.sh ide        # Antigravity IDE, IntelliJ 설정 연결 및 확장 프로그램 동기화
./install.sh terminal   # Alacritty, WezTerm, Tmux 연결 및 Nerd Fonts 설치
./install.sh fonts      # Nerd Fonts (D2Coding, ComicShannsMono)만 단독 설치
./install.sh formatter  # 코드 포매터 Docker 이미지 빌드 (dotconfig-formatter:latest)

# Antigravity IDE 확장 프로그램 관리
./install.sh --dump-extensions  # 현재 IDE에 설치된 확장 목록을 extensions.txt로 내보내기

# 패키지 설치 (Brewfile 기반)
./install.sh packages   # (또는 ./install.sh brew)
```

---

## 3. 프로그램 패키지 관리 (`Brewfile`)

[`Brewfile`](./Brewfile)은 사용자가 직접 설치할 프로그램을 선언적으로 편집할 수 있는 파일입니다.

- **macOS 전용 애플리케이션 (GUI Cask)**은 `if OS.mac?` 블록으로 감싸져 있으므로, Linux 환경에서 실행해도 에러 없이 CLI 패키지만 정상 처리됩니다.
- 원하는 패키지를 `Brewfile`에 추가하거나 주석 처리하여 손쉽게 커스터마이징할 수 있습니다.

### 💡 Homebrew 자동 설치 (macOS & sudo 없는 Ubuntu 지원)

`./install.sh packages` (또는 `./install.sh all`) 실행 시 시스템에 Homebrew가 감지되지 않으면 OS에 맞춰 **자동으로 Homebrew를 먼저 설치**한 뒤 [`Brewfile`](./Brewfile) 패키지를 동기화합니다:

- **macOS**: 공식 Homebrew 설치 스크립트 실행 (`/opt/homebrew` 또는 `/usr/local`)
- **Ubuntu/Linux (sudo 권한 불필요)**: 사용자 홈 디렉터리(`~/.linuxbrew`)에 Homebrew를 자동 클론 및 심볼릭 링크 구성 (`zsh/.zprofile`에서 자동 PATH 로드)
- _(또한 `~/.local/bin` 경로가 셸 PATH에 기본 등록되어 있으므로, 직접 다운로드한 AppImage나 Standalone 바이너리를 `~/.local/bin`에 두고 바로 사용할 수도 있습니다.)_

---

## 4. 안전 백업 메커니즘

기존 사용자 파일/폴더가 감지되면 덮어쓰지 않고 타임스탬프 기반 백업 디렉토리로 자동 이동합니다:

```text
~/.dotconfig_backups/backup_YYYYMMDD_HHMMSS/
```

---

## 5. AI 에이전트 라이프사이클 훅 (`agents/shared/hooks/hook.py`)

Claude, Gemini, Codex 에이전트 공통으로 동작하는 보안 가드, 자동 포맷, 시스템 알림 훅을 제공합니다.

| 훅 이벤트                 | 동작 및 기능                                                                                                                                                                                                                         |
| :------------------------ | :----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **PreToolUse** (실행 전)  | **보안 가드**: `git push --force`, `git reset --hard`, `rm -rf /` 등 파괴적 명령 사전 차단<br>**시크릿 보호**: `.env`, 개인키, 인증 파일 직접 접근 차단 및 API 키(OpenAI, Google, GitHub, Slack 등) 누출 차단                        |
| **PostToolUse** (실행 후) | **자동 코드 포맷**: 파일 수정 완료 시 **단발성 Docker 컨테이너**(`dotconfig-formatter:latest`)를 통해 즉시 포맷 적용 (`prettier`, `ruff`, `google-java-format`, `clang-format`, `stylua`) _(Docker 미가동 시 로컬 도구로 자동 폴백)_ |
| **Stop** (세션 종료)      | **작업 완료 알림**: 긴 작업 완료 시 macOS 네이티브 알림(`display notification`) 및 Glass 사운드 재생                                                                                                                                 |
