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
├── devcontainers/              # 환경별 Dev Container 템플릿 (42 C/C++, Go, DB 풀스택, Python AI 등)
└── docker/                     # 컨테이너화 도구 정의
    └── formatter/              # Dockerfile, build.sh (단발성 코드 포매터 컨테이너)
```

### 매핑 상세 테이블

| 모듈                | 리포지토리 소스 (`dotconfig/`)                                                        | macOS 대상 경로 (`$HOME`)                                                            | Ubuntu/Linux 대상 경로 (`$HOME`)                                                                              | 링크 방식                                                                           |
| :------------------ | :------------------------------------------------------------------------------------ | :----------------------------------------------------------------------------------- | :------------------------------------------------------------------------------------------------------------ | :---------------------------------------------------------------------------------- |
| **Neovim**          | `nvim`                                                                                | `~/.config/nvim`                                                                     | `~/.config/nvim`                                                                                              | 디렉토리 심볼릭 링크                                                                |
| **Zsh**             | `zsh/.zshrc`<br>`zsh/.zprofile`<br>`zsh/.p10k.zsh`                                    | `~/.zshrc`<br>`~/.zprofile`<br>`~/.p10k.zsh`                                         | `~/.zshrc`<br>`~/.zprofile`<br>`~/.p10k.zsh`                                                                  | 파일 심볼릭 링크<br>_(oh-my-zsh, p10k, 플러그인 자동 보장)_                         |
| **Git**             | `git/.gitconfig`<br>`git/.gitignore`                                                  | `~/.gitconfig`<br>`~/.gitignore`<br>`~/Projects/<account>/`                          | `~/.gitconfig`<br>`~/.gitignore`<br>`~/Projects/<account>/`                                                   | 파일 심볼릭 링크<br>_(다중 계정 격리 워크플로우 & SSH 키/서명 자동화)_              |
| **Claude**          | `agents/shared/{INSTRUCTIONS.md,rules,agents,hooks}`<br>`agents/claude/settings.json` | `~/.claude/{CLAUDE.md,rules,agents,hooks}`<br>`~/.claude/settings.json`              | `~/.claude/{CLAUDE.md,rules,agents,hooks}`<br>`~/.claude/settings.json`                                       | 공통 마크다운/폴더 및 설정 링크<br>_(claude CLI 자동 설치 보장)_                    |
| **Gemini / AGY**    | `agents/shared/{INSTRUCTIONS.md,rules,agents,hooks}`<br>`agents/gemini/*`             | `~/.gemini/{GEMINI.md,agents}`<br>`~/.gemini/config/{rules,hooks,skills/*/SKILL.md}` | `~/.gemini/{GEMINI.md,agents}`<br>`~/.gemini/config/{rules,hooks,skills/*/SKILL.md}`                          | 공통 마크다운/스킬 및 설정 링크<br>_(agy CLI 자동 설치 보장)_                       |
| **Codex**           | `agents/shared/{INSTRUCTIONS.md,agents,hooks}`<br>`agents/codex/{config.toml,agents}` | `~/.codex/{AGENTS.md,config.toml,agents,hooks}`<br>`~/.codex/skills/*/SKILL.md`      | `~/.codex/{AGENTS.md,config.toml,agents,hooks}`<br>`~/.codex/skills/*/SKILL.md`                               | 공통 마크다운/스킬 및 TOML 링크<br>_(codex CLI 자동 설치 보장)_                     |
| **IDE (VS Code / Antigravity)** | `ide/antigravity-ide/*`                                                               | `~/Library/Application Support/Antigravity IDE/User/*`<br>_(VS Code: `~/Library/Application Support/Code/User/*`)_    | `~/.config/Code/User/*`<br>_(Antigravity: `~/.config/Antigravity IDE/User/*`, `~/goinfre/.vscode/extensions` 자동 격리)_ | 파일 심볼릭 링크<br>_(extensions.txt 기반 확장 자동 설치/동기화)_                   |
| **IntelliJ IDEA**   | `ide/intellij/*`                                                                      | `~/Library/Application Support/JetBrains/IntelliJIdea*/*`                            | `~/.config/JetBrains/IntelliJIdea*/*`                                                                         | 파일 심볼릭 링크                                                                    |
| **Terminal**        | `alacritty`<br>`wezterm/wezterm.lua`<br>`tmux/tmux.conf`                              | `~/.config/alacritty`<br>`~/.wezterm.lua`<br>`~/.tmux.conf`<br>`~/Library/Fonts`     | `~/.config/alacritty`<br>`~/.wezterm.lua` 및 `~/.config/wezterm/`<br>`~/.tmux.conf`<br>`~/.local/share/fonts` | 디렉토리 및 파일 링크<br>_(tpm 및 Nerd Fonts: D2Coding, ComicShannsMono 자동 보장)_ |

---

## 2. 사용법 (`install.sh`)

### ⚡ 웹 원라인 설치 (새 머신 / Fresh OS)

새 머신에서 터미널을 열고 다음 명령어 한 줄만 실행하면, 저장소 클론(`~/.dotconfig`), 선행 도구(Xcode CLI Tools, Homebrew) 설치, 그리고 전체 환경 설정 심볼릭 링크가 원클릭으로 완료됩니다:

```bash
# 전체 자동 설치 (Homebrew, 심볼릭 링크, 폰트, IDE 확장 등)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/gdtknight/dotconfig/main/install.sh)"

# 미리보기 (Dry-run)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/gdtknight/dotconfig/main/install.sh)" -- --dry-run

# 특정 모듈만 선택 설치 (예: Neovim, Git)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/gdtknight/dotconfig/main/install.sh)" -- nvim git
```

> **Tip**: 기본 설치 위치는 `~/.dotconfig`이며, 다른 경로를 원할 경우 `DOTCONFIG_DIR=~/my/path` 환경변수를 앞에 지정할 수 있습니다.

---

### 💻 로컬 저장소에서 실행

이미 저장소를 클론한 경우, 저장소 디렉터리 내에서 직접 실행할 수 있습니다. OS(macOS, Linux)를 자동으로 감지하며 **sudo 권한이 전혀 필요하지 않습니다.**

```bash
# 전체 설정 링크 미리보기 (실제 변경 없음)
./install.sh --dry-run all

# 전체 설정 실제 심볼릭 링크 연결
./install.sh all

# 특정 모듈만 선택 연결
./install.sh nvim       # Neovim만 연결
./install.sh zsh        # Zsh (.zshrc, .zprofile, .p10k.zsh), Oh My Zsh, p10k 및 플러그인 설정
./install.sh git        # Git 전역 설정 및 다중 계정(Projects/계정별 디렉터리, SSH 키, includeIf) 구성
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

---

## 6. 다중 Git 계정 워크플로우 (`~/Projects/`)

단일 호스트에서 복수의 GitHub 계정(예: 학교/회사 계정과 개인 계정)을 사용할 때, URL을 임의로 수정할 필요 없이 작업 경로에 따라 **이메일, 커밋 서명, SSH 인증 키**가 100% 자동 분기됩니다.

### 디렉터리 아키텍처

```text
~/Projects/
├── <account1>/      # 계정 1 작업 공간 (예: personal)
│   └── my-project/  # -> 일반 GitHub URL 그대로 clone 해도 계정 1 SSH 키/이메일 자동 적용
└── <account2>/      # 계정 2 작업 공간 (예: work)
    └── sub-project/ # -> 일반 GitHub URL 그대로 clone 해도 계정 2 SSH 키/이메일 자동 적용
```

- **설정 자동화**: `./install.sh git` (또는 `./install.sh all`) 실행 시 계정 정보가 없으면 대화형으로 계정 정보를 입력받아 `~/.config/dotconfig/git-accounts.env`에 안전하게 격리 저장합니다.
- **자동 분기 구성**: 계정별 ed25519 SSH 키(`~/.ssh/id_ed25519_<user>`), 프로젝트 디렉터리(`~/Projects/<user>`), `~/.gitconfig-<user>`, 그리고 `~/.gitconfig.local`의 `includeIf` 설정이 한 번에 자동 구성됩니다.
- **클립보드 지원 (방안 A)**: 실행 시 각 계정의 공개키가 클립보드(`pbcopy`)에 자동 복사되며, 터미널 안내 링크(`https://github.com/settings/ssh/new`)를 통해 GitHub에 손쉽게 붙여넣기만 하면 등록이 완료됩니다.
- **저장소 무결성**: 실제 개인 식별자(이름, 이메일, 계정명)는 로컬 `~/.config/dotconfig/git-accounts.env` 및 `~/.gitconfig.local`에만 보관되어 공개 Git 저장소에는 일체 커밋되지 않습니다.

---

## 7. Dev Container 템플릿 관리 (`devcontainers/`)

호스트 머신에 개발 툴체인을 직접 설치하지 않고 격리된 Docker 환경에서 개발할 수 있는 8가지 표준 템플릿을 제공합니다:

- `42-c-valgrind`: Ubuntu 24.04, Clang/GCC, GDB, Valgrind, Make, Norminette (42 C/C++ 과제 전용)
- `fullstack-db`: Node.js 20 앱 + PostgreSQL 16 + Redis 7 멀티 컨테이너 Compose 환경
- `go-backend`: Go 1.23, gopls, dlv, golangci-lint
- `python-ai`: Python 3.11, PyTorch, Jupyter, LangChain, Pandas
- `devops-cloud`: Terraform, kubectl, helm, aws-cli
- `rust`: Rust, Cargo, rust-analyzer
- `java`: OpenJDK 21, Gradle, Maven
- `node-ts`: Node.js 20, TypeScript
- `react-native`: React Native & Expo (Metro 8081 포트 포워딩, 하이브리드 iOS/Android)

### 사용법

새 프로젝트나 기존 프로젝트 디렉터리에서 명령어 한 줄로 템플릿을 생성합니다:

```bash
# 1. 원하는 디렉터리로 이동
cd ~/Projects/gdtknight/my-project

# 2. 템플릿 초기화 (Zsh 자동완성 지원: devcontainer-init <Tab>)
devcontainer-init 42-c-valgrind

# 3. Neovim 실행 후 단축키 조작
nvim .
# -> <Space>Ds : 컨테이너 백그라운드 시작 (Start)
# -> <Space>Da : 컨테이너 내부로 접속 (Attach)
# -> <Space>Dq : 작업 완료 후 컨테이너 중지 (Stop)
```
