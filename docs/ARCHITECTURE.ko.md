[English](./ARCHITECTURE.md) | **한국어**

# Dotconfig 아키텍처 가이드 (Architecture Guide)

이 문서는 `dotconfig`의 전체 시스템 구조, 핵심 런타임 워크플로우, 모듈별 내부 설계, 그리고 **아키텍처 결정 기록 (Architecture Decision Record, ADR)** 을 정리한 심화 기술 문서입니다.

---

## 1. 시스템 컨텍스트 및 컨테이너 아키텍처 (C4 Model)

`dotconfig`는 macOS 및 Ubuntu Linux(Rootless 클러스터 환경 포함) 워크스테이션을 위한 선언적 **단일 진실 공급원 (Single Source of Truth, SSoT)** 입니다. **멱등성 (Idempotency)** 을 보장하는 Bash 오케스트레이터가 저장소 리소스를 **심볼릭 링크 (Symlink)** 로 대상 경로에 투영하여 호스트 환경의 비추적 변이를 방지합니다.

```mermaid
flowchart TD
    Dev["Developer (macOS / Ubuntu)"]
    Repo["dotconfig Repository (Single Source of Truth)"]
    Inst["install.sh (Bash 3.2+ Orchestrator)"]
    Backup["Backup Store (~/.dotconfig_backups)"]

    Dev -->|"CLI / Web Installer 실행"| Inst
    Repo -->|"Symlink 원본 및 템플릿 제공"| Inst
    Inst -. "충돌 시 스냅샷 백업" .-> Backup

    Inst --> Nvim["Neovim (LazyVim) & 9개 플러그인"]
    Inst --> Zsh["Zsh (.zshrc, .p10k.zsh) & Tmux / WezTerm / Alacritty"]
    Inst --> Git["Multi-Account Git & Scoped SSH"]
    Inst --> Ide["Antigravity IDE / VS Code / IntelliJ (18개 확장)"]
    Inst --> Agents["AI Agents (Claude Code, Gemini CLI, Codex)"]
    Inst --> Pkg["Homebrew / Rootless Linuxbrew (~/.linuxbrew)"]
    Inst --> FmtDocker["Formatter Image (dotconfig-formatter:latest)"]

    Zsh -->|"devcontainer-init"| DevGen["Dev Container 2.0 Python Engine"]
    Agents -->|"PreToolUse / PostToolUse / Stop"| Hook["Unified Lifecycle Hook (hook.py)"]
    Hook -->|"docker run --rm (또는 Local Fallback)"| FmtDocker
```

---

## 2. 핵심 런타임 워크플로우 (Core Runtime Workflows)

### 2.1 멱등적 배포 및 무손실 백업 흐름 (Idempotent Deployment & Backup)

`install.sh`는 심볼릭 링크를 생성·갱신하기 전에 `--dry-run` 시뮬레이션을 지원하며, 기존 파일이 충돌할 경우 타임스탬프 기반 백업 디렉터리로 먼저 이동시킵니다.

```mermaid
sequenceDiagram
    actor User as 개발자 (User)
    participant CLI as install.sh
    participant FS as 대상 파일시스템 (Target FS)
    participant BK as 백업 저장소 (~/.dotconfig_backups)

    User->>CLI: ./install.sh [--dry-run] [--force] <module>
    CLI->>FS: 대상 경로(Target Path) 상태 검사
    alt 이미 저장소 원본을 가리키는 심볼릭 링크인 경우
        CLI-->>User: 건너뜀 (Idempotent No-Op)
    else 다른 파일/링크가 존재하는 경우
        CLI->>BK: backup_YYYYMMDD_HHMMSS/ 로 기존 파일 백업
        CLI->>FS: ln -sfn <repo_src> <target>
    else 대상 경로가 비어 있는 경우
        CLI->>FS: ln -sfn <repo_src> <target>
    end
```

### 2.2 통합 AI 에이전트 생명주기 훅 (Unified AI Agent Lifecycle Hook)

`agents/shared/hooks/hook.py`는 Claude Code, Gemini CLI / Antigravity, Codex 간 서로 다른 JSON 페이로드 스키마를 정규화하여 단일 보안 가드 및 자동 포매팅 파이프라인으로 처리합니다.

