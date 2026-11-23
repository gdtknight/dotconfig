#!/usr/bin/env python3
"""Sync shared MCP definitions (agents/shared/mcp.json) across Claude, Gemini/AGY, and Codex."""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
import tempfile

MANAGED_BEGIN = "# BEGIN DOTCONFIG MANAGED MCP"
MANAGED_END = "# END DOTCONFIG MANAGED MCP"
BARE_TOML_KEY_RE = re.compile(r"^[A-Za-z0-9_-]+$")


def _toml_key(key: str) -> str:
    return key if BARE_TOML_KEY_RE.match(key) else json.dumps(key)


def _toml_value(value: object) -> str:
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, str):
        return json.dumps(value)
    if isinstance(value, list):
        return "[" + ", ".join(_toml_value(item) for item in value) + "]"
    raise ValueError(f"Unsupported TOML value type: {type(value).__name__}")


def _validate_str_dict(raw: object, field: str, server: str) -> dict[str, str]:
    if raw is None:
        return {}
    if not isinstance(raw, dict):
        raise ValueError(f"MCP server '{server}' field '{field}' must be an object")
    out: dict[str, str] = {}
    for k, v in raw.items():
        if not isinstance(k, str) or not isinstance(v, str):
            raise ValueError(
                f"MCP server '{server}' field '{field}' entries must be string:string"
            )
        out[k] = v
    return out


def validate_servers(payload: object) -> dict[str, dict]:
    """Validate canonical mcpServers payload and normalize transport fields."""
    if not isinstance(payload, dict) or not isinstance(payload.get("mcpServers"), dict):
        raise ValueError("Source JSON must contain a top-level 'mcpServers' object")

    normalized: dict[str, dict] = {}
    for name, cfg in payload["mcpServers"].items():
        if not isinstance(name, str) or not name.strip():
            raise ValueError("MCP server name must be a non-empty string")
        if not isinstance(cfg, dict):
            raise ValueError(f"MCP server '{name}' must be an object")

        disabled = cfg.get("disabled", False)
        if not isinstance(disabled, bool):
            raise ValueError(f"MCP server '{name}' field 'disabled' must be boolean")

        url = cfg.get("url")
        command = cfg.get("command")
        transport = cfg.get("type")

        if url is not None and command is not None:
            raise ValueError(f"MCP server '{name}' cannot set both 'url' and 'command'")
        if url is not None:
            if not isinstance(url, str) or not url.strip():
                raise ValueError(f"MCP server '{name}' field 'url' must be non-empty")
            transport = transport or "http"
            if transport not in ("http", "sse"):
                raise ValueError(
                    f"MCP server '{name}' has unsupported URL transport '{transport}'"
                )
            headers = _validate_str_dict(cfg.get("headers"), "headers", name)
            entry: dict = {"type": transport, "url": url, "disabled": disabled}
            if headers:
                entry["headers"] = headers
            normalized[name] = entry
        elif command is not None:
            if not isinstance(command, str) or not command.strip():
                raise ValueError(
                    f"MCP server '{name}' field 'command' must be non-empty"
                )
            args = cfg.get("args", [])
            if not isinstance(args, list) or not all(isinstance(a, str) for a in args):
                raise ValueError(
                    f"MCP server '{name}' field 'args' must be a list of strings"
                )
            transport = transport or "stdio"
            if transport != "stdio":
                raise ValueError(
                    f"MCP server '{name}' with 'command' must use 'stdio' transport"
                )
            env = _validate_str_dict(cfg.get("env"), "env", name)
            entry = {
                "type": "stdio",
                "command": command,
                "args": args,
                "disabled": disabled,
            }
            if env:
                entry["env"] = env
            normalized[name] = entry
        else:
            raise ValueError(
                f"MCP server '{name}' must define either 'url' or 'command'"
            )

    return normalized


