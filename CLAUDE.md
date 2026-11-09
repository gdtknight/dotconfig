# Dotconfig Repository Agent Guidelines

이 저장소는 macOS 및 Linux 환경의 설정(Neovim, LLM 에이전트, IDE, 셸, 터미널 도구, 패키지)을 관리하는 중앙 설정 저장소입니다.

---

## 1. 핵심 작업 원칙

1. **단일 진실 공급원 (Single Source of Truth)**:
   - 시스템 대상 경로(`~/.config`, `~/.claude`, `~/.gemini`, `~/.codex`, `~/Library/...`)를 직접 수정하지 말고, 반드시 본 저장소(`dotconfig/`) 내의 파일을 수정한 후 반영합니다.
   - 모든 대상 파일은 `install.sh`를 통해 심볼릭 링크로 연결되어 있으므로, 저장소의 파일 수정 시 실시간으로 시스템에 반영됩니다.

2. **민감 정보 및 동적 상태 파일 격리**:
   - 인증 토큰(`oauth_creds.json`, `auth.json`, `token*`), 세션 히스토리(`history.jsonl`, `*.sqlite*`), 프로세스 락/소켓 파일은 절대 Git에 커밋하거나 저장소에 추가하지 않습니다.
   - 에이전트 설정 추가 시 순수 설정(`settings.json`, `config.json`, `rules/`, `agents/`, `skills/`)만 관리합니다.

---

## 2. 모듈별 관리 규칙

1. **LLM 에이전트 3사 동기화 (`agents/`)**:
   - 공통 지침 및 전문 에이전트는 `agents/shared/`(INSTRUCTIONS.md, rules/, agents/*.md)에 단일 소스로 관리합니다.
   - 새 에이전트나 스킬 추가 시 `agents/shared/agents/<name>.md` 및 `agents/codex/agents/<name>.toml`을 작성하면, `install.sh agents`가 Claude(`~/.claude`), Gemini(`~/.gemini/config/skills`), Codex(`~/.codex/skills`) 3개 플랫폼에 자동 동기화합니다.

2. **패키지 관리 (`Brewfile`)**:
   - macOS 전용 애플리케이션(GUI Cask) 및 폰트는 반드시 `if OS.mac?` 블록 내에 선언하여 Ubuntu/Linux(root 권한 없는 환경)에서도 CLI 도구가 에러 없이 설치되도록 보장합니다.

3. **IDE 및 확장 프로그램 (`ide/`)**:
   - Antigravity IDE 설정(`settings.json`), 키바인딩(`keybindings.json`), 확장 프로그램 목록(`extensions.txt`)을 선언적으로 관리합니다.
   - IDE에서 새로 설치한 확장은 `./install.sh --dump-extensions`를 통해 `extensions.txt`로 내보냅니다.

4. **셸 및 터미널 도구 (`zsh/`, `alacritty/`, `wezterm/`, `tmux/`)**:
   - Oh My Zsh, Powerlevel10k, Tmux 플러그인(TPM), Nerd Fonts(D2Coding, ComicShannsMono)는 `install.sh` 실행 시 자동 부트스트랩 및 CoreText 사용자 등록이 보장되어야 합니다.

---

## 3. 스크립트 및 매핑 무결성 유지

1. **install.sh & README.md 동시 업데이트**:
   - 새로운 설정 모듈, 파일, 패키지가 추가/제거되면 `install.sh`의 링크 함수와 `README.md`의 아키텍처 트리 및 매핑 테이블을 반드시 함께 최신화합니다.
2. **호환성 및 안전성 보장**:
   - `install.sh`는 macOS 기본 Bash(3.2+) 환경에서 추가 의존성 없이 실행 가능해야 하며, `--dry-run` 및 자동 백업(`~/.dotconfig_backups`) 동작을 항상 지원해야 합니다.

---

## 4. 변경 작업 및 검증 절차

1. **선(先) 검증 후(後) 적용**:
   - 파일 수정 후 반드시 `./install.sh --dry-run <module>`을 실행하여 문법 오류나 의도치 않은 파일 덮어쓰기가 없는지 확인합니다.
2. **동작 검증**:
   - 필요 시 `./install.sh <module>`을 실행하여 심볼릭 링크 정상 생성 및 CLI 연동을 직접 확인합니다.
3. **Git 커밋 규격 준수**:
   - 커밋 메시지는 Conventional Commits(`feat:`, `fix:`, `refactor:`, `chore:` 등) 및 Chris Beams 7원칙(영문 명령형, 50자 이하 제목)을 엄격히 준수합니다.