```mermaid
sequenceDiagram
    actor Agent as AI Agent (Claude / Gemini / Codex)
    participant Hook as hook.py
    participant Guard as Security Guard (PreToolUse)
    participant Docker as dotconfig-formatter:latest

    Agent->>Hook: stdin JSON (toolCall 또는 tool_name/tool_input)
    Hook->>Hook: extract_tool_info(payload) 페이로드 정규화

    alt Event == PreToolUse
        Hook->>Guard: DANGEROUS_COMMAND_PATTERNS, is_dangerous_rm(), is_dangerous_chmod() 검사
        Hook->>Guard: SENSITIVE_FILE_PATTERN 및 SECRET_PATTERNS 검사
        alt 보안 정책 위반
            Guard-->>Agent: Exit 1 + JSON decision "deny"
        else 안전한 작업
            Guard-->>Agent: Exit 0 + JSON decision "allow"
        end
    else Event == PostToolUse (파일 쓰기/수정 도구)
        Hook->>Docker: docker run --rm (홈/임시 경로 마운트) <formatter>
        alt Docker 데몬 비활성/미설치
            Hook->>Hook: 로컬 포매터 바이너리로 폴백 (Fallback)
        end
        Hook-->>Agent: Exit 0
    end
```

### 2.3 Dev Container 2.0 동적 생성 파이프라인 (Dev Container Generation)

`zsh/.zshrc`에 통합된 `devcontainer-init` 명령과 Zsh 탭 자동완성(`_devcontainer_init_completion`)을 통해 외부 Python 패키지 의존성 없이 템플릿, 실시간 런타임 버전, 선택적 DB **사이드카 (Sidecar)** 를 구성합니다.

```mermaid
flowchart LR
    Zsh["zsh: devcontainer-init"] --> Init["init_devcontainer.py"]
    Init --> Ver["version_fetcher.py"]
    Ver -->|"1.5s HTTP Timeout"| Api["공식 API (nodejs.org, endoflife.date, go.dev)"]
    Ver -. "캐시 읽기/쓰기" .-> Cache["~/.cache/dotconfig/devcontainer-versions.json"]
    Ver -. "오프라인 폴백" .-> Fallback["DEFAULT_FALLBACKS"]
    Init --> Db["db_templates.py (SUPPORTED_DATABASES)"]
    Db -->|"render_compose_yaml()"| Compose["docker-compose.yml (멀티 컨테이너 사이드카)"]
    Init --> Out[".devcontainer/ + 선택적 Neovim/AI/Docker Socket"]
```

---

## 3. 모듈별 내부 설계 (Module Breakdown)

### 3.1 통합 설치 오케스트레이터 및 패키지 관리 (`install.sh`, `Brewfile`)
- **Bash 3.2+ 호환성**: 연관 배열(Associative Array) 등 Bash 4+ 전용 문법을 배제하여 기본 macOS 환경에서도 `set -euo pipefail` 기반으로 즉시 실행됩니다.
- **웹 부트스트랩 (Web Bootstrap)**: 원격 1줄 실행 시 `DOTCONFIG_DIR`(기본 `~/.dotconfig`)로 `https://github.com/gdtknight/dotconfig.git`을 클론·갱신한 뒤 `all` 기본 실행(`packages`, `nvim`, `agents`, `ide`, `git`, `zsh`, `terminal` — `fonts` 포함) 또는 지정한 모듈(`fonts`, `formatter` 포함)을 실행합니다. (`formatter` 이미지 빌드는 필요 시 `./install.sh formatter`로 별도 실행)
- **루트리스(Rootless) 및 OS 분기**: `Brewfile`에서 macOS 전용 GUI Cask(`google-chrome`, `alfred`, `rectangle`, `orbstack`, `wezterm`), `terminal-notifier`, Nerd Fonts를 `if OS.mac?` 블록으로 격리하여 Ubuntu Rootless 환경(`~/.linuxbrew`)에서도 CLI 도구(`neovim`, `tmux`, `eza`, `zoxide`, `fzf`, `ripgrep`, `bat`, `lazygit`, `gh`)가 에러 없이 설치됩니다.

