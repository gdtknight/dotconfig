#!/usr/bin/env python3
"""Generate and validate Obsidian Excalidraw (.excalidraw.md) diagrams from JSON specs."""

from __future__ import annotations

import argparse
from datetime import date
import json
import re
import sys
import unicodedata
import zlib
from pathlib import Path

KIND_STYLES: dict[str, dict[str, str]] = {
    "source": {"stroke": "#1971c2", "bg": "#d0ebff", "shape": "rectangle"},
    "concept": {"stroke": "#2f9e44", "bg": "#d3f9d8", "shape": "rectangle"},
    "entity": {"stroke": "#6741d9", "bg": "#e5dbff", "shape": "rectangle"},
    "synthesis": {"stroke": "#e8590c", "bg": "#ffe8cc", "shape": "rectangle"},
    "decision": {"stroke": "#c2255c", "bg": "#ffdeeb", "shape": "diamond"},
    "warning": {"stroke": "#c92a2a", "bg": "#ffe3e3", "shape": "rectangle"},
    "system": {"stroke": "#0c8599", "bg": "#c5f6fa", "shape": "rectangle"},
    "default": {"stroke": "#1e1e1e", "bg": "#f1f3f5", "shape": "rectangle"},
}


def _det_int(key: str, offset: int = 0) -> int:
    return (zlib.crc32(key.encode("utf-8")) + offset) & 0x7FFFFFFF


def _slugify(text: str) -> str:
    slug = re.sub(r"[^a-zA-Z0-9가-힣_-]+", "-", text.strip().lower()).strip("-")
    return slug or "diagram"


def _measure_text(text: str, font_size: int = 16) -> tuple[float, float]:
    lines = text.splitlines() or [""]
    max_units = 0.0
    for line in lines:
        units = sum(
            1.85 if unicodedata.east_asian_width(ch) in ("W", "F") else 1.0
            for ch in line
        )
        if units > max_units:
            max_units = units
    width = max(40.0, round(max_units * font_size * 0.58, 1))
    height = round(len(lines) * font_size * 1.25, 1)
    return width, height


def _normalize_link(raw_link: str) -> str:
    link = raw_link.strip()
    if not link:
        return ""
    if link.startswith(("http://", "https://", "obsidian://")):
        return link
    if link.startswith("[[") and link.endswith("]]"):
        return link
    return f"[[{link}]]"


def _base_element(
    elem_id: str,
    elem_type: str,
    x: float,
    y: float,
    width: float,
    height: float,
    stroke: str = "#1e1e1e",
    bg: str = "transparent",
    fill_style: str = "solid",
    stroke_style: str = "solid",
    opacity: int = 100,
) -> dict:
    return {
        "id": elem_id,
        "type": elem_type,
        "x": round(x, 1),
        "y": round(y, 1),
        "width": round(width, 1),
        "height": round(height, 1),
        "angle": 0,
        "strokeColor": stroke,
        "backgroundColor": bg,
        "fillStyle": fill_style,
        "strokeWidth": 2,
        "strokeStyle": stroke_style,
        "roughness": 1,
        "opacity": opacity,
        "groupIds": [],
        "frameId": None,
        "roundness": {"type": 3} if elem_type == "rectangle" else None,
        "seed": _det_int(elem_id, 1),
        "version": 1,
        "versionNonce": _det_int(elem_id, 2),
        "isDeleted": False,
        "boundElements": [],
        "updated": 1,
        "link": None,
        "locked": False,
    }