def render_gemini_json(servers: dict[str, dict]) -> str:
    """Render ~/.gemini/config/mcp_config.json content."""
    mcp_servers: dict[str, dict] = {}
    for name, cfg in servers.items():
        if cfg["type"] in ("http", "sse"):
            entry: dict = {
                "disabled": cfg["disabled"],
                "serverUrl": cfg["url"],
            }
            if "headers" in cfg:
                entry["headers"] = cfg["headers"]
        else:
            entry = {
                "type": "stdio",
                "command": cfg["command"],
                "args": cfg["args"],
                "disabled": cfg["disabled"],
            }
            if "env" in cfg:
                entry["env"] = cfg["env"]
        mcp_servers[name] = entry

    return json.dumps({"mcpServers": mcp_servers}, indent=2) + "\n"


def render_codex_block(servers: dict[str, dict]) -> str:
    """Render managed [mcp_servers.*] TOML block for ~/.codex/config.toml."""
    lines = [
        MANAGED_BEGIN,
        "# Auto-generated from agents/shared/mcp.json by install.sh / sync_mcp.py",
    ]
    for name, cfg in servers.items():
        tbl = _toml_key(name)
        lines.append("")
        lines.append(f"[mcp_servers.{tbl}]")
        if cfg["type"] in ("http", "sse"):
            lines.append(f"url = {_toml_value(cfg['url'])}")
            if "headers" in cfg:
                pairs = ", ".join(
                    f"{_toml_key(k)} = {_toml_value(v)}"
                    for k, v in cfg["headers"].items()
                )
                lines.append(f"http_headers = {{ {pairs} }}")
        else:
            lines.append(f"command = {_toml_value(cfg['command'])}")
            if cfg["args"]:
                lines.append(f"args = {_toml_value(cfg['args'])}")
            if "env" in cfg:
                lines.append("")
                lines.append(f"[mcp_servers.{tbl}.env]")
                for k, v in cfg["env"].items():
                    lines.append(f"{_toml_key(k)} = {_toml_value(v)}")
        if cfg["disabled"]:
            lines.append("enabled = false")
    lines.append(MANAGED_END)
    return "\n".join(lines) + "\n"


def merge_codex_toml(existing_text: str, managed_block: str) -> str:
    """Insert or replace the managed MCP block in Codex config.toml."""
    pattern = re.compile(
        re.escape(MANAGED_BEGIN) + r".*?" + re.escape(MANAGED_END) + r"\n?",
        re.DOTALL,
    )
    if pattern.search(existing_text):
        return pattern.sub(managed_block, existing_text, count=1)
    base = existing_text.rstrip("\n")
    if not base:
        return managed_block
    return base + "\n\n" + managed_block


def render_claude_servers(servers: dict[str, dict]) -> dict[str, dict]:
    """Build Claude Code ~/.claude.json mcpServers entries for enabled servers."""
    rendered: dict[str, dict] = {}
    for name, cfg in servers.items():
        if cfg["disabled"]:
            continue
        if cfg["type"] in ("http", "sse"):
            entry: dict = {"type": cfg["type"], "url": cfg["url"]}
            if "headers" in cfg:
                entry["headers"] = cfg["headers"]
        else:
            entry = {
                "type": "stdio",
                "command": cfg["command"],
                "args": cfg["args"],
            }
            if "env" in cfg:
                entry["env"] = cfg["env"]
        rendered[name] = entry
    return rendered


def _atomic_write(path: str, content: str, default_mode: int = 0o644) -> None:
    parent = os.path.dirname(os.path.abspath(path))
    os.makedirs(parent, exist_ok=True)
    mode = os.stat(path).st_mode & 0o777 if os.path.exists(path) else default_mode
    fd, tmp_path = tempfile.mkstemp(prefix=".dotconfig-mcp-", dir=parent)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as fh:
            fh.write(content)
        os.chmod(tmp_path, mode)
        os.replace(tmp_path, path)
    except Exception:
        if os.path.exists(tmp_path):
            os.unlink(tmp_path)
        raise


