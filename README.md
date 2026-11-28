<div align="center">

# Dotconfig

**macOS · Ubuntu (Rootless) 크로스 플랫폼 개발 환경 & 3사 AI 에이전트 하네스**

[![Platform](https://img.shields.io/badge/Platform-macOS%20%7C%20Ubuntu%20(Rootless)-blue?style=flat-square)](./install.sh)
[![Shell](https://img.shields.io/badge/Shell-Bash%203.2%2B%20%7C%20Zsh-121011?style=flat-square&logo=gnu-bash)](./zsh/.zshrc)
[![Editor](https://img.shields.io/badge/Neovim-LazyVim%20v14%2B-57A143?style=flat-square&logo=neovim)](./nvim)
[![AI Harness](https://img.shields.io/badge/AI%20Agents-Claude%20%7C%20Gemini%20%7C%20Codex-8A2BE2?style=flat-square)](./agents)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow?style=flat-square)](./LICENSE)

**한국어** | [English](./README.en.md)

[개요](#개요) · [빠른 시작](#빠른-시작) · [저장소 구조](#저장소-구조) · [주요 구성](#주요-구성) · [GitHub Wiki](https://github.com/gdtknight/dotconfig/wiki)

</div>

---

## 개요

macOS와 `sudo` 없는 Ubuntu 클러스터·컨테이너 환경을 하나의 선언적 저장소로 통합 관리.
3사 AI 코딩 에이전트 하네스, 단발성 Docker 포매터, 멀티 계정 Git/SSH 격리를 [`install.sh`](./install.sh) 한 곳에서 제어.

* **무권한 크로스 플랫폼 부트스트랩**: macOS Homebrew, Linux `~/.linuxbrew` 자동 설치 및 `~/goinfre` 감지 시 홈 쿼터 격리
* **단일 진실 공급원 (SSoT)**: 전역 지침, 전문 서브에이전트 13종, 공용 스킬, MCP, 생명주기 훅을 `agents/shared/`에서 일괄 동기화
* **호스트 최소화**: 다국어 자동 포매팅을 단발성 Docker 컨테이너(`dotconfig-formatter`)에서 실행해 호스트 의존성 최소화
* **멱등성 및 안전 백업**: `--dry-run` 시뮬레이션 지원, 충돌 시 덮어쓰지 않고 `~/.dotconfig_backups/backup_YYYYMMDD_HHMMSS/` 백업

---

## 빠른 시작

### 1. 원격 웹 부트스트랩

사전 도구 확인, 저장소 클론(`~/.dotconfig`), 전체 모듈 링크를 한 번에 실행.

* 전체 환경 자동 구성 (패키지, 폰트, 심볼릭 링크, IDE 확장 동기화)

  ```bash
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/gdtknight/dotconfig/main/install.sh)"
  ```

* 파일 변경 없이 실행 계획만 미리 확인

  ```bash
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/gdtknight/dotconfig/main/install.sh)" -- --dry-run
  ```

* 원하는 모듈만 선택 설치 (예: Neovim, Git)

  ```bash
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/gdtknight/dotconfig/main/install.sh)" -- nvim git
  ```

> 기본 클론 경로(`~/.dotconfig`) 변경 시 실행 전 `DOTCONFIG_DIR=~/custom/path` 지정.

### 2. 로컬 실행 및 모듈별 적용

* `all` 실행 순서: `packages` → `fonts` → `git(기본)` → `zsh` → `tmux` → `terminal` → `nvim` → `ide` → `agents` → `git(계정 마법사)`
* 기존 일반 파일 강제 백업·교체 또는 터미널 재선택 시 `-f` / `--force`, 비대화형 터미널 지정 시 `--terminal alacritty|wezterm|none` 옵션 사용

* 전체 변경 예정 내역 시뮬레이션

  ```bash
  ./install.sh --dry-run all
  ```

* 전체 모듈 계층 순서 설치

  ```bash
  ./install.sh all
  ```

* Homebrew / Rootless Linuxbrew 부트스트랩 및 Brewfile 동기화

  ```bash
  ./install.sh packages
  ```

* Nerd Fonts (D2Coding, ComicShannsMono) 설치 및 CoreText / `fc-cache` 등록

  ```bash
  ./install.sh fonts
  ```

* 전역 Git 설정 및 대화형 멀티 계정 SSH/서명 설정

  ```bash
  ./install.sh git
  ```

* Zsh, Oh My Zsh, Powerlevel10k 및 플러그인 구성

  ```bash
  ./install.sh zsh
  ```

* Tmux (`~/.tmux.conf`), TPM 및 Tmux 플러그인 9종 동기화

  ```bash
  ./install.sh tmux
  ```

* 터미널 선택 설치 및 링크 (Alacritty 기본 / WezTerm / 건너뛰기, 미선택 링크 자동 정리)

  ```bash
  ./install.sh terminal
  ```

* Neovim (LazyVim v14+) 설정 연결

  ```bash
  ./install.sh nvim
  ```

* IDE 설정·확장(18종) 동기화 및 Docker v29+ CLI 패치

  ```bash
  ./install.sh ide
  ```

* Claude, Gemini/AGY, Codex 규칙·서브에이전트·스킬·MCP·훅·CLI 동기화

  ```bash
  ./install.sh agents
  ```

* `dotconfig-formatter:latest` Docker 이미지 빌드

  ```bash
  ./install.sh formatter
  ```

* 현재 IDE 확장 목록을 `ide/antigravity-ide/extensions.txt`로 내보내기

  ```bash
  ./install.sh --dump-extensions
  ```

---

## 저장소 구조

```text
dotconfig/
├── install.sh                    # Bash 3.2+ 통합 오케스트레이터 & 웹 부트스트래퍼
├── Brewfile                      # CLI 도구 및 macOS 전용 Cask / 폰트 (if OS.mac? 분기)
├── README.md / README.en.md      # 저장소 요약 문서 (한국어 / English)
├── CLAUDE.md / CLAUDE.ko.md      # 저장소 작업 규칙 (AGENTS.md -> CLAUDE.md)
├── docs/                         # 저장소 내 아키텍처 원본 문서
├── nvim/                         # LazyVim v14+, Obsidian 동적 스캔, devcontainer.nvim
├── zsh/                          # Zsh (.zshrc, .zprofile, .p10k.zsh)
├── git/                          # 전역 .gitconfig (histogram diff, SSH 서명) & .gitignore
├── agents/                       # Claude, Gemini/AGY, Codex 통합 하네스 (agents/shared/ SSoT)
├── ide/                          # Antigravity IDE / VS Code (18종 확장) & IntelliJ IDEA
├── alacritty/                    # Alacritty 설정 (터미널 기본 선택 대상)
├── wezterm/                      # WezTerm Lua 설정 (wezterm.lua)
├── tmux/                         # Tmux 설정 (TPM & 플러그인 9종)
└── docker/formatter/             # 다국어 단발성 포매터 Docker 이미지 (Debian Bookworm Slim)
```

---

## 주요 구성

상세 설계, 아키텍처 다이어그램, 트러블슈팅 세부 내역은 [GitHub Wiki](https://github.com/gdtknight/dotconfig/wiki)에서 관리.

| 영역 | 핵심 동작 요약 | 상세 Wiki |
| :--- | :--- | :--- |
| **AI 3사 하네스 & 훅** | `hook.py` 3사 페이로드 정규화, 파괴적 명령·시크릿 차단, 단발성 Docker 포매터, 서브에이전트 13종·스킬·MCP 동기화 | [AI-Agent-Harness](https://github.com/gdtknight/dotconfig/wiki/AI-Agent-Harness) |
| **멀티 계정 Git · 터미널 · Tmux** | `~/Projects/<account>/` 기준 SSH·서명 격리, 1단계 공용 폰트, `tmux` 독립 모듈, Alacritty/WezTerm 택 1 및 미선택 링크 정리 | [Git-Multi-Account-and-Terminal](https://github.com/gdtknight/dotconfig/wiki/Git-Multi-Account-and-Terminal) |
| **실전 트러블슈팅 자동 보정** | Docker v29+ `i.Action` 패치, WhichKey 채팅 가드, `~/goinfre` 쿼터 격리, SSH `EDITOR`, Obsidian `no-vault` 폴백 | [Troubleshooting](https://github.com/gdtknight/dotconfig/wiki/Troubleshooting) |

---

## 상세 문서

| 문서 | 설명 | 위치 |
| :--- | :--- | :--- |
| **Wiki 홈** | 전체 기술 문서 인덱스 | [Wiki Home](https://github.com/gdtknight/dotconfig/wiki) |
| **아키텍처 가이드 (한국어)** | C4 계층도, 런타임 시퀀스, 계층형 설치 순서, 심볼릭 링크 매핑, ADR-01~05 | [Architecture](https://github.com/gdtknight/dotconfig/wiki/Architecture) |
| **Architecture Guide (English)** | C4 context, runtime flows, symlink mapping, ADR-01 to ADR-05 | [Architecture-EN](https://github.com/gdtknight/dotconfig/wiki/Architecture-EN) |
| **브랜치 전략 및 릴리스** | `main` 보호, Issue/PR → `dev` 통합, Release PR + README/Wiki 동기화 | [Branch-Strategy-and-Release](https://github.com/gdtknight/dotconfig/wiki/Branch-Strategy-and-Release) |
| **저장소 유지보수 규칙** | SSoT, 3사 에이전트·문서 동기화, Git 워크플로우 규칙 | [CLAUDE.ko.md](./CLAUDE.ko.md) · [CLAUDE.md](./CLAUDE.md) |

---

## 라이선스

[MIT License](./LICENSE) 조건에 따라 배포.
