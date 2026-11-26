#!/usr/bin/env python3
"""Initialize, lint, and log Obsidian + Excalidraw LLM Wiki repositories."""

from __future__ import annotations

import argparse
from datetime import date
import re
import sys
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
SKILL_DIR = SCRIPT_DIR.parent
TEMPLATES_DIR = SKILL_DIR / "templates"

sys.path.insert(0, str(SCRIPT_DIR))
import excalidraw_gen  # noqa: E402

VALID_LOG_OPS = ("init", "ingest", "query", "lint", "visualize", "update")
REQUIRED_FRONTMATTER = ("id", "type", "tags", "updated")
WIKILINK_RE = re.compile(r"(!?)\[\[([^\]|#]+)(?:#[^\]|]*)?(?:\|[^\]]*)?\]\]")


def _render_template(text: str, name: str, domain: str, today: str) -> str:
    return (
        text.replace("{{WIKI_NAME}}", name)
        .replace("{{DOMAIN}}", domain)
        .replace("{{DATE}}", today)
    )


def _write_if_needed(path: Path, content: str, force: bool) -> bool:
    if path.exists() and not force:
        return False
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")
    return True


def cmd_init(
    target_dir: str,
    name: str,
    domain: str,
    force: bool,
    include_templates: bool,
) -> int:
    root = Path(target_dir).expanduser().resolve()
    today = date.today().isoformat()

    for rel in (
        "raw/assets",
        "wiki/sources",
        "wiki/entities",
        "wiki/concepts",
        "wiki/syntheses",
        "wiki/visuals",
    ):
        (root / rel).mkdir(parents=True, exist_ok=True)

    if include_templates:
        (root / "templates").mkdir(parents=True, exist_ok=True)
        for tpl in sorted(TEMPLATES_DIR.glob("*.md")):
            if tpl.name in ("WIKI_SCHEMA.md", "index.md", "log.md", "overview.md"):
                continue
            _write_if_needed(root / "templates" / tpl.name, tpl.read_text("utf-8"), force)

    seed_map = {
        TEMPLATES_DIR / "WIKI_SCHEMA.md": root / "WIKI_SCHEMA.md",
        TEMPLATES_DIR / "index.md": root / "wiki/index.md",
        TEMPLATES_DIR / "log.md": root / "wiki/log.md",
        TEMPLATES_DIR / "overview.md": root / "wiki/overview.md",
    }
    created = 0
    for src, dst in seed_map.items():
        rendered = _render_template(src.read_text("utf-8"), name, domain, today)
        if _write_if_needed(dst, rendered, force):
            created += 1

    print(f"[OK] Initialized LLM Wiki at {root} ({created} core files written)")
    return 0


def cmd_log(wiki_root: str, op: str, title: str, note: str | None) -> int:
    root = Path(wiki_root).expanduser().resolve()
    log_path = root / "wiki" / "log.md"
    if not log_path.is_file():
        print(f"[ERROR] Missing wiki/log.md under {root}", file=sys.stderr)
        return 1

    today = date.today().isoformat()
    entry = f"\n## [{today}] {op} | {title}\n"
    if note:
        entry += f"- {note.strip()}\n"

    existing = log_path.read_text(encoding="utf-8")
    if existing and not existing.endswith("\n"):
        entry = "\n" + entry
    log_path.write_text(existing + entry, encoding="utf-8")
    print(f"[OK] Appended log entry to {log_path}")
    return 0


def _parse_frontmatter(raw: str) -> dict[str, str]:
    match = re.match(r"^---\s*\n(.*?)\n---\s*(?:\n|$)", raw, re.DOTALL)
    if not match:
        return {}
    keys: dict[str, str] = {}
    for line in match.group(1).splitlines():
        if not line or line[0].isspace() or line.lstrip().startswith("#"):
            continue
        if ":" in line:
            k, v = line.split(":", 1)
            keys[k.strip()] = v.strip()
    return keys


def _strip_ignored_blocks(raw: str, is_excalidraw_md: bool) -> str:
    # Remove YAML frontmatter, HTML comments, %%...%% blocks, and fenced code blocks
    text = re.sub(r"^---\s*\n.*?\n---\s*\n", "", raw, count=1, flags=re.DOTALL)
    text = re.sub(r"<!--.*?-->", "", text, flags=re.DOTALL)
    if is_excalidraw_md:
        text = re.sub(r"%%.*?%%", "", text, flags=re.DOTALL)
    text = re.sub(r"```.*?```", "", text, flags=re.DOTALL)
    text = re.sub(r"`[^`\n]+`", "", text)
    return text


def _build_resolver(root: Path, wiki_dir: Path) -> tuple[dict[str, Path], set[Path]]:
    lookup: dict[str, Path] = {}
    all_pages: set[Path] = set()

    for path in sorted(wiki_dir.rglob("*.md")):
        all_pages.add(path)
        rel = path.relative_to(wiki_dir).as_posix()
        rel_no_md = rel[:-3] if rel.endswith(".md") else rel
        base_no_md = path.stem

        candidates = [rel, rel_no_md, path.name, base_no_md]
        if rel.endswith(".excalidraw.md"):
            rel_exc = rel[:-3]
            base_exc = path.name[:-3]
            candidates.extend([rel_exc, base_exc])

        for key in candidates:
            lookup.setdefault(key.lower(), path)

    raw_dir = root / "raw"
    if raw_dir.is_dir():
        for asset in raw_dir.rglob("*"):
            if asset.is_file():
                rel_raw = asset.relative_to(root).as_posix()
                lookup.setdefault(rel_raw.lower(), asset)
                lookup.setdefault(asset.name.lower(), asset)

    return lookup, all_pages