def _assign_layers(nodes: list[dict], edges: list[dict]) -> dict[str, int]:
    node_ids = [n["id"] for n in nodes]
    id_set = set(node_ids)
    preds: dict[str, list[str]] = {nid: [] for nid in node_ids}
    succs: dict[str, list[str]] = {nid: [] for nid in node_ids}

    for edge in edges:
        src = edge.get("from", "")
        dst = edge.get("to", "")
        if src in id_set and dst in id_set and src != dst:
            succs[src].append(dst)
            preds[dst].append(src)

    ranks: dict[str, int] = {nid: 0 for nid in node_ids}
    roots = [nid for nid in node_ids if not preds[nid]]
    queue = list(roots)
    max_rank = max(0, len(node_ids) - 1)
    iterations = 0
    max_iters = max(1, len(node_ids) * (len(edges) + 1))

    while queue and iterations < max_iters:
        cur = queue.pop(0)
        iterations += 1
        next_rank = min(max_rank, ranks[cur] + 1)
        for nxt in succs[cur]:
            if next_rank > ranks[nxt]:
                ranks[nxt] = next_rank
                queue.append(nxt)

    return ranks


def _compute_node_boxes(nodes: list[dict], edges: list[dict], direction: str) -> dict[str, dict]:
    boxes: dict[str, dict] = {}
    for node in nodes:
        nid = node["id"]
        label = node.get("label", nid)
        kind = node.get("kind", "default")
        style = KIND_STYLES.get(kind, KIND_STYLES["default"])
        shape = node.get("shape") or style["shape"]

        tw, th = _measure_text(label, font_size=16)
        w = float(node.get("width") or max(160.0, tw + 28.0))
        h = float(node.get("height") or max(64.0, th + 20.0))
        if shape == "diamond" and not (node.get("width") and node.get("height")):
            w = round(w * 1.35, 1)
            h = round(h * 1.35, 1)

        boxes[nid] = {
            "node": node,
            "label": label,
            "shape": shape,
            "stroke": style["stroke"],
            "bg": style["bg"],
            "w": w,
            "h": h,
            "tw": tw,
            "th": th,
            "x": node.get("x"),
            "y": node.get("y"),
        }

    if any(b["x"] is None or b["y"] is None for b in boxes.values()):
        ranks = _assign_layers(nodes, edges)
        layers: dict[int, list[str]] = {}
        for node in nodes:
            r = ranks[node["id"]]
            layers.setdefault(r, []).append(node["id"])

        gap_major = 110.0
        gap_minor = 52.0
        margin_x = 80.0
        margin_y = 80.0

        if direction == "TB":
            layer_heights = {
                r: max(boxes[nid]["h"] for nid in nids) for r, nids in layers.items()
            }
            layer_widths = {
                r: sum(boxes[nid]["w"] for nid in nids) + gap_minor * max(0, len(nids) - 1)
                for r, nids in layers.items()
            }
            max_row_w = max(layer_widths.values()) if layer_widths else 0.0
            cur_y = margin_y
            for r in sorted(layers):
                nids = layers[r]
                cur_x = margin_x + (max_row_w - layer_widths[r]) / 2.0
                for nid in nids:
                    b = boxes[nid]
                    if b["x"] is None:
                        b["x"] = cur_x
                    if b["y"] is None:
                        b["y"] = cur_y + (layer_heights[r] - b["h"]) / 2.0
                    cur_x += b["w"] + gap_minor
                cur_y += layer_heights[r] + gap_major
        else:
            layer_widths = {
                r: max(boxes[nid]["w"] for nid in nids) for r, nids in layers.items()
            }
            layer_heights = {
                r: sum(boxes[nid]["h"] for nid in nids) + gap_minor * max(0, len(nids) - 1)
                for r, nids in layers.items()
            }
            max_col_h = max(layer_heights.values()) if layer_heights else 0.0
            cur_x = margin_x
            for r in sorted(layers):
                nids = layers[r]
                cur_y = margin_y + (max_col_h - layer_heights[r]) / 2.0
                for nid in nids:
                    b = boxes[nid]
                    if b["x"] is None:
                        b["x"] = cur_x + (layer_widths[r] - b["w"]) / 2.0
                    if b["y"] is None:
                        b["y"] = cur_y
                    cur_y += b["h"] + gap_minor
                cur_x += layer_widths[r] + gap_major

    return boxes


