#!/usr/bin/env python3
"""
공통 AI 에이전트 라이프사이클 훅 (Claude, Gemini, Codex 공용)
1. PreToolUse: 파괴적 명령어, 민감 파일 접근, API 키 누출 차단
2. PostToolUse: 파일 수정 후 자동 코드 포매터 실행
3. Stop: 장시간 작업 완료 시 macOS 네이티브 알림
"""

import json
import os
import re
import shutil
import subprocess
import sys


# ------------------------------------------------------------------------------
# 1. 차단 규칙 정의 (Guard Rules)
# ------------------------------------------------------------------------------

# 파괴적 명령어 패턴
DANGEROUS_COMMAND_PATTERNS = [
    (r"git\s+push\s+.*(--force\b|-f\b)", "강제 푸시(git push --force)는 원격 히스토리를 덮어쓸 수 있어 차단됩니다."),
    (r"git\s+reset\s+--hard", "하드 리셋(git reset --hard)은 작업 내용을 영구 유실시킬 수 있어 차단됩니다."),
    (r"git\s+clean\s+-[a-zA-Z]*f", "git clean -f 명령은 추적되지 않는 파일을 강제 삭제하므로 차단됩니다."),
    (r"git\s+checkout\s+(\.|-f\b|--force)", "git checkout . / -f 명령은 수정사항을 되돌리므로 차단됩니다."),
    (r"rm\s+-(rf|fr)\s+[/~]", "루트(/) 또는 홈(~) 디렉터리 강제 삭제 명령은 위험하므로 차단됩니다."),
    (r"\bmkfs(\.\w+)?\b", "파일 시스템 포맷(mkfs) 명령은 차단됩니다."),
    (r"\bdd\s+if=", "dd 저수준 디스크 덮어쓰기 명령은 차단됩니다."),
    (r"chmod\s+-R\s+777\s+[/~]", "루트/홈 전체에 777 권한 부여는 보안상 차단됩니다."),
]

# 민감 파일 패턴 (example, sample, template 은 허용)
SENSITIVE_FILE_PATTERN = re.compile(
    r"(^|/)(?!\.env\.(example|sample|template))(\.env(\..+)?|id_rsa(\.pub)?|id_ed25519(\.pub)?|.*\.pem|.*\.key|credentials\.json|oauth_creds\.json|auth\.json)$",
    re.IGNORECASE,
)

# API 키 및 시크릿 토큰 패턴
SECRET_PATTERNS = [
    (re.compile(r"ghp_[a-zA-Z0-9]{36}"), "GitHub Personal Access Token"),
    (re.compile(r"github_pat_[a-zA-Z0-9_]{82}"), "GitHub Fine-Grained Token"),
    (re.compile(r"sk-[a-zA-Z0-9]{48}"), "OpenAI API Key"),
    (re.compile(r"AIzaSy[a-zA-Z0-9_-]{33}"), "Google API Key"),
    (re.compile(r"AKIA[0-9A-Z]{16}"), "AWS Access Key"),
    (re.compile(r"xox[baprs]-[0-9a-zA-Z]{10,48}"), "Slack Token"),
]


# ------------------------------------------------------------------------------
# 2. 페이로드 파서 (Claude / Gemini / Codex 공통)
# ------------------------------------------------------------------------------

def parse_input():
    """stdin에서 JSON을 읽어 도구 이름과 인자를 정규화하여 반환"""
    try:
        raw = sys.stdin.read()
        if not raw.strip():
            return {}
        return json.loads(raw)
    except Exception:
        return {}


def extract_tool_info(payload):
    """플랫폼별 페이로드 차이를 흡수하여 (tool_name, args) 추출"""
    # Gemini / Antigravity 포맷
    if "toolCall" in payload:
        tc = payload.get("toolCall", {})
        return tc.get("name", ""), tc.get("args", {})

    # Claude / Codex 포맷
    tool_name = payload.get("tool_name") or payload.get("name", "")
    tool_args = payload.get("tool_input") or payload.get("args") or payload.get("input", {})
    return tool_name, tool_args


# ------------------------------------------------------------------------------
# 3. PreToolUse 핸들러 (차단 가드 & 시크릿 검사)
# ------------------------------------------------------------------------------

def handle_pre_tool():
    payload = parse_input()
    tool_name, tool_args = extract_tool_info(payload)

    # 1) 명령어 검사 (run_command, Bash, terminal 등)
    cmd = (
        tool_args.get("CommandLine")
        or tool_args.get("command")
        or tool_args.get("cmd")
        or ""
    )
    if cmd:
        # 위험 명령어 검사
        for pattern, msg in DANGEROUS_COMMAND_PATTERNS:
            if re.search(pattern, cmd, re.IGNORECASE):
                deny(f"위험한 명령어 차단: {msg} (명령: '{cmd[:80]}...')")

        # 시크릿 파일 접근 검사 (예: cat .env, rm .env)
        tokens = re.split(r"\s+", cmd)
        for token in tokens:
            cleaned = token.strip("\"'`;|&<>()")
            if cleaned and SENSITIVE_FILE_PATTERN.search(cleaned):
                deny(f"민감한 시크릿 파일 직접 접근 차단: '{cleaned}'")

        # API 키 및 시크릿 누출 검사
        for pattern, secret_type in SECRET_PATTERNS:
            if pattern.search(cmd):
                deny(f"명령어 내 민감 정보({secret_type}) 노출 차단")

    # 2) 파일 도구 검사 (write_file, edit_file, read_file 등)
    file_path = (
        tool_args.get("Path")
        or tool_args.get("path")
        or tool_args.get("file_path")
        or tool_args.get("file")
        or ""
    )
    if file_path:
        norm_path = os.path.basename(file_path.strip("\"'"))
        if SENSITIVE_FILE_PATTERN.search(norm_path) or SENSITIVE_FILE_PATTERN.search(file_path):
            # 파일 읽기/쓰기 차단
            deny(f"민감한 시크릿 파일({norm_path}) 접근 또는 수정 시도가 차단되었습니다.")

    # 정상 허용
    allow()


