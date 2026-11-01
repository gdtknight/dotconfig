# Dotconfig

macOS 환경 설정을 단일 Git 리포지토리에서 관리하고, `install.sh` 스크립트를 통해 시스템 대상 경로에 안전한 심볼릭 링크를 생성하는 워크플로우입니다.

## 1. 아키텍처 및 심볼릭 링크 매핑

```text
dotconfig/
├── install.sh                  # 심볼릭 링크 자동 설치 및 백업 관리 스크립트
├── README.md                   # 리포지토리 매뉴얼 및 매핑 테이블
├── CLAUDE.md / AGENTS.md       # 에이전트 작업 지침 및 스키마
├── nvim/                       # Neovim (LazyVim v14+, Obsidian.nvim, Snacks)
├── agents/                     # LLM 에이전트 설정 (Claude, Gemini, Codex)
│   ├── claude/                 # CLAUDE.md, settings.json, rules/, agents/
│   ├── gemini/                 # settings.json, config.json, hooks.json, mcp_config.json
│   └── codex/                  # config.toml, AGENTS.md
├── ide/                        # IDE 설정
│   ├── antigravity-ide/        # settings.json, keybindings.json
│   └── intellij/               # keymaps/macOS.xml, idea.vmoptions, idea.properties
├── alacritty/                  # Alacritty 터미널 설정 및 테마
├── tmux/                       # tmux.conf
└── karabiner/                  # Karabiner-Elements 키 매핑
```

### 매핑 상세 테이블

| 모듈 | 리포지토리 소스 (`dotconfig/`) | 시스템 대상 경로 (`$HOME`) | 링크 방식 |
| :--- | :--- | :--- | :--- |
| **Neovim** | `nvim` | `~/.config/nvim` | 디렉토리 심볼릭 링크 |
| **Claude** | `agents/claude/CLAUDE.md`<br>`agents/claude/settings.json`<br>`agents/claude/rules`<br>`agents/claude/agents` | `~/.claude/CLAUDE.md`<br>`~/.claude/settings.json`<br>`~/.claude/rules`<br>`~/.claude/agents` | 선택적 파일 및 폴더 링크<br>*(세션/캐시/인증 제외)* |
| **Gemini** | `agents/gemini/settings.json`<br>`agents/gemini/config.json`<br>`agents/gemini/hooks.json`<br>`agents/gemini/mcp_config.json` | `~/.gemini/settings.json`<br>`~/.gemini/config/config.json`<br>`~/.gemini/config/hooks.json`<br>`~/.gemini/config/mcp_config.json` | 파일 심볼릭 링크<br>*(토큰/DB 제외)* |
| **Codex** | `agents/codex/config.toml`<br>`agents/codex/AGENTS.md` | `~/.codex/config.toml`<br>`~/.codex/AGENTS.md` | 파일 심볼릭 링크<br>*(DB/로그 제외)* |
| **Antigravity IDE** | `ide/antigravity-ide/settings.json`<br>`ide/antigravity-ide/keybindings.json` | `~/Library/Application Support/Antigravity IDE/User/settings.json`<br>`~/Library/Application Support/Antigravity IDE/User/keybindings.json` | 파일 심볼릭 링크 |
| **IntelliJ IDEA** | `ide/intellij/keymaps/macOS.xml`<br>`ide/intellij/idea.vmoptions`<br>`ide/intellij/idea.properties` | `~/Library/Application Support/JetBrains/IntelliJIdea*/keymaps/macOS.xml`<br>`~/Library/Application Support/JetBrains/IntelliJIdea*/idea.vmoptions`<br>`~/Library/Application Support/JetBrains/IntelliJIdea*/idea.properties` | 파일 심볼릭 링크 |
| **Terminal** | `alacritty`<br>`tmux/tmux.conf`<br>`karabiner` | `~/.config/alacritty`<br>`~/.tmux.conf`<br>`~/.config/karabiner` | 디렉토리 및 파일 링크 |

---

## 2. 사용법 (`install.sh`)

`install.sh`는 멱등성(Idempotency)을 보장하며, 대상 경로에 이미 존재하는 실제 파일/폴더를 자동으로 백업한 뒤 심볼릭 링크를 연결합니다.

```bash
# 전체 설정 링크 미리보기 (실제 변경 없음)
./install.sh --dry-run all

# 전체 설정 실제 심볼릭 링크 연결
./install.sh all

# 특정 모듈만 선택 연결
./install.sh nvim       # Neovim만 연결
./install.sh agents     # Claude, Gemini, Codex 에이전트 설정만 연결
./install.sh ide        # Antigravity IDE, IntelliJ 설정만 연결
./install.sh terminal   # Alacritty, Tmux, Karabiner 연결
```

### 안전 백업 메커니즘
심볼릭 링크가 아닌 기존 사용자 파일이 감지되면, 덮어쓰지 않고 타임스탬프 기반 백업 디렉토리로 자동 이동합니다:
```text
~/.dotconfig_backups/backup_YYYYMMDD_HHMMSS/
```
원본 파일이 필요할 경우 위 백업 경로에서 언제든지 복원할 수 있습니다.