def _resolve_target(target: str, lookup: dict[str, Path]) -> Path | None:
    clean = target.strip().lstrip("./")
    if not clean:
        return None
    if clean.lower().startswith("wiki/"):
        clean = clean[5:]
    return lookup.get(clean.lower())


def cmd_lint(wiki_root: str) -> int:
    root = Path(wiki_root).expanduser().resolve()
    wiki_dir = root / "wiki"
    if not wiki_dir.is_dir():
        print(f"[ERROR] Missing wiki/ directory under {root}", file=sys.stderr)
        return 1

    lookup, all_pages = _build_resolver(root, wiki_dir)
    index_path = wiki_dir / "index.md"
    log_path = wiki_dir / "log.md"
    overview_path = wiki_dir / "overview.md"

    errors: list[str] = []
    warnings: list[str] = []
    inbound: dict[Path, int] = {p: 0 for p in all_pages}
    index_targets: set[Path] = set()

    for page in sorted(all_pages):
        rel = page.relative_to(root).as_posix()
        raw = page.read_text(encoding="utf-8")
        is_excalidraw = page.name.lower().endswith(".excalidraw.md")

        if page not in (index_path, log_path):
            fm = _parse_frontmatter(raw)
            if not fm:
                errors.append(f"{rel}: Missing YAML frontmatter")
            else:
                missing = [k for k in REQUIRED_FRONTMATTER if k not in fm]
                if missing:
                    errors.append(
                        f"{rel}: Frontmatter missing required key(s): {', '.join(missing)}"
                    )

        if is_excalidraw:
            ok, exc_errs = excalidraw_gen.validate_file(str(page))
            if not ok:
                for err in exc_errs:
                    errors.append(f"{rel}: [Excalidraw] {err}")

        scan_text = _strip_ignored_blocks(raw, is_excalidraw)
        for _embed, target in WIKILINK_RE.findall(scan_text):
            resolved = _resolve_target(target, lookup)
            if resolved is None:
                errors.append(f"{rel}: Broken wikilink [[{target}]]")
                continue
            if resolved in inbound and resolved != page:
                if page == index_path:
                    index_targets.add(resolved)
                elif page != log_path:
                    inbound[resolved] += 1

    if not index_path.is_file():
        errors.append("wiki/index.md: Missing index catalog")
    if not log_path.is_file():
        errors.append("wiki/log.md: Missing chronological log")

    for page in sorted(all_pages):
        if page in (index_path, log_path):
            continue
        rel = page.relative_to(root).as_posix()
        if index_path.is_file() and page not in index_targets:
            warnings.append(f"{rel}: Not listed in wiki/index.md")
        if page != overview_path and inbound[page] == 0:
            warnings.append(f"{rel}: Orphan page (0 inbound links from content pages)")

    print(f"# Wiki Lint Report ({root})")
    print(f"- Pages scanned: {len(all_pages)}")
    print(f"- Errors: {len(errors)}")
    print(f"- Warnings: {len(warnings)}")

    if errors:
        print("\n## Errors")
        for err in errors:
            print(f"- [ERROR] {err}")
    if warnings:
        print("\n## Warnings")
        for warn in warnings:
            print(f"- [WARN] {warn}")
    if not errors and not warnings:
        print("\n[OK] All wiki links, frontmatter, index coverage, and Excalidraw schemas passed.")

    return 1 if errors else 0


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Initialize, lint, and log LLM Wiki repositories."
    )
    sub = parser.add_subparsers(dest="command", required=True)

    init_p = sub.add_parser("init", help="Initialize a new LLM Wiki / Obsidian vault")
    init_p.add_argument("target_dir", help="Target directory path")
    init_p.add_argument("--name", default="Knowledge Wiki", help="Wiki display name")
    init_p.add_argument("--domain", default="General Knowledge", help="Wiki domain")
    init_p.add_argument("--force", action="store_true", help="Overwrite existing core files")
    init_p.add_argument(
        "--no-templates",
        action="store_true",
        help="Skip copying templates/ into target_dir",
    )

    lint_p = sub.add_parser("lint", help="Lint wiki structure, links, and Excalidraw files")
    lint_p.add_argument("wiki_root", help="Wiki root directory containing wiki/")

    log_p = sub.add_parser("log", help="Append a dated entry to wiki/log.md")
    log_p.add_argument("wiki_root", help="Wiki root directory containing wiki/")
    log_p.add_argument("op", choices=VALID_LOG_OPS, help="Operation type")
    log_p.add_argument("title", help="Short entry title")
    log_p.add_argument("--note", help="Optional bullet note under the entry")

    args = parser.parse_args()

    if args.command == "init":
        return cmd_init(
            args.target_dir,
            args.name,
            args.domain,
            args.force,
            not args.no_templates,
        )
    if args.command == "lint":
        return cmd_lint(args.wiki_root)
    return cmd_log(args.wiki_root, args.op, args.title, args.note)


if __name__ == "__main__":
    sys.exit(main())
