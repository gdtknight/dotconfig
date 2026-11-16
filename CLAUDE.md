**English** | [한국어](./CLAUDE.ko.md)

# Dotconfig Repository Agent Guidelines

This repository is the central configuration repository managing macOS and Linux environments (Neovim, LLM coding agents, IDE, shells, terminal tools, Dev Containers, and packages).

---

## 1. Core Working Principles

1. **Single Source of Truth (SSoT)**:
   - Never edit target system paths directly (`~/.config`, `~/.claude`, `~/.gemini`, `~/.codex`, `~/Library/...`). Always modify files inside `dotconfig/` and apply them through the installer.
   - All target paths are connected via symbolic links managed by `install.sh`, so repository edits take effect immediately.

2. **Sensitive Data & Dynamic State Isolation**:
   - Never commit or track authentication tokens (`oauth_creds.json`, `auth.json`, `token*`), session histories (`history.jsonl`, `*.sqlite*`), or process locks/sockets in Git.
   - Manage only pure declarative configurations (`settings.json`, `config.json`, `rules/`, `agents/`, `skills/`, `hooks/`) inside the repository.

---

## 2. Module-Specific Rules

1. **Cross-Vendor LLM Agent Sync (`agents/`)**:
   - Maintain shared guidelines and specialized agents in `agents/shared/` (`INSTRUCTIONS.md`, `rules/`, `agents/*.md`) as the single source of truth. Do **not** split files inside `agents/shared/` into `.md`/`.ko.md` pairs, as `install.sh agents` links them directly into tool directories.
   - When adding a new agent or skill, provide both `agents/shared/agents/<name>.md` and `agents/codex/agents/<name>.toml` so `install.sh agents` synchronizes Claude (`~/.claude`), Gemini (`~/.gemini/config/skills`), and Codex (`~/.codex/skills`) automatically.

2. **Package Management (`Brewfile`)**:
   - Declare macOS-only applications (GUI Casks) and fonts strictly inside the `if OS.mac?` block so rootless Ubuntu/Linux installations run without errors.

3. **IDE & Extensions (`ide/`)**:
   - Manage Antigravity IDE (`settings.json`, `keybindings.json`) and extension lists (`extensions.txt`) declaratively.
   - After installing new extensions inside the IDE, export them to `extensions.txt` with `./install.sh --dump-extensions`.

4. **Shell & Terminal Tools (`zsh/`, `alacritty/`, `wezterm/`, `tmux/`)**:
   - Ensure Oh My Zsh, Powerlevel10k, Tmux plugins (TPM), and Nerd Fonts (D2Coding, ComicShannsMono, including macOS CoreText registration) bootstrap cleanly during `install.sh`.

---

## 3. Script & Documentation Integrity

1. **Synchronized Updates (`install.sh`, `README*.md`, `docs/`)**:
   - Whenever modules, files, templates, or packages are added or removed, keep `install.sh` link functions and the bilingual documentation (`README.md`, `README.en.md`, `docs/ARCHITECTURE.md`, `docs/ARCHITECTURE.ko.md`) aligned in the same change.
   - Preserve the `AGENTS.md -> CLAUDE.md` symlink.

2. **Compatibility & Safety Guarantees**:
   - `install.sh` must remain runnable on stock macOS Bash (3.2+) with zero extra dependencies and must preserve `--dry-run` simulation and automatic timestamped backups (`~/.dotconfig_backups`).

---

## 4. Verification & Git Workflow

1. **Verify Before Applying**:
   - After any modification, run `./install.sh --dry-run <module>` (or `./install.sh --dry-run all`) to check syntax and ensure no unintended file overwrites occur.
2. **Runtime Verification**:
   - Run `./install.sh <module>` when needed to verify symlink creation and CLI integration directly.
3. **Commit Standards**:
   - Strictly follow Conventional Commits (`feat:`, `fix:`, `refactor:`, `docs:`, `chore:`, etc.) and Chris Beams' 7 rules (imperative English mood, capitalized subject line <= 50 chars without trailing period).
