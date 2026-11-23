[English](./CLAUDE.md) | **한국어**

# Dotconfig Repository Agent Guidelines

이 저장소는 macOS 및 Linux 환경의 설정(Neovim, LLM 에이전트, IDE, 셸, 터미널 도구, Dev Container, 패키지)을 관리하는 중앙 설정 저장소입니다.

---

## 1. 핵심 작업 원칙 (Core Working Principles)

1. **단일 진실 공급원 (Single Source of Truth, SSoT)**:
   - 시스템 대상 경로(`~/.config`, `~/.claude`, `~/.gemini`, `~/.codex`, `~/Library/...`)를 직접 수정하지 말고, 반드시 본 저장소(`dotconfig/`) 내의 파일을 수정한 후 반영합니다.
   - 모든 대상 파일은 `install.sh`를 통해 **심볼릭 링크 (Symlink)** 로 연결되어 있으므로, 저장소의 파일 수정 시 실시간으로 시스템에 반영됩니다.

2. **민감 정보 및 동적 상태 파일 격리 (Sensitive Data Isolation)**:
   - 인증 토큰(`oauth_creds.json`, `auth.json`, `token*`), 세션 히스토리(`history.jsonl`, `*.sqlite*`), 프로세스 락/소켓 파일은 절대 Git에 커밋하거나 저장소에 추가하지 않습니다.
   - 에이전트 설정 추가 시 순수 선언적 설정(`settings.json`, `config.json`, `rules/`, `agents/`, `skills/`, `hooks/`)만 관리합니다.

---

## 2. 모듈별 관리 규칙 (Module-Specific Rules)

1. **LLM 에이전트 3사 동기화 (`agents/`)**:
   - 공통 지침, 전문 에이전트, 공용 스킬, 공용 MCP 서버 정의는 `agents/shared/`(`INSTRUCTIONS.md`, `rules/`, `agents/*.md`, `skills/<name>/`, `mcp.json`)에 단일 소스로 관리합니다. `install.sh agents`가 직접 대상 도구 디렉터리로 링크하므로 `agents/shared/` 내부 프롬프트·스킬 파일은 영문/국문(`.ko.md`)으로 분리하지 않습니다.
   - 새 서브에이전트 추가 시 `agents/shared/agents/<name>.md`와 `agents/codex/agents/<name>.toml`을 함께 작성하고, `graphify`처럼 다중 파일로 구성된 스킬 디렉터리는 `agents/shared/skills/<name>/` 아래에 두면 `install.sh agents`가 Claude(`~/.claude/skills`), Gemini(`~/.gemini/config/skills`), Codex(`~/.codex/skills`) 3개 플랫폼에 자동 동기화합니다.
   - 3사 공용 MCP 서버를 추가·비활성화할 때는 시크릿 없는 순수 선언 정의만 `agents/shared/mcp.json`에 반영한 뒤 `./install.sh agents`를 실행해 `sync_mcp.py`로 `agents/gemini/mcp_config.json`, `agents/codex/config.toml`, `~/.claude.json`(`mcpServers`)에 일괄 동기화합니다.

2. **패키지 관리 (`Brewfile`)**:
   - macOS 전용 애플리케이션(GUI Cask) 및 폰트는 반드시 `if OS.mac?` 블록 내에 선언하여 Ubuntu/Linux(Rootless 권한 환경 포함)에서도 CLI 도구가 에러 없이 설치되도록 보장합니다.

3. **IDE 및 확장 프로그램 (`ide/`)**:
   - Antigravity IDE 설정(`settings.json`), 키바인딩(`keybindings.json`), 확장 프로그램 목록(`extensions.txt`)을 선언적으로 관리합니다.
   - IDE에서 새로 설치한 확장은 `./install.sh --dump-extensions`를 통해 `extensions.txt`로 내보냅니다.

4. **셸 및 터미널 도구 (`zsh/`, `alacritty/`, `wezterm/`, `tmux/`)**:
   - Oh My Zsh, Powerlevel10k, Tmux 플러그인(TPM), Nerd Fonts(D2Coding, ComicShannsMono)는 `install.sh` 실행 시 자동 **부트스트랩 (Bootstrap)** 및 macOS CoreText 사용자 등록이 보장되어야 합니다.

---

## 3. 스크립트 및 문서 무결성 유지 (Script & Documentation Integrity)

1. **스크립트 및 영문/국문 문서 동시 업데이트**:
   - 새로운 설정 모듈, 파일, 템플릿, 패키지가 추가/제거되면 `install.sh`의 링크 함수와 국문/영문 문서(`README.md`, `README.en.md`, `docs/ARCHITECTURE.md`, `docs/ARCHITECTURE.ko.md`)의 아키텍처 트리 및 매핑 테이블을 반드시 함께 최신화합니다.
   - `AGENTS.md -> CLAUDE.md` 심볼릭 링크를 항상 유지합니다.

2. **호환성 및 안전성 보장**:
   - `install.sh`는 macOS 기본 Bash(3.2+) 환경에서 추가 의존성 없이 실행 가능해야 하며, `--dry-run` **드라이런 (Dry-Run)** 시뮬레이션 및 자동 백업(`~/.dotconfig_backups`) 동작을 항상 지원해야 합니다.

---

## 4. 변경 작업 및 검증 절차 (Verification & Git Workflow)

1. **선(先) 검증 후(後) 적용**:
   - 파일 수정 후 반드시 `./install.sh --dry-run <module>` (또는 `./install.sh --dry-run all`)을 실행하여 문법 오류나 의도치 않은 파일 덮어쓰기가 없는지 확인합니다.
2. **동작 검증**:
   - 필요 시 `./install.sh <module>`을 실행하여 심볼릭 링크 정상 생성 및 CLI 연동을 직접 확인합니다.
3. **Git 커밋 규격 준수**:
   - 커밋 메시지는 **Conventional Commits**(`feat:`, `fix:`, `refactor:`, `docs:`, `chore:` 등) 및 **Chris Beams 7원칙**(영문 명령형, 50자 이하 제목, 마침표 생략)을 엄격히 준수합니다.
