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

# 파괴적 명령어 패턴 (고정 문자열 / 정규식)
DANGEROUS_COMMAND_PATTERNS = [
    (
        r"git\s+push\s+.*(--force\b|-f\b)",
        "강제 푸시(git push --force)는 원격 히스토리를 덮어쓸 수 있어 차단됩니다.",
    ),
    (
        r"git\s+reset\s+--hard",
        "하드 리셋(git reset --hard)은 작업 내용을 영구 유실시킬 수 있어 차단됩니다.",
    ),
    (
        r"git\s+clean\s+-[a-zA-Z]*f",
        "git clean -f 명령은 추적되지 않는 파일을 강제 삭제하므로 차단됩니다.",
    ),
    (
        r"git\s+checkout\s+(\.|-f\b|--force)",
        "git checkout . / -f 명령은 수정사항을 되돌리므로 차단됩니다.",
    ),
    (r"\bmkfs(\.\w+)?\b", "파일 시스템 포맷(mkfs) 명령은 차단됩니다."),
    (r"\bdd\s+if=", "dd 저수준 디스크 덮어쓰기 명령은 차단됩니다."),
]

# 시스템 핵심 디렉터리 (전체 삭제 방지용)
CRITICAL_SYSTEM_DIRS = {
    "/",
    "/*",
    "/system",
    "/system/*",
    "/library",
    "/library/*",
    "/usr",
    "/usr/*",
    "/bin",
    "/bin/*",
    "/sbin",
    "/sbin/*",
    "/etc",
    "/etc/*",
    "/var",
    "/var/*",
    "/dev",
    "/dev/*",
    "/opt",
    "/opt/*",
    "/private",
    "/private/*",
    "/applications",
    "/applications/*",
}

# 홈 디렉터리 전체 타겟
CRITICAL_HOME_TARGETS = {
    "~",
    "~/",
    "~/*",
    "$home",
    "$home/",
    "$home/*",
    "${home}",
    "${home}/",
    "${home}/*",
}


def is_dangerous_rm(cmd: str) -> bool:
    """rm 명령어의 타겟을 정밀 분석하여 루트, 홈, 시스템 주요 디렉터리 전체 삭제만 선별 차단합니다.

    /tmp/..., ~/.cache/..., 프로젝트 내부 서브디렉터리 등 안전한 하위 경로 삭제는 허용합니다.
    """
    sub_cmds = re.split(r"[;&|]+", cmd)
    for sub in sub_cmds:
        tokens = sub.strip().split()
        if not tokens:
            continue

        cmd_idx = 0
        if tokens[0] in ("sudo", "env", "nohup") and len(tokens) > 1:
            cmd_idx = 1

        if cmd_idx >= len(tokens) or tokens[cmd_idx] != "rm":
            continue

        rm_args = tokens[cmd_idx + 1 :]
        # 재귀 플래그(-r, -R, -rf, -fr, --recursive 등) 확인
        has_recursive = any(
            arg == "--recursive" or re.search(r"^-[a-zA-Z]*[rR]", arg)
            for arg in rm_args
        )
        if not has_recursive:
            continue

        # 타겟 인자 추출
        targets = [
            arg.strip("\"'`;")
            for arg in rm_args
            if not arg.startswith("-") and arg.strip("\"'`;")
        ]

        for target in targets:
            norm = target.strip().rstrip("/")
            norm_lower = norm.lower()

            # 1. 루트 전체 삭제 (예: /, /*)
            if norm in ("", "/", "/*"):
                return True

            # 2. 홈 디렉터리 전체 삭제 (예: ~, ~/, ~/*, $HOME 등)
            if (
                norm_lower in CRITICAL_HOME_TARGETS
                or target.strip().lower() in CRITICAL_HOME_TARGETS
            ):
                return True

            # 3. 시스템 주요 최상위 디렉터리 전체 삭제 (예: /System, /Library, /usr 등)
            # 단, /tmp/xxx, ~/.cache/xxx 등 구체적 하위 경로는 안전하므로 허용
            if norm_lower in CRITICAL_SYSTEM_DIRS:
                return True

    return False