### 3.2 3사 AI 에이전트 동기화 및 보안 가드 (`agents/`)
- **통합 프롬프트/에이전트 트리**: `agents/shared/`에 전역 지침(`INSTRUCTIONS.md`), 세부 규칙(`rules/`), **12개 전문 에이전트**(`agents/shared/agents/*.md`)를 단일 관리하며 `agents/codex/agents/*.toml`과 짝을 이룹니다.
- **플랫폼 어댑터**: `install.sh agents`가 Claude(`~/.claude`), Gemini(`~/.gemini/config/skills`), Codex(`~/.codex/skills`) 경로에 심볼릭 링크를 구성하고 `agy`, `claude`, `codex` CLI 설치를 연계합니다.
- **생명주기 훅 (Lifecycle Hook, `hook.py`)**:
  - `PreToolUse` (`handle_pre_tool()`): 위험 Git/디스크 명령(`git push --force`, `git reset --hard`, `git clean -f`, `mkfs`, `dd`), 루트·홈·시스템 디렉터리 대상 `rm`(`is_dangerous_rm()`), 광범위 `chmod 777`(`is_dangerous_chmod()`), 시크릿 파일 및 API 키 노출(`SENSITIVE_FILE_PATTERN`, `SECRET_PATTERNS`)을 선별 차단합니다.
  - `PostToolUse` (`handle_post_tool()`): 수정된 파일 확장자(`.js`, `.ts`, `.py`, `.c`, `.cpp`, `.lua`, `.java` 등)에 따라 `prettier`, `ruff`, `clang-format`, `stylua`, `google-java-format`을 단발성 컨테이너(`dotconfig-formatter:latest`)에서 실행하며 Docker 미가용 시 로컬 바이너리로 폴백합니다.

### 3.3 IDE 용량 격리 및 호환성 패치 (`ide/`, `nvim/`)
- **Neovim (LazyVim)**: `nvim/`을 `~/.config/nvim`에 연결하며 `nvim/lua/plugins/` 아래 **9개 플러그인 설정**(`42format.lua`, `42header.lua`, `bufferline.lua`, `devcontainer.nvim.lua`, `emoji-picker.nvim.lua`, `markview.nvim.lua`, `obsidian.nvim.lua`, `tokyonight-nvim.lua`, `vim-tmux-navigator.lua`)을 관리합니다.
- **쿼터 제한 환경 격리 (`~/goinfre`)**: `link_ide`가 `~/goinfre` 존재 시 `.vscode/extensions`와 `.antigravity-ide/extensions`를 대용량 스크래치 영역으로 심볼릭 링크 격리합니다.
- **Antigravity IDE Dev Containers 패치**: `patch_antigravity_dev_containers` 함수가 컨테이너 상태 비교 구문(`"start"===(i.status||i.Status)`)에 `||i.Action` 체크를 보강하여 CLI 버전 간 호환성을 확보합니다.
- **선언적 확장 목록**: `ide/antigravity-ide/extensions.txt`에 **18개 확장 프로그램**을 관리하며 `./install.sh --dump-extensions`로 현재 IDE 상태를 역동기화합니다.

### 3.4 Dev Container 2.0 동적 엔진 (`devcontainers/`)
- **9개 스택 템플릿**: `42-c-valgrind`, `devops-cloud`, `fullstack-db`, `go-backend`, `java`, `node-ts`, `python-ai`, `react-native`, `rust`.
- **스마트 버전 수집 (`version_fetcher.py`)**: 공식 API(`nodejs.org/dist/index.json`, `endoflife.date/api/python.json`, `go.dev/dl/?mode=json`)를 엄격한 `1.5초` 타임아웃(`TIMEOUT_SECONDS = 1.5`)으로 조회하고 `~/.cache/dotconfig/devcontainer-versions.json`에 캐싱하며, 오프라인 시 `DEFAULT_FALLBACKS`로 즉시 폴백합니다.
- **Compose 자동 승격 (`db_templates.py`)**: `SUPPORTED_DATABASES`(`postgres`, `redis`, `mysql`, `mongo`) 중 하나 이상 선택 시 `render_compose_yaml()`이 단일 컨테이너 구성을 영속 볼륨이 포함된 멀티 컨테이너 `docker-compose.yml`로 자동 승격합니다.

### 3.5 셸, 폰트 및 멀티 계정 Git 격리 (`zsh/`, `alacritty/`, `wezterm/`, `tmux/`, `git/`)
- **결정론적 셸 초기화 (`zsh/.zshrc`)**: `typeset -U`로 `PATH`/`FPATH` 중복을 제거하고, Oh My Zsh 로딩 *이전*에 Homebrew `shellenv`를 초기화하며, SSH 세션에서도 설치된 `nvim`을 `EDITOR`로 우선 적용합니다. `__p9k_sourced` 가드와 `_dotconfig_repo_dir()` 동적 경로 해석도 함께 제공합니다.
- **멀티 계정 Git/SSH 격리**: `setup_git_accounts`가 `~/.config/dotconfig/git-accounts.env`, 계정별 `~/.gitconfig-<user>`, `~/.gitconfig.local`을 생성하고 `sshCommand` 스코프를 계정별로 엄격히 분리합니다.
- **터미널/폰트 자동화**: `install.sh terminal`에서 TPM 클론 및 Tmux 플러그인을 자동 설치하고, macOS에서는 D2Coding / ComicShannsMono Nerd Fonts를 CoreText 사용자 영역에 자동 등록합니다.

