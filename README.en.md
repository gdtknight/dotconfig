<div align="center">

# Dotconfig

**Cross-Platform, Zero-Sudo Developer Environment & 3-Vendor AI Agent Harness**

[![Platform](https://img.shields.io/badge/Platform-macOS%20%7C%20Ubuntu%20(Rootless)-blue?style=flat-square)](./install.sh)
[![Shell](https://img.shields.io/badge/Shell-Bash%203.2%2B%20%7C%20Zsh-121011?style=flat-square&logo=gnu-bash)](./zsh/.zshrc)
[![Editor](https://img.shields.io/badge/Neovim-LazyVim%20v14%2B-57A143?style=flat-square&logo=neovim)](./nvim)
[![AI Harness](https://img.shields.io/badge/AI%20Agents-Claude%20%7C%20Gemini%20%7C%20Codex-8A2BE2?style=flat-square)](./agents)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow?style=flat-square)](./LICENSE)

[한국어](./README.md) | **English**

[Overview](#overview) · [Quick Start](#quick-start) · [Structure](#structure) · [Highlights](#highlights) · [GitHub Wiki](https://github.com/gdtknight/dotconfig/wiki)

</div>

---

## Overview

Declarative **Single Source of Truth (SSoT)** workspace for **macOS** and **Ubuntu/Linux (including rootless cluster hosts)**.
Unifies a 3-vendor AI Agent harness, ephemeral Docker formatting, and multi-account Git/SSH isolation under [`install.sh`](./install.sh).

* **Zero-Sudo Bootstrap**: Installs Homebrew on macOS and rootless Linuxbrew (`~/.linuxbrew`) on Ubuntu, relocating heavy storage into `~/goinfre` when present
* **Single Source of Truth**: Syncs shared rules, 13 subagents, shared skills, MCP servers, and lifecycle hooks from `agents/shared/` across Claude, Gemini/AGY, and Codex
* **Thin Host Tooling**: Runs multi-language code formatters inside ephemeral `docker run --rm` containers (`dotconfig-formatter`) without host toolchain clutter
* **Idempotent & Safe**: Supports `--dry-run` simulation and archives file collisions into `~/.dotconfig_backups/backup_YYYYMMDD_HHMMSS/`

---

## Quick Start

### 1. Web One-Line Bootstrap

Checks prerequisites, clones to `~/.dotconfig`, and links modules on a clean machine.

* Full automated setup (packages, fonts, symlinks, IDE extensions)

  ```bash
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/gdtknight/dotconfig/main/install.sh)"
  ```

* Preview actions without modifying files

  ```bash
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/gdtknight/dotconfig/main/install.sh)" -- --dry-run
  ```

* Install specific modules only (e.g., Neovim and Git)

  ```bash
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/gdtknight/dotconfig/main/install.sh)" -- nvim git
  ```

> Override the default clone path (`~/.dotconfig`) by setting `DOTCONFIG_DIR=~/custom/path` before execution.

### 2. Local Repository Execution

* `all` order: `packages` → `fonts` → `git` (base) → `zsh` → `tmux` → `terminal` → `nvim` → `ide` → `agents` → `git` (accounts)
* Pass `-f` / `--force` to replace non-symlink targets or re-prompt terminal selection, and `--terminal alacritty|wezterm|none` for non-interactive selection

* Preview all symlinks and actions

  ```bash
  ./install.sh --dry-run all
  ```

* Apply bottom-up full environment setup

  ```bash
  ./install.sh all
  ```

* Bootstrap Homebrew/Linuxbrew & sync Brewfile

  ```bash
  ./install.sh packages
  ```

* Install & register Nerd Fonts (D2Coding, ComicShannsMono) for macOS & Linux

  ```bash
  ./install.sh fonts
  ```

* Link global Git config & interactive multi-account setup

  ```bash
  ./install.sh git
  ```

* Link Zsh, Oh My Zsh, Powerlevel10k & plugins

  ```bash
  ./install.sh zsh
  ```

* Link `~/.tmux.conf`, install TPM & sync 9 Tmux plugins

  ```bash
  ./install.sh tmux
  ```

* Select & link terminal emulator (Alacritty [default] / WezTerm / skip; cleans unselected repo symlinks)

  ```bash
  ./install.sh terminal
  ```

* Link LazyVim v14+ configuration

  ```bash
  ./install.sh nvim
  ```

* Link IDE settings, sync extensions & patch Docker v29+ CLI

  ```bash
  ./install.sh ide
  ```

* Sync Claude, Gemini/AGY, Codex configs, subagents, skills, MCP & CLIs

  ```bash
  ./install.sh agents
  ```

* Build `dotconfig-formatter` Docker image

  ```bash
  ./install.sh formatter
  ```

* Export current Antigravity IDE extensions to `extensions.txt`

  ```bash
  ./install.sh --dump-extensions
  ```

---

## Structure

```text
dotconfig/
├── install.sh                    # Bash 3.2+ orchestrator & web bootstrapper
├── Brewfile                      # CLI tools & macOS-only Casks / fonts (OS.mac? guarded)
├── README.md / README.en.md      # Main summary docs (Korean / English)
├── CLAUDE.md / CLAUDE.ko.md      # Repository maintenance guidelines (AGENTS.md -> CLAUDE.md)
├── docs/                         # Local architecture guide mirrors
├── nvim/                         # LazyVim v14+, Obsidian auto-scan, devcontainer.nvim
├── zsh/                          # Zsh (.zshrc, .zprofile, .p10k.zsh)
├── git/                          # Global .gitconfig (histogram diff, SSH signing) & .gitignore
├── agents/                       # Claude, Gemini/AGY, Codex harness (agents/shared/ SSoT)
├── ide/                          # Antigravity IDE / VS Code (18 extensions) & IntelliJ IDEA
├── alacritty/                    # Alacritty config (default terminal selection)
├── wezterm/                      # WezTerm Lua configuration (wezterm.lua)
├── tmux/                         # Tmux config (TPM & 9 plugins)
└── docker/formatter/             # Multi-language ephemeral formatter image (Debian Bookworm Slim)
```

---

## Highlights

Detailed architecture diagrams, ADR records, and module internals live in the [GitHub Wiki](https://github.com/gdtknight/dotconfig/wiki).

| Area | Summary | Wiki Page |
| :--- | :--- | :--- |
| **3-Vendor AI Harness** | Payload-normalized `hook.py` guards, ephemeral Docker formatter, 13 subagents, shared skills & MCP sync | [AI-Agent-Harness](https://github.com/gdtknight/dotconfig/wiki/AI-Agent-Harness) |
| **Multi-Account Git & Terminal** | Directory-scoped `includeIf` Git/SSH keys, Step 1 fonts, standalone `tmux`, Alacritty/WezTerm choice + auto-cleanup | [Git-Multi-Account-and-Terminal](https://github.com/gdtknight/dotconfig/wiki/Git-Multi-Account-and-Terminal) |
| **Automated Fixes** | Docker v29+ `i.Action` patch, WhichKey AI chat guards, `~/goinfre` isolation, SSH `EDITOR`, Obsidian fallback | [Troubleshooting](https://github.com/gdtknight/dotconfig/wiki/Troubleshooting) |

---

## Documentation

| Document | Scope | Location |
| :--- | :--- | :--- |
| **Wiki Home** | Complete technical documentation index | [Wiki Home](https://github.com/gdtknight/dotconfig/wiki) |
| **Architecture Guide (English)** | C4 context, runtime flows, bottom-up order, symlink table, ADR-01 to ADR-05 | [Architecture-EN](https://github.com/gdtknight/dotconfig/wiki/Architecture-EN) |
| **아키텍처 가이드 (한국어)** | Korean architecture guide & ADR-01 to ADR-05 | [Architecture](https://github.com/gdtknight/dotconfig/wiki/Architecture) |
| **Branch Strategy & Release** | Protected `main`, Issue/PR -> `dev`, Release PR + README/Wiki sync | [Branch-Strategy-and-Release](https://github.com/gdtknight/dotconfig/wiki/Branch-Strategy-and-Release) |
| **Contributor Guidelines** | SSoT rules, cross-vendor sync & Git workflow | [CLAUDE.md](./CLAUDE.md) · [CLAUDE.ko.md](./CLAUDE.ko.md) |

---

## License

Released under the [MIT License](./LICENSE).