def is_dangerous_chmod(cmd: str) -> bool:
    """루트 또는 홈 전체에 chmod -R 777을 부여하는 파괴적 명령만 선별 차단합니다."""
    sub_cmds = re.split(r"[;&|]+", cmd)
    for sub in sub_cmds:
        tokens = sub.strip().split()
        if not tokens:
            continue

        cmd_idx = 0
        if tokens[0] in ("sudo", "env", "nohup") and len(tokens) > 1:
            cmd_idx = 1

        if cmd_idx >= len(tokens) or tokens[cmd_idx] != "chmod":
            continue

        args = tokens[cmd_idx + 1 :]
        has_recursive = any(
            arg in ("-R", "-r") or re.search(r"^-[a-zA-Z]*R", arg) for arg in args
        )
        has_777 = any("777" in arg for arg in args)

        if not (has_recursive and has_777):
            continue

        targets = [
            arg.strip("\"'`;")
            for arg in args
            if not arg.startswith("-") and "777" not in arg
        ]
        for target in targets:
            norm = target.strip().rstrip("/").lower()
            if norm in ("", "/", "/*") or norm in CRITICAL_HOME_TARGETS:
                return True

    return False

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
    tool_args = (
        payload.get("tool_input") or payload.get("args") or payload.get("input", {})
    )
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
        # 위험 명령어 검사 (정규식 패턴)
        for pattern, msg in DANGEROUS_COMMAND_PATTERNS:
            if re.search(pattern, cmd, re.IGNORECASE):
                deny(f"위험한 명령어 차단: {msg} (명령: '{cmd[:80]}...')")

        # 파괴적 삭제(rm) 검사 (루트/홈/시스템 핵심 디렉터리 정밀 차단)
        if is_dangerous_rm(cmd):
            deny(f"위험한 명령어 차단: 루트(/), 홈(~), 또는 시스템 핵심 디렉터리 전체 삭제 명령은 차단됩니다. (명령: '{cmd[:80]}...')")

        # 파괴적 권한 변경(chmod 777) 검사
        if is_dangerous_chmod(cmd):
            deny(f"위험한 명령어 차단: 루트(/) 또는 홈(~) 전체에 777 권한 부여는 보안상 차단됩니다. (명령: '{cmd[:80]}...')")

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
        if SENSITIVE_FILE_PATTERN.search(norm_path) or SENSITIVE_FILE_PATTERN.search(
            file_path
        ):
            # 파일 읽기/쓰기 차단
            deny(
                f"민감한 시크릿 파일({norm_path}) 접근 또는 수정 시도가 차단되었습니다."
            )

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
# 4. PostToolUse 핸들러 (단발성 Docker 컨테이너 기반 코드 포매터 실행)
# ------------------------------------------------------------------------------

DOCKER_IMAGE = "dotconfig-formatter:latest"

# 지원 언어 확장자별 포매터 및 실행 명령어
FORMATTER_COMMANDS = {
    # JS / TS / JSON / Markdown / CSS / SCSS -> Prettier
    ".js": ["prettier", "--write"],
    ".jsx": ["prettier", "--write"],
    ".ts": ["prettier", "--write"],
    ".tsx": ["prettier", "--write"],
    ".json": ["prettier", "--write"],
    ".md": ["prettier", "--write"],
    ".css": ["prettier", "--write"],
    ".scss": ["prettier", "--write"],
    # Python -> ruff
    ".py": ["ruff", "format"],
    # C / C++ -> clang-format
    ".c": ["clang-format", "-i"],
    ".cpp": ["clang-format", "-i"],
    ".cc": ["clang-format", "-i"],
    ".h": ["clang-format", "-i"],
    ".hpp": ["clang-format", "-i"],
    # Lua -> stylua
    ".lua": ["stylua"],
    # Java -> google-java-format
    ".java": ["google-java-format", "--replace"],
}


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
    """단발성 Docker 컨테이너(docker run --rm) 기반 포매터 실행 (실패 시 로컬 폴백)"""
    ext = os.path.splitext(file_path)[1].lower()
    cmd_prefix = FORMATTER_COMMANDS.get(ext)
    if not cmd_prefix:
        return

    # 심볼릭 링크 해석을 포함한 정규 절대 경로
    abs_path = os.path.realpath(os.path.abspath(file_path))
    file_dir = os.path.dirname(abs_path)
    home_dir = os.path.realpath(os.path.expanduser("~"))

    # 1) Docker 단발성 컨테이너 실행 시도
    docker_bin = shutil.which("docker")
    if docker_bin:
        try:
            # 기본적으로 홈 디렉터리 마운트
            volume_args = ["-v", f"{home_dir}:{home_dir}"]
            # 임시 폴더 또는 홈 외부 경로 접근 지원
            if abs_path.startswith("/private/"):
                volume_args.extend(["-v", "/private:/private"])
            elif not abs_path.startswith(home_dir):
                volume_args.extend(["-v", f"{file_dir}:{file_dir}"])

            docker_cmd = (
                [
                    docker_bin,
                    "run",
                    "--rm",
                ]
                + volume_args
                + [
                    "-w",
                    file_dir,
                    DOCKER_IMAGE,
                ]
                + cmd_prefix
                + [abs_path]
            )

            res = subprocess.run(
                docker_cmd,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                timeout=15,
            )
            if res.returncode == 0:
                return
        except Exception:
            pass

    # 2) Docker 미가동 또는 실패 시 로컬 포매터 폴백
    try:
        local_tool = cmd_prefix[0]
        local_bin = shutil.which(local_tool)
        if local_bin:
            local_cmd = [local_bin] + cmd_prefix[1:] + [abs_path]
            subprocess.run(
                local_cmd,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                timeout=5,
            )
        elif ext == ".py":
            # Python: ruff 없으면 black 시도
            black_bin = shutil.which("black")
            if black_bin:
                subprocess.run(
                    [black_bin, "-q", abs_path],
                    stdout=subprocess.DEVNULL,
                    stderr=subprocess.DEVNULL,
                    timeout=5,
                )
    except Exception:
        pass