def sync_text_target(path: str, new_content: str, dry_run: bool) -> None:
    current = ""
    if os.path.exists(path):
        with open(path, "r", encoding="utf-8") as fh:
            current = fh.read()
    if current == new_content:
        print(f"[OK] MCP target up to date: {path}")
        return
    if dry_run:
        print(f"[DRY-RUN] Update MCP target: {path}")
        return
    _atomic_write(path, new_content)
    print(f"[OK] Synced MCP target: {path}")


def sync_claude_config(path: str, servers: dict[str, dict], dry_run: bool) -> None:
    """Merge shared enabled servers into Claude Code's ~/.claude.json mcpServers."""
    desired = render_claude_servers(servers)
    existing: dict = {}
    if os.path.exists(path):
        try:
            with open(path, "r", encoding="utf-8") as fh:
                loaded = json.load(fh)
        except PermissionError:
            if dry_run:
                print(
                    f"[DRY-RUN] Cannot inspect {path} in sandbox; would merge {len(desired)} MCP server(s)"
                )
                return
            raise
        if not isinstance(loaded, dict):
            raise ValueError(f"Expected JSON object in {path}")
        existing = loaded

    current_mcp = existing.get("mcpServers")
    if current_mcp is None:
        current_mcp = {}
    elif not isinstance(current_mcp, dict):
        raise ValueError(f"Expected 'mcpServers' object in {path}")

    merged_mcp = dict(current_mcp)
    for name in list(merged_mcp.keys()):
        if name in servers and servers[name]["disabled"]:
            del merged_mcp[name]
    merged_mcp.update(desired)

    if merged_mcp == current_mcp and "mcpServers" in existing:
        print(f"[OK] MCP target up to date: {path}")
        return
    if dry_run:
        print(f"[DRY-RUN] Merge shared MCP servers into: {path}")
        return

    updated = dict(existing)
    updated["mcpServers"] = merged_mcp
    _atomic_write(path, json.dumps(updated, indent=2) + "\n", default_mode=0o600)
    print(f"[OK] Synced Claude MCP servers in: {path}")


def main() -> int:
    script_dir = os.path.dirname(os.path.abspath(__file__))
    repo_root = os.path.dirname(os.path.dirname(script_dir))

    parser = argparse.ArgumentParser(
        description="Sync agents/shared/mcp.json to Gemini/AGY, Codex, and Claude Code."
    )
    parser.add_argument(
        "--source",
        default=os.path.join(script_dir, "mcp.json"),
        help="Path to shared mcp.json",
    )
    parser.add_argument(
        "--gemini-out",
        default=os.path.join(repo_root, "agents", "gemini", "mcp_config.json"),
        help="Path to Gemini/AGY mcp_config.json",
    )
    parser.add_argument(
        "--codex-config",
        default=os.path.join(repo_root, "agents", "codex", "config.toml"),
        help="Path to Codex config.toml",
    )
    parser.add_argument(
        "--claude-config",
        default=os.path.expanduser("~/.claude.json"),
        help="Path to Claude Code ~/.claude.json",
    )
    parser.add_argument("--dry-run", action="store_true", help="Preview without writes")
    args = parser.parse_args()

    try:
        with open(args.source, "r", encoding="utf-8") as fh:
            raw_source = json.load(fh)
        servers = validate_servers(raw_source)

        gemini_text = render_gemini_json(servers)
        sync_text_target(args.gemini_out, gemini_text, args.dry_run)

        codex_existing = ""
        if os.path.exists(args.codex_config):
            with open(args.codex_config, "r", encoding="utf-8") as fh:
                codex_existing = fh.read()
        codex_text = merge_codex_toml(codex_existing, render_codex_block(servers))
        sync_text_target(args.codex_config, codex_text, args.dry_run)

        sync_claude_config(args.claude_config, servers, args.dry_run)
    except Exception as exc:
        print(f"[ERROR] MCP sync failed: {exc}", file=sys.stderr)
        return 1

    return 0


if __name__ == "__main__":
    sys.exit(main())
