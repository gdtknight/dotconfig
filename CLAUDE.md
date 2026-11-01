# Dotconfig Repository Agent Guidelines

이 저장소는 macOS 전반의 환경 설정(Neovim, LLM 에이전트, IDE, 터미널 도구)을 관리하는 중앙 설정 저장소입니다.

## 핵심 작업 원칙

1. **단일 진실 공급원 (Single Source of Truth)**:
   - 시스템 대상 경로(`~/.config`, `~/.claude`, `~/Library/...`)를 직접 수정하지 말고, 반드시 본 저장소(`dotconfig/`) 내의 파일을 수정한 후 반영합니다.
   - 모든 대상 파일은 `install.sh`를 통해 심볼릭 링크로 연결되어 있으므로, 본 저장소의 파일 수정 시 실시간으로 시스템에 반영됩니다.

2. **민감 정보 및 동적 상태 파일 격리**:
   - 인증 토큰(`oauth_creds.json`, `auth.json`), 세션 히스토리(`history.jsonl`, `*.sqlite*`), 프로세스 락/소켓 파일은 절대 Git에 커밋하거나 `dotconfig`에 추가하지 않습니다.
   - 에이전트 설정 추가 시 순수 설정(`settings.json`, `config.json`, `rules/`, `agents/`, `skills/`)만 관리합니다.

3. **스크립트 및 매핑 무결성 유지**:
   - 새로운 설정 모듈이나 파일이 추가되면 `install.sh`의 해당 모듈 링크 함수와 `README.md`의 매핑 테이블을 반드시 함께 업데이트합니다.
   - `install.sh`는 macOS 기본 Bash(3.2+) 환경에서 추가 의존성 없이 실행 가능해야 하며, `--dry-run` 및 자동 백업(`~/.dotconfig_backups`) 동작을 항상 지원해야 합니다.