def _edge_anchors(src: dict, dst: dict, direction: str) -> tuple[float, float, float, float]:
    scx = src["x"] + src["w"] / 2.0
    scy = src["y"] + src["h"] / 2.0
    dcx = dst["x"] + dst["w"] / 2.0
    dcy = dst["y"] + dst["h"] / 2.0
    dx = dcx - scx
    dy = dcy - scy

    if direction == "TB" and abs(dy) >= abs(dx) * 0.4:
        if dy >= 0:
            return scx, src["y"] + src["h"], dcx, dst["y"]
        return scx, src["y"], dcx, dst["y"] + dst["h"]

    if abs(dx) >= abs(dy):
        if dx >= 0:
            return src["x"] + src["w"], scy, dst["x"], dcy
        return src["x"], scy, dst["x"] + dst["w"], dcy

    if dy >= 0:
        return scx, src["y"] + src["h"], dcx, dst["y"]
    return scx, src["y"], dcx, dst["y"] + dst["h"]


def build_scene(spec: dict) -> tuple[dict, list[tuple[str, str]], list[tuple[str, str]]]:
    """Build Excalidraw v2 scene dict, text element entries, and element link entries."""
    direction = str(spec.get("direction", "LR")).upper()
    if direction not in ("LR", "TB"):
        direction = "LR"

    nodes = spec.get("nodes", [])
    edges = spec.get("edges", [])
    groups = spec.get("groups", [])

    boxes = _compute_node_boxes(nodes, edges, direction)
    group_elements: list[dict] = []
    node_elements: list[dict] = []
    edge_elements: list[dict] = []
    text_elements: list[tuple[str, str]] = []
    element_links: list[tuple[str, str]] = []
    shape_by_id: dict[str, dict] = {}

    # 1. Group frames (placed first so they render behind nodes)
    for grp in groups:
        gid = grp["id"]
        glabel = grp.get("label", gid)
        gcolor = grp.get("color", "#868e96")
        members = [b for b in boxes.values() if b["node"].get("group") == gid]
        if not members:
            continue

        min_x = min(b["x"] for b in members) - 24.0
        min_y = min(b["y"] for b in members) - 44.0
        max_x = max(b["x"] + b["w"] for b in members) + 24.0
        max_y = max(b["y"] + b["h"] for b in members) + 24.0

        frame_id = f"grp-{gid}"
        frame_el = _base_element(
            frame_id,
            "rectangle",
            min_x,
            min_y,
            max_x - min_x,
            max_y - min_y,
            stroke=gcolor,
            bg="#f8f9fa",
            fill_style="solid",
            stroke_style="dashed",
            opacity=60,
        )
        frame_el["strokeWidth"] = 1
        frame_el["boundElements"] = None
        group_elements.append(frame_el)

        gtitle_id = f"grp-title-{gid}"
        gtw, gth = _measure_text(glabel, font_size=14)
        title_el = _base_element(
            gtitle_id,
            "text",
            min_x + 12.0,
            min_y + 10.0,
            gtw,
            gth,
            stroke=gcolor,
            bg="transparent",
        )
        title_el.update(
            {
                "text": glabel,
                "originalText": glabel,
                "fontSize": 14,
                "fontFamily": 1,
                "textAlign": "left",
                "verticalAlign": "top",
                "containerId": None,
                "lineHeight": 1.25,
                "autoResize": True,
                "boundElements": None,
            }
        )
        group_elements.append(title_el)
        text_elements.append((gtitle_id, glabel))

    # 2. Nodes and bound labels
    for node in nodes:
        nid = node["id"]
        b = boxes[nid]
        shape_el = _base_element(
            nid,
            b["shape"],
            b["x"],
            b["y"],
            b["w"],
            b["h"],
            stroke=b["stroke"],
            bg=b["bg"],
        )

        raw_link = node.get("link")
        if raw_link:
            norm_link = _normalize_link(str(raw_link))
            shape_el["link"] = norm_link
            element_links.append((nid, norm_link))

        text_id = f"{nid}-text"
        shape_el["boundElements"].append({"id": text_id, "type": "text"})

        tx = b["x"] + (b["w"] - b["tw"]) / 2.0
        ty = b["y"] + (b["h"] - b["th"]) / 2.0
        text_el = _base_element(
            text_id,
            "text",
            tx,
            ty,
            b["tw"],
            b["th"],
            stroke="#1e1e1e",
            bg="transparent",
        )
        text_el.update(
            {
                "text": b["label"],
                "originalText": b["label"],
                "fontSize": 16,
                "fontFamily": 1,
                "textAlign": "center",
                "verticalAlign": "middle",
                "containerId": nid,
                "lineHeight": 1.25,
                "autoResize": True,
                "boundElements": None,
            }
        )

        shape_by_id[nid] = shape_el
        node_elements.extend([shape_el, text_el])
        text_elements.append((text_id, b["label"]))

    # 3. Edges and bound edge labels
    for idx, edge in enumerate(edges):
        src_id = edge.get("from", "")
        dst_id = edge.get("to", "")
        if src_id not in boxes or dst_id not in boxes:
            continue

        sx, sy, ex, ey = _edge_anchors(boxes[src_id], boxes[dst_id], direction)
        dx = round(ex - sx, 1)
        dy = round(ey - sy, 1)
        arrow_id = f"edge-{idx}-{src_id}-to-{dst_id}"

        arrow_el = _base_element(
            arrow_id,
            "arrow",
            sx,
            sy,
            abs(dx),
            abs(dy),
            stroke="#495057",
            bg="transparent",
            stroke_style=edge.get("style", "solid"),
        )
        arrow_el.update(
            {
                "roundness": {"type": 2},
                "points": [[0, 0], [dx, dy]],
                "lastCommittedPoint": None,
                "startBinding": {"elementId": src_id, "focus": 0, "gap": 4},
                "endBinding": {"elementId": dst_id, "focus": 0, "gap": 4},
                "startArrowhead": "arrow" if edge.get("bidirectional") else None,
                "endArrowhead": "arrow",
                "elbowed": False,
            }
        )

        shape_by_id[src_id]["boundElements"].append({"id": arrow_id, "type": "arrow"})
        shape_by_id[dst_id]["boundElements"].append({"id": arrow_id, "type": "arrow"})
        edge_elements.append(arrow_el)

        edge_label = str(edge.get("label", "")).strip()
        if edge_label:
            lbl_id = f"{arrow_id}-label"
            lw, lh = _measure_text(edge_label, font_size=14)
            mx = sx + dx / 2.0 - lw / 2.0
            my = sy + dy / 2.0 - lh / 2.0
            lbl_el = _base_element(
                lbl_id,
                "text",
                mx,
                my,
                lw,
                lh,
                stroke="#343a40",
                bg="transparent",
            )
            lbl_el.update(
                {
                    "text": edge_label,
                    "originalText": edge_label,
                    "fontSize": 14,
                    "fontFamily": 1,
                    "textAlign": "center",
                    "verticalAlign": "middle",
                    "containerId": arrow_id,
                    "lineHeight": 1.25,
                    "autoResize": True,
                    "boundElements": None,
                }
            )
            arrow_el["boundElements"].append({"id": lbl_id, "type": "text"})
            edge_elements.append(lbl_el)
            text_elements.append((lbl_id, edge_label))

    scene = {
        "type": "excalidraw",
        "version": 2,
        "source": "https://excalidraw.com",
        "elements": group_elements + node_elements + edge_elements,
        "appState": {"gridSize": 20, "viewBackgroundColor": "#ffffff"},
        "files": {},
    }
    return scene, text_elements, element_links