def deny(reason: str):
    """차단 응답 출력 및 종료"""
    sys.stderr.write(f"\n[Security Guard] {reason}\n")
    # Gemini / Antigravity 규격 JSON
    print(json.dumps({"decision": "deny", "reason": reason}))
    sys.exit(1)


def allow():
    """허용 응답 출력 및 종료"""
    print(json.dumps({"decision": "allow"}))
    sys.exit(0)


# ------------------------------------------------------------------------------
# 4. PostToolUse 핸들러 (자동 코드 포매터 실행)
# ------------------------------------------------------------------------------

def handle_post_tool():
    payload = parse_input()
    tool_name, tool_args = extract_tool_info(payload)

    # 파일 생성/수정 도구인 경우에만 포매터 실행
    write_tools = {"write_file", "edit_file", "Write", "Edit", "str_replace_editor"}
    if tool_name not in write_tools:
        print(json.dumps({}))
        sys.exit(0)

    file_path = (
        tool_args.get("Path")
        or tool_args.get("path")
        or tool_args.get("file_path")
        or ""
    )
    if not file_path or not os.path.isfile(file_path):
        print(json.dumps({}))
        sys.exit(0)

    format_file(file_path)
    print(json.dumps({}))
    sys.exit(0)


def format_file(file_path: str):
    """파일 확장자별 로컬 포매터 실행 (실패 시 조용히 무시)"""
    ext = os.path.splitext(file_path)[1].lower()

    try:
        # JS / TS / JSON / Markdown -> Prettier
        if ext in {".ts", ".tsx", ".js", ".jsx", ".json", ".md", ".css", ".scss"}:
            prettier_cmd = shutil.which("prettier")
            if prettier_cmd:
                subprocess.run(
                    [prettier_cmd, "--write", file_path],
                    stdout=subprocess.DEVNULL,
                    stderr=subprocess.DEVNULL,
                    timeout=5,
                )

        # Python -> ruff 또는 black
        elif ext == ".py":
            ruff_cmd = shutil.which("ruff")
            if ruff_cmd:
                subprocess.run(
                    [ruff_cmd, "format", file_path],
                    stdout=subprocess.DEVNULL,
                    stderr=subprocess.DEVNULL,
                    timeout=5,
                )
            else:
                black_cmd = shutil.which("black")
                if black_cmd:
                    subprocess.run(
                        [black_cmd, "-q", file_path],
                        stdout=subprocess.DEVNULL,
                        stderr=subprocess.DEVNULL,
                        timeout=5,
                    )

        # C / C++ -> clang-format
        elif ext in {".c", ".cpp", ".cc", ".h", ".hpp"}:
            clang_cmd = shutil.which("clang-format")
            if clang_cmd:
                subprocess.run(
                    [clang_cmd, "-i", file_path],
                    stdout=subprocess.DEVNULL,
                    stderr=subprocess.DEVNULL,
                    timeout=5,
                )

        # Lua -> stylua
        elif ext == ".lua":
            stylua_cmd = shutil.which("stylua")
            if stylua_cmd:
                subprocess.run(
                    [stylua_cmd, file_path],
                    stdout=subprocess.DEVNULL,
                    stderr=subprocess.DEVNULL,
                    timeout=5,
                )
    except Exception:
        pass


# ------------------------------------------------------------------------------
# 5. Stop 핸들러 (macOS 네이티브 알림)
# ------------------------------------------------------------------------------

def handle_stop():
    # macOS 환경 알림 전송
    if sys.platform == "darwin":
        try:
            msg = "에이전트 작업이 완료되었습니다."
            script = f'display notification "{msg}" with title "AI Agent" sound name "Glass"'
            subprocess.run(
                ["osascript", "-e", script],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                timeout=3,
            )
        except Exception:
            pass

    print(json.dumps({}))
    sys.exit(0)


# ------------------------------------------------------------------------------
# 메인 엔트리포인트
# ------------------------------------------------------------------------------

def main():
    if len(sys.argv) < 2:
        print(json.dumps({}))
        sys.exit(0)

    action = sys.argv[1].lower()
    if action in {"pre-tool", "pretooluse", "pre_tool"}:
        handle_pre_tool()
    elif action in {"post-tool", "posttooluse", "post_tool"}:
        handle_post_tool()
    elif action in {"stop", "session-end", "sessionend"}:
        handle_stop()
    else:
        print(json.dumps({}))
        sys.exit(0)


if __name__ == "__main__":
    main()