---

## 4. 아키텍처 결정 기록 (Architecture Decision Records, ADRs)

### ADR-01: GNU Stow / Chezmoi 대신 Bash 3.2+ 단일 오케스트레이터 채택
- **배경 (Context)**: 초기 macOS(기본 Bash 3.2, 패키지 매니저 미설치 상태)와 `sudo` 권한이 없는 Linux 클러스터 노드 모두에서 추가 바이너리 설치 없이 동작해야 합니다.
- **결정 (Decision)**: 외부 의존성 없는 순수 Bash 3.2+ 스크립트(`install.sh`)로 심볼릭 링크, 백업, 드라이런, 부트스트랩을 통합 구현합니다.
- **결과 (Consequences)**: 클린 머신에서 `curl | bash` 1줄만으로 Homebrew 설치 전 단계부터 즉시 부트스트랩이 가능하며, `--dry-run`과 `~/.dotconfig_backups` 백업 일관성을 유지할 수 있습니다.

### ADR-02: 3사 AI 에이전트 통합 단일 진실 공급원 + 훅 페이로드 정규화
- **배경 (Context)**: Claude Code, Gemini CLI, Codex CLI는 스킬 디렉터리 규약과 Pre/PostToolUse 훅 JSON 스키마(`toolCall` vs `tool_name` / `tool_input`)가 서로 다릅니다.
- **결정 (Decision)**: `agents/shared/`를 유일한 원본 소스로 두고 `install.sh agents`가 플랫폼별 링크를 구성하며, `hook.py`의 `extract_tool_info()`가 입력 페이로드를 단일 포맷으로 정규화합니다.
- **결과 (Consequences)**: 프롬프트·보안 정책·포매터 동작이 3사 플랫폼에서 중복 없이 동일하게 강제됩니다.

### ADR-03: PostToolUse 단발성 Docker 포매터 컨테이너 (`dotconfig-formatter:latest`)
- **배경 (Context)**: C/C++, Java, Lua, Python, JS/TS 포매터를 호스트에 직접 설치하면 언어별 런타임 버전 충돌과 환경 오염이 발생합니다.
- **결정 (Decision)**: `docker/formatter/Dockerfile`(`debian:bookworm-slim`)에 `clang-format`, `google-java-format` v1.24.0, `prettier`, `ruff`, `black`, `stylua`를 패키징하여 `docker run --rm`으로 격리 실행하고, Docker 미가용 시 로컬 폴백을 둡니다.
- **결과 (Consequences)**: OS와 무관하게 동일한 포매팅 결과를 얻으면서도 호스트 환경 의존성을 최소화합니다.

### ADR-04: 표준 라이브러리 기반 Dev Container 엔진 및 1.5초 타임아웃 캐싱
- **배경 (Context)**: `devcontainer-init`은 별도 가상환경(virtualenv) 활성화 없이 모든 프로젝트 디렉터리에서 즉시 실행되어야 하며 폐쇄망/저속 네트워크에서도 멈추지 않아야 합니다.
- **결정 (Decision)**: Python 표준 라이브러리(`urllib.request`, `json`)만으로 구현하고 `TIMEOUT_SECONDS = 1.5`, 로컬 JSON 캐시, 정적 `DEFAULT_FALLBACKS` 3단계 전략을 적용합니다.
- **결과 (Consequences)**: 온라인 환경에서는 최신 LTS 버전을 반영하고, 오프라인 환경에서도 대기 시간 없이 즉시 컨테이너 구성을 생성합니다.

### ADR-05: 쿼터 제한 환경 격리(`~/goinfre`) 및 Rootless Linuxbrew 지원
- **배경 (Context)**: 공용 클러스터 워크스테이션은 홈 디렉터리 디스크 쿼터가 작고 루트 권한을 허용하지 않습니다.
- **결정 (Decision)**: `link_ide`에서 `~/goinfre` 존재 시 IDE 확장 디렉터리를 자동 심볼릭 링크 격리하고, `Brewfile`의 macOS GUI 항목을 `if OS.mac?`로 감싸 `~/.linuxbrew`와 공존시킵니다.
- **결과 (Consequences)**: 개인 macOS 장비와 제한된 Ubuntu 클러스터에서 동일한 도구 체인을 유지할 수 있습니다.