def render_obsidian_md(
    spec: dict,
    scene: dict,
    text_elements: list[tuple[str, str]],
    element_links: list[tuple[str, str]],
) -> str:
    """Wrap Excalidraw v2 scene into Obsidian excalidraw-plugin parsed markdown."""
    title = str(spec.get("title", "Diagram"))
    slug = str(spec.get("id") or _slugify(title))
    today = date.today().isoformat()

    raw_tags = ["excalidraw"]
    for tag in spec.get("tags", []):
        t = str(tag).strip()
        if t and t not in raw_tags:
            raw_tags.append(t)

    sources = [str(s).strip() for s in spec.get("sources", []) if str(s).strip()]

    lines = [
        "---",
        f"id: {slug}",
        "type: excalidraw",
        "excalidraw-plugin: parsed",
        "tags:",
    ]
    for tag in raw_tags:
        lines.append(f"  - {tag}")
    lines.extend([f"created: {today}", f"updated: {today}"])
    if sources:
        lines.append("sources:")
        for src in sources:
            lines.append(f'  - "{src}"')
    else:
        lines.append("sources: []")
    lines.extend(
        [
            "---",
            "==⚠ Switch to EXCALIDRAW VIEW in the MORE OPTIONS menu of this document. ⚠==",
            "",
            "# Excalidraw Data",
            "## Text Elements",
        ]
    )

    for tid, text in text_elements:
        lines.append(f"{text} ^{tid}")
        lines.append("")

    if element_links:
        lines.append("## Element Links")
        for sid, link in element_links:
            lines.append(f"^{sid}: {link}")
        lines.append("")

    lines.extend(
        [
            "%%",
            "## Drawing",
            "```json",
            json.dumps(scene, indent=2, ensure_ascii=False),
            "```",
            "%%",
            "",
        ]
    )
    return "\n".join(lines)