# ------------------------------------------------------------------------------
# 5. Stop 핸들러 (macOS 네이티브 알림)
# ------------------------------------------------------------------------------


def get_target_app():
    """알림 클릭 시 포커스할 대상 애플리케이션 및 번들 ID를 감지합니다."""
    # 1. Antigravity 환경 감지
    if "ANTIGRAVITY_AGENT" in os.environ or "ANTIGRAVITY_APP_DATA_DIR" in os.environ:
        return "Antigravity IDE", "com.google.antigravity-ide"

    # 2. WezTerm 환경 감지
    if "WEZTERM_EXECUTABLE" in os.environ:
        return "WezTerm", "com.github.wez.wezterm"

    # 3. Alacritty 환경 감지
    if "ALACRITTY_LOG" in os.environ or "ALACRITTY_SOCKET" in os.environ:
        return "Alacritty", "org.alacritty"

    # 4. 기타 터미널 및 VS Code 감지
    term_prog = os.environ.get("TERM_PROGRAM", "").lower()
    if "vscode" in term_prog:
        return "Antigravity IDE", "com.google.antigravity-ide"
    elif "iterm" in term_prog:
        return "iTerm2", "com.googlecode.iterm2"
    elif "apple_terminal" in term_prog:
        return "Terminal", "com.apple.Terminal"

    # 5. 기본값: Antigravity IDE
    return "Antigravity IDE", "com.google.antigravity-ide"


def handle_stop():
    # macOS 환경 알림 전송
    if sys.platform == "darwin":
        try:
            msg = "에이전트 작업이 완료되었습니다."
            title = "AI Agent"
            app_name, bundle_id = get_target_app()

            # 1. terminal-notifier 우선 시도 (클릭 시 해당 앱 활성화)
            notified = False
            if shutil.which("terminal-notifier"):
                res = subprocess.run(
                    [
                        "terminal-notifier",
                        "-title",
                        title,
                        "-message",
                        msg,
                        "-sound",
                        "Glass",
                        "-activate",
                        bundle_id,
                        "-group",
                        "ai-agent-stop",
                    ],
                    stdout=subprocess.DEVNULL,
                    stderr=subprocess.DEVNULL,
                    timeout=3,
                )
                if res.returncode == 0:
                    notified = True

            # 2. terminal-notifier 실패/미설치 시 AppleScript tell application 폴백
            # (발신자 앱을 Antigravity IDE/WezTerm 등으로 귀속시켜 클릭 시 스크립트 편집기 대신 해당 창 활성화)
            if not notified:
                script = (
                    f'tell application "{app_name}" to display notification "{msg}" '
                    f'with title "{title}" sound name "Glass"'
                )
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