def _extract_scene_from_text(raw: str, is_markdown: bool) -> tuple[dict | None, list[str]]:
    errors: list[str] = []
    if not is_markdown:
        try:
            return json.loads(raw), errors
        except json.JSONDecodeError as exc:
            return None, [f"Invalid JSON: {exc}"]

    fm_match = re.match(r"^---\s*\n(.*?)\n---\s*\n", raw, re.DOTALL)
    if not fm_match:
        errors.append("Missing YAML frontmatter")
    elif not re.search(r"^excalidraw-plugin:\s*parsed\s*$", fm_match.group(1), re.MULTILINE):
        errors.append("Frontmatter missing 'excalidraw-plugin: parsed'")

    if "%%" not in raw:
        errors.append("Missing Obsidian '%%' hidden drawing block")

    json_match = re.search(r"##\s+Drawing\s*\n```json\s*\n(.*?)\n```", raw, re.DOTALL)
    if not json_match:
        errors.append("Missing '## Drawing' JSON code block")
        return None, errors

    try:
        scene = json.loads(json_match.group(1))
    except json.JSONDecodeError as exc:
        errors.append(f"Invalid Drawing JSON: {exc}")
        return None, errors

    return scene, errors


def validate_file(path: str) -> tuple[bool, list[str]]:
    """Validate an Obsidian .excalidraw.md or raw .excalidraw file."""
    file_path = Path(path)
    if not file_path.is_file():
        return False, [f"File not found: {path}"]

    raw = file_path.read_text(encoding="utf-8")
    is_md = file_path.name.lower().endswith(".md")
    scene, errors = _extract_scene_from_text(raw, is_md)
    if scene is None:
        return False, errors

    if scene.get("type") != "excalidraw":
        errors.append(f"Expected scene type 'excalidraw', got {scene.get('type')!r}")
    if scene.get("version") != 2:
        errors.append(f"Expected scene version 2, got {scene.get('version')!r}")

    elements = scene.get("elements")
    if not isinstance(elements, list) or not elements:
        errors.append("'elements' must be a non-empty list")
        return False, errors

    by_id: dict[str, dict] = {}
    for el in elements:
        if not isinstance(el, dict) or not el.get("id"):
            errors.append("Element missing string 'id'")
            continue
        eid = el["id"]
        if eid in by_id:
            errors.append(f"Duplicate element id: {eid}")
        by_id[eid] = el

    for eid, el in by_id.items():
        bound_ids = {
            b.get("id") for b in (el.get("boundElements") or []) if isinstance(b, dict)
        }
        if el.get("type") == "text" and el.get("containerId"):
            cid = el["containerId"]
            container = by_id.get(cid)
            if not container:
                errors.append(f"Text '{eid}' containerId '{cid}' does not exist")
            else:
                c_bounds = {
                    b.get("id")
                    for b in (container.get("boundElements") or [])
                    if isinstance(b, dict)
                }
                if eid not in c_bounds:
                    errors.append(
                        f"Container '{cid}' boundElements missing bound text '{eid}'"
                    )

        if el.get("type") == "arrow":
            for side in ("startBinding", "endBinding"):
                binding = el.get(side)
                if binding:
                    target_id = binding.get("elementId")
                    target = by_id.get(target_id)
                    if not target:
                        errors.append(
                            f"Arrow '{eid}' {side} target '{target_id}' does not exist"
                        )
                    else:
                        t_bounds = {
                            b.get("id")
                            for b in (target.get("boundElements") or [])
                            if isinstance(b, dict)
                        }
                        if eid not in t_bounds:
                            errors.append(
                                f"Target '{target_id}' boundElements missing arrow '{eid}'"
                            )

        for bid in bound_ids:
            if bid not in by_id:
                errors.append(f"Element '{eid}' boundElements references missing '{bid}'")

    return len(errors) == 0, errors


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Generate and validate Obsidian Excalidraw diagrams."
    )
    sub = parser.add_subparsers(dest="command", required=True)

    gen_p = sub.add_parser("generate", help="Generate .excalidraw.md or .excalidraw")
    gen_p.add_argument("--input", "-i", help="Input JSON spec path (default: stdin)")
    gen_p.add_argument("--output", "-o", help="Output file path (default: stdout)")
    gen_p.add_argument(
        "--format",
        choices=("obsidian", "excalidraw"),
        default="obsidian",
        help="Output format (default: obsidian)",
    )

    val_p = sub.add_parser("validate", help="Validate an Excalidraw file")
    val_p.add_argument("file", help="Path to .excalidraw.md or .excalidraw")

    args = parser.parse_args()

    if args.command == "validate":
        ok, errs = validate_file(args.file)
        if ok:
            print(f"[OK] Excalidraw valid: {args.file}")
            return 0
        print(f"[FAIL] Excalidraw invalid: {args.file}", file=sys.stderr)
        for err in errs:
            print(f"  - {err}", file=sys.stderr)
        return 1

    raw_spec = (
        Path(args.input).read_text(encoding="utf-8")
        if args.input
        else sys.stdin.read()
    )
    spec = json.loads(raw_spec)
    scene, text_elements, element_links = build_scene(spec)
    output_text = (
        render_obsidian_md(spec, scene, text_elements, element_links)
        if args.format == "obsidian"
        else json.dumps(scene, indent=2, ensure_ascii=False) + "\n"
    )

    if args.output:
        out_path = Path(args.output)
        out_path.parent.mkdir(parents=True, exist_ok=True)
        out_path.write_text(output_text, encoding="utf-8")
        ok, errs = validate_file(str(out_path))
        if not ok:
            print(f"[ERROR] Generated invalid file: {errs}", file=sys.stderr)
            return 1
        print(f"[OK] Generated Excalidraw ({len(scene['elements'])} elements): {out_path}")
    else:
        sys.stdout.write(output_text)

    return 0


if __name__ == "__main__":
    sys.exit(main())
