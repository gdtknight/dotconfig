#!/usr/bin/env python3
"""차세대 맞춤형 Dev Container 생성 엔진 (devcontainer-init 2.0).

대화형 마법사(Interactive Wizard)와 비대화형 CLI 플래그를 모두 지원하며,
최신 버전 동적 주입, 패키지 매니저 주입, 로컬 DB 사이드카 Compose 자동 승격,
포트 포워딩, 부팅 훅 자동화를 선언적으로 수행합니다.
"""

import argparse
import json
import os
import re
import shutil
import sys

# 스크립트 디렉터리 경로 등록
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
if SCRIPT_DIR not in sys.path:
    sys.path.insert(0, SCRIPT_DIR)

from db_templates import SUPPORTED_DATABASES, render_compose_yaml
from version_fetcher import get_template_versions

# ANSI 색상 코드 정의
C_RESET = "\033[0m"
C_BOLD = "\033[1m"
C_CYAN = "\033[1;36m"
C_GREEN = "\033[1;32m"
C_YELLOW = "\033[1;33m"
C_RED = "\033[1;31m"
C_DIM = "\033[2m"


# ------------------------------------------------------------------------------
# 1. 템플릿별 기본 메타데이터 및 옵션 사양
# ------------------------------------------------------------------------------

TEMPLATE_METADATA = {
    "node-ts": {
        "title": "Node.js & TypeScript",
        "default_port": [3000],
        "pkg_managers": ["pnpm (권장)", "bun", "yarn", "npm"],
        "default_pkg": "pnpm",
        "user": "node",
        "home": "/home/node",
    },
    "python-ai": {
        "title": "Python & AI Engineering",
        "default_port": [8888, 5000],
        "pkg_managers": ["uv (초고속 권장)", "poetry", "pip"],
        "default_pkg": "uv",
        "user": "vscode",
        "home": "/home/vscode",
    },
    "go-backend": {
        "title": "Go Backend Service",
        "default_port": [8080],
        "pkg_managers": ["go mod (기본)"],
        "default_pkg": "go mod",
        "user": "vscode",
        "home": "/home/vscode",
    },
    "fullstack-db": {
        "title": "Full-Stack Node + DB",
        "default_port": [3000, 5432],
        "pkg_managers": ["pnpm (권장)", "yarn", "npm"],
        "default_pkg": "pnpm",
        "user": "node",
        "home": "/home/node",
    },
    "rust": {
        "title": "Rust Systems Programming",
        "default_port": [8080],
        "pkg_managers": ["cargo (기본)"],
        "default_pkg": "cargo",
        "user": "vscode",
        "home": "/home/vscode",
    },
    "java": {
        "title": "Java Spring / OpenJDK",
        "default_port": [8080],
        "pkg_managers": ["gradle (권장)", "maven"],
        "default_pkg": "gradle",
        "user": "vscode",
        "home": "/home/vscode",
    },
    "react-native": {
        "title": "React Native Mobile Hub",
        "default_port": [8081, 19000],
        "pkg_managers": ["yarn (권장)", "npm"],
        "default_pkg": "yarn",
        "user": "node",
        "home": "/home/node",
    },
    "42-c-valgrind": {
        "title": "42 C/C++ Valgrind & Norminette",
        "default_port": [],
        "pkg_managers": ["make (기본)"],
        "default_pkg": "make",
        "user": "vscode",
        "home": "/home/vscode",
    },
    "devops-cloud": {
        "title": "DevOps & Cloud Terraform",
        "default_port": [],
        "pkg_managers": ["terraform (기본)"],
        "default_pkg": "terraform",
        "user": "vscode",
        "home": "/home/vscode",
    },
}


# ------------------------------------------------------------------------------
# 2. 대화형 마법사 프롬프트 헬퍼
# ------------------------------------------------------------------------------


def prompt_select(
    question: str, options: list[str], default_idx: int = 0
) -> tuple[int, str]:
    """단일 선택지 프롬프트 (번호 입력)"""
    print(f"\n{C_CYAN}? {question}{C_RESET}")
    for idx, opt in enumerate(options, 1):
        is_default = (idx - 1) == default_idx
        marker = f"{C_GREEN}▸{C_RESET}" if is_default else " "
        def_tag = f"{C_DIM} (기본값){C_RESET}" if is_default else ""
        print(f"  {marker} [{idx}] {opt}{def_tag}")

    while True:
        try:
            choice = input(
                f"{C_DIM}번호 선택 [1-{len(options)}, 엔터는 {default_idx+1}]: {C_RESET}"
            ).strip()
            if not choice:
                return default_idx, options[default_idx]
            num = int(choice)
            if 1 <= num <= len(options):
                return num - 1, options[num - 1]
            print(f"{C_RED}1부터 {len(options)} 사이의 번호를 입력해주세요.{C_RESET}")
        except (ValueError, KeyboardInterrupt, EOFError):
            print(f"\n{C_YELLOW}입력이 취소되었습니다.{C_RESET}")
            sys.exit(0)


def prompt_multiselect(
    question: str, options: list[tuple[str, str, bool]]
) -> list[str]:
    """다중 선택 프롬프트 (스페이스/쉼표 구분 번호 입력)"""
    print(
        f"\n{C_CYAN}? {question}{C_RESET} {C_DIM}(쉼표로 여러 개 선택 가능, 예: 1, 2){C_RESET}"
    )
    for idx, (key, label, default_on) in enumerate(options, 1):
        check = f"{C_GREEN}[x]{C_RESET}" if default_on else "[ ]"
        print(f"   [{idx}] {check} {label}")

    while True:
        try:
            raw = input(
                f"{C_DIM}선택 번호 입력 (엔터 시 기본값 유지 / 0 입력 시 선택 해제): {C_RESET}"
            ).strip()
            if not raw:
                # 기본값 유지
                return [key for key, _, def_on in options if def_on]
            if raw == "0":
                return []

            selected = []
            parts = re.split(r"[\s,]+", raw)
            valid = True
            for p in parts:
                if not p:
                    continue
                num = int(p)
                if 1 <= num <= len(options):
                    selected.append(options[num - 1][0])
                else:
                    valid = False
                    break
            if valid:
                return selected
            print(f"{C_RED}올바른 번호를 입력해주세요.{C_RESET}")
        except (ValueError, KeyboardInterrupt, EOFError):
            print(f"\n{C_YELLOW}입력이 취소되었습니다.{C_RESET}")
            sys.exit(0)


def prompt_text(question: str, default: str = "") -> str:
    """텍스트 입력 프롬프트"""
    print(f"\n{C_CYAN}? {question}{C_RESET}")
    def_tag = f" {C_DIM}(기본값: {default}){C_RESET}" if default else ""
    try:
        val = input(f"{C_DIM}입력{def_tag}: {C_RESET}").strip()
        return val if val else default
    except (KeyboardInterrupt, EOFError):
        print(f"\n{C_YELLOW}입력이 취소되었습니다.{C_RESET}")
        sys.exit(0)


def prompt_confirm(question: str, default: bool = True) -> bool:
    """Y/n 확인 프롬프트"""
    def_str = "Y/n" if default else "y/N"
    print(f"\n{C_CYAN}? {question} [{def_str}]{C_RESET} ", end="")
    try:
        ans = input().strip().lower()
        if not ans:
            return default
        return ans in ("y", "yes")
    except (KeyboardInterrupt, EOFError):
        print(f"\n{C_YELLOW}입력이 취소되었습니다.{C_RESET}")
        sys.exit(0)


# ------------------------------------------------------------------------------
# 3. 템플릿 커스텀 엔진 (JSON & Compose 합성)
# ------------------------------------------------------------------------------


def extract_clean_version(raw_version: str) -> str:
    """'22 (LTS: Jod)' -> '22', '3.12 (권장)' -> '3.12' 와 같이 순수 버전 문자열 추출"""
    clean = raw_version.split("(")[0].strip()
    return clean.replace("Ubuntu", "").replace("Node.js", "").strip()


def customize_devcontainer(
    template_dir: str,
    target_dir: str,
    selected_version: str,
    pkg_manager: str,
    selected_dbs: list[str],
    ports: list[int],
    enable_nvim: bool = True,
    enable_docker_socket: bool = False,
    enable_ai_cli: bool = False,
    auto_install_deps: bool = True,
):
    """지정된 옵션들을 바탕으로 .devcontainer 및 docker-compose.yml을 생성합니다."""
    template_devcontainer_dir = os.path.join(template_dir, ".devcontainer")
    dest_devcontainer_dir = os.path.join(target_dir, ".devcontainer")

    # 대상 디렉터리 준비
    os.makedirs(dest_devcontainer_dir, exist_ok=True)

    # 원본 파일 복사 (Dockerfile 등 부속 파일이 있는 경우 유지)
    for item in os.listdir(template_devcontainer_dir):
        src_path = os.path.join(template_devcontainer_dir, item)
        dst_path = os.path.join(dest_devcontainer_dir, item)
        if os.path.isfile(src_path):
            shutil.copy2(src_path, dst_path)

    json_path = os.path.join(dest_devcontainer_dir, "devcontainer.json")
    with open(json_path, "r", encoding="utf-8") as f:
        data = json.load(f)

    # 1. 버전 치환
    clean_ver = extract_clean_version(selected_version)
    if clean_ver and "image" in data:
        orig_img = data["image"]
        base_img_name = orig_img.split(":")[0]
        data["image"] = f"{base_img_name}:{clean_ver}"

    # 2. Features 블록 초기화
    if "features" not in data:
        data["features"] = {}

    # 3. 패키지 매니저 주입
    pkg_clean = pkg_manager.split("(")[0].strip().lower()
    if "pnpm" in pkg_clean:
        data["features"]["ghcr.io/devcontainers/features/node:1"] = {
            "pnpmVersion": "latest"
        }
    elif "bun" in pkg_clean:
        data["features"]["ghcr.io/devcontainers-extra/features/bun:1"] = {}
    elif "uv" in pkg_clean:
        data["features"]["ghcr.io/astral-sh/uv-devcontainer/uv:1"] = {}
    elif "poetry" in pkg_clean:
        data["features"]["ghcr.io/devcontainers-extra/features/poetry:2"] = {}

    # 4. 호스트 Docker 소켓 바인딩 (Docker-outside-of-Docker)
    if enable_docker_socket:
        data["features"][
            "ghcr.io/devcontainers/features/docker-outside-of-docker:1"
        ] = {}

    # 5. 호스트 Neovim 설정 마운트
    template_name = os.path.basename(template_dir)
    meta = TEMPLATE_METADATA.get(template_name, {})
    user_home = meta.get("home", "/home/vscode")

    if enable_nvim:
        if "mounts" not in data:
            data["mounts"] = []
        nvim_mount = (
            f"source=${{localEnv:HOME}}/.config/nvim,"
            f"target={user_home}/.config/nvim,type=bind,consistency=cached"
        )
        if not any("nvim" in str(m) for m in data["mounts"]):
            data["mounts"].append(nvim_mount)

    # 6. 포트 포워딩 주입
    if ports:
        data["forwardPorts"] = ports
        if "portsAttributes" not in data:
            data["portsAttributes"] = {}
        for p in ports:
            data["portsAttributes"][str(p)] = {
                "label": f"Port {p}",
                "onAutoForward": "notify",
            }

    # 7. 타임존 및 로케일 자동 주입 (Asia/Seoul)
    if "containerEnv" not in data:
        data["containerEnv"] = {}
    data["containerEnv"]["TZ"] = "Asia/Seoul"

    # 8. 부팅 훅 (postCreateCommand) 자동화
    post_cmds = []
    if auto_install_deps:
        if "pnpm" in pkg_clean:
            post_cmds.append("pnpm install || true")
        elif "bun" in pkg_clean:
            post_cmds.append("bun install || true")
        elif "yarn" in pkg_clean:
            post_cmds.append("yarn install || true")
        elif "npm" in pkg_clean:
            post_cmds.append("npm install || true")
        elif "uv" in pkg_clean:
            post_cmds.append(
                "uv sync || [ -f requirements.txt ] && uv pip install -r requirements.txt || true"
            )
        elif "poetry" in pkg_clean:
            post_cmds.append("poetry install || true")
        elif "go mod" in pkg_clean:
            post_cmds.append("go mod download || true")

    if enable_ai_cli:
        post_cmds.append(
            "npm install -g @google/antigravity @anthropic-ai/claude-code 2>/dev/null || true"
        )

    if post_cmds:
        data["postCreateCommand"] = " && ".join(post_cmds)

    # 9. 데이터베이스 사이드카가 있는 경우: Docker Compose로 자동 승격!
    if selected_dbs:
        compose_path = os.path.join(dest_devcontainer_dir, "docker-compose.yml")
        base_img = data.get("image", "")
        dockerfile = data.get("build", {}).get("dockerfile", "")

        compose_content = render_compose_yaml(
            base_image=base_img,
            dockerfile=dockerfile,
            selected_dbs=selected_dbs,
            custom_ports=ports,
        )
        with open(compose_path, "w", encoding="utf-8") as f:
            f.write(compose_content)

        # devcontainer.json을 Compose 모드로 전환
        data["dockerComposeFile"] = ["docker-compose.yml"]
        data["service"] = "app"
        data["workspaceFolder"] = (
            "/workspaces/${localWorkspaceFolderBasename}"
        )
        data["shutdownAction"] = "stopCompose"

        # 포트는 compose가 관리하므로 중복 방지 정리
        data.pop("image", None)
        data.pop("build", None)

    # 최종 devcontainer.json 저장
    with open(json_path, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2, ensure_ascii=False)


# ------------------------------------------------------------------------------
# 4. 메인 CLI 진입점 (대화형 / 플래그 하이브리드)
# ------------------------------------------------------------------------------


def main():
    parser = argparse.ArgumentParser(
        description="차세대 맞춤형 Dev Container 생성기 (devcontainer-init 2.0)",
        formatter_class=argparse.RawTextHelpFormatter,
    )
    parser.add_argument(
        "template",
        nargs="?",
        help="생성할 Dev Container 템플릿 이름 (예: node-ts, python-ai, fullstack-db 등)",
    )
    parser.add_argument(
        "--version", "-v", help="언어/SDK 버전 (예: 22, 3.12, 1.23 등)"
    )
    parser.add_argument(
        "--pkg",
        "-p",
        help="패키지 매니저 (예: pnpm, bun, yarn, npm, uv, poetry)",
    )
    parser.add_argument(
        "--db",
        "-d",
        help="로컬 DB 사이드카 (쉼표 구분: postgres,redis,mysql,mongo)",
    )
    parser.add_argument(
        "--port", help="호스트 노출 포트 (쉼표 구분: 3000,8080)"
    )
    parser.add_argument(
        "--nvim",
        action="store_true",
        default=True,
        help="호스트 Neovim 설정 마운트 (기본값: True)",
    )
    parser.add_argument(
        "--docker-socket",
        action="store_true",
        help="호스트 Docker 소켓 바인딩 (Docker-outside-of-Docker)",
    )
    parser.add_argument(
        "--ai",
        action="store_true",
        help="컨테이너 내부 AI Agent CLI 사전 설치 (Claude / Antigravity)",
    )
    parser.add_argument(
        "--no-install",
        action="store_true",
        help="컨테이너 기동 시 패키지 의존성 자동 설치 건너뛰기",
    )
    parser.add_argument(
        "-i",
        "--interactive",
        action="store_true",
        help="강제 대화형 마법사 모드 실행",
    )
    parser.add_argument(
        "-y",
        "--yes",
        action="store_true",
        help="확인 프롬프트 생략 (기본값으로 즉시 생성)",
    )

    args = parser.parse_args()

    # 템플릿 디렉터리 경로 파악
    dotconfig_repo = os.environ.get(
        "DOTCONFIG_REPO", os.path.expanduser("~/dev/dotconfig")
    )
    templates_root = os.path.join(dotconfig_repo, "devcontainers")

    available_templates = [
        d
        for d in os.listdir(templates_root)
        if os.path.isdir(os.path.join(templates_root, d))
        and os.path.exists(os.path.join(templates_root, d, ".devcontainer"))
    ]

    target_dir = os.getcwd()

    # 1. 템플릿 미지정 시 대화형 선택
    template_name = args.template
    is_interactive = (
        args.interactive
        or (not args.yes and sys.stdin.isatty() and not template_name)
        or (not args.yes and sys.stdin.isatty() and not args.version)
    )

    if not template_name:
        if not sys.stdin.isatty():
            print(
                f"{C_RED}Error: 템플릿 이름을 지정해주세요. 사용 가능한 템플릿: {', '.join(available_templates)}{C_RESET}"
            )
            sys.exit(1)
        print(f"\n{C_BOLD}🚀 차세대 Dev Container 맞춤형 생성기 (v2.0){C_RESET}")
        opts = [
            f"{t} ({TEMPLATE_METADATA.get(t, {}).get('title', '')})"
            for t in available_templates
        ]
        idx, _ = prompt_select(
            "프로젝트에 맞는 Dev Container 템플릿을 선택하세요:", opts
        )
        template_name = available_templates[idx]

    if template_name not in available_templates:
        print(
            f"{C_RED}Error: 존재하지 않는 템플릿입니다: '{template_name}'{C_RESET}"
        )
        print(f"사용 가능한 템플릿: {', '.join(available_templates)}")
        sys.exit(1)

    template_dir = os.path.join(templates_root, template_name)
    meta = TEMPLATE_METADATA.get(template_name, {})

    # 2. 대화형 모드 진행 (Interactive Wizard)
    if is_interactive and not args.yes:
        print(
            f"\n{C_GREEN}✓ 선택된 템플릿: {C_BOLD}{template_name}{C_RESET} {C_DIM}({meta.get('title', '')}){C_RESET}"
        )

        # (1) 버전 선택 (공식 API 동적 조회 + 로컬 캐시 연동)
        print(
            f"{C_DIM}⏳ 최신 버전 정보를 실시간 조회 중입니다...{C_RESET}",
            end="\r",
        )
        versions = get_template_versions(template_name)
        print(" " * 50, end="\r")  # 이전 줄 지우기

        version_opts = versions + ["직접 입력"]
        v_idx, chosen_ver = prompt_select(
            f"{meta.get('title', template_name)} SDK 버전을 선택하세요:",
            version_opts,
            default_idx=0,
        )
        if chosen_ver == "직접 입력":
            selected_version = prompt_text(
                "원하는 정확한 버전을 입력하세요 (예: 20, 3.11 등):",
                versions[0].split()[0],
            )
        else:
            selected_version = chosen_ver

        # (2) 패키지 매니저 선택
        pkg_opts = meta.get("pkg_managers", ["기본값"])
        if len(pkg_opts) > 1:
            _, selected_pkg = prompt_select(
                "사용할 패키지 매니저를 선택하세요:", pkg_opts, default_idx=0
            )
        else:
            selected_pkg = pkg_opts[0]

        # (3) 로컬 DB 사이드카 선택
        db_choices = [
            ("postgres", "PostgreSQL 16 (기본 포트: 5432)", False),
            ("redis", "Redis 7 (기본 포트: 6379)", False),
            ("mysql", "MySQL 8.4 LTS (기본 포트: 3306)", False),
            ("mongo", "MongoDB 7 (기본 포트: 27017)", False),
        ]
        selected_dbs = prompt_multiselect(
            "함께 띄울 로컬 데이터베이스가 있나요?", db_choices
        )

        # (4) 노출 포트 입력
        default_ports = meta.get("default_port", [])
        def_port_str = ", ".join(map(str, default_ports))
        port_input = prompt_text(
            "호스트에 노출할 애플리케이션 포트 (쉼표 구분):", def_port_str
        )
        ports = []
        if port_input:
            for p in re.split(r"[\s,]+", port_input):
                if p.isdigit():
                    ports.append(int(p))

        # (5) 부가 기능 옵션
        print(f"\n{C_CYAN}⚙️ 추가 환경 옵션을 설정합니다:{C_RESET}")
        enable_nvim = prompt_confirm(
            "호스트 Neovim 설정을 컨테이너에 자동 마운트할까요?",
            default=True,
        )
        enable_docker = prompt_confirm(
            "호스트 Docker 소켓을 공유할까요? (Docker-in-Docker 필요 시)",
            default=False,
        )
        enable_ai = prompt_confirm(
            "컨테이너 내부에 AI Agent CLI(Claude / Antigravity)를 탑재할까요?",
            default=False,
        )
        auto_deps = prompt_confirm(
            "컨테이너 기동 시 패키지 의존성을 자동 설치할까요?", default=True
        )

    # 3. 비대화형 플래그 모드 (Scriptable One-liner)
    else:
        versions = get_template_versions(template_name)
        selected_version = (
            args.version if args.version else versions[0].split()[0]
        )
        selected_pkg = (
            args.pkg if args.pkg else meta.get("default_pkg", "default")
        )
        selected_dbs = (
            [d.strip() for d in args.db.split(",") if d.strip()]
            if args.db
            else []
        )
        ports = []
        if args.port:
            for p in re.split(r"[\s,]+", args.port):
                if p.isdigit():
                    ports.append(int(p))
        else:
            ports = meta.get("default_port", [])

        enable_nvim = args.nvim
        enable_docker = args.docker_socket
        enable_ai = args.ai
        auto_deps = not args.no_install

    # 4. 기존 .devcontainer 존재 여부 확인
    dest_dir = os.path.join(target_dir, ".devcontainer")
    if os.path.exists(dest_dir):
        if not args.yes:
            if not prompt_confirm(
                f"현재 디렉터리에 .devcontainer가 이미 존재합니다. 덮어쓸까요?",
                default=False,
            ):
                print(f"{C_YELLOW}생성이 중단되었습니다.{C_RESET}")
                sys.exit(0)
        shutil.rmtree(dest_dir, ignore_errors=True)

    # 5. 커스텀 devcontainer 빌드 및 작성
    customize_devcontainer(
        template_dir=template_dir,
        target_dir=target_dir,
        selected_version=selected_version,
        pkg_manager=selected_pkg,
        selected_dbs=selected_dbs,
        ports=ports,
        enable_nvim=enable_nvim,
        enable_docker_socket=enable_docker,
        enable_ai_cli=enable_ai,
        auto_install_deps=auto_deps,
    )

    # 6. 완료 안내 출력
    print(f"\n{C_GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━{C_RESET}")
    print(f"{C_BOLD}{C_GREEN}✓ 맞춤형 Dev Container 생성이 완료되었습니다!{C_RESET}")
    print(
        f"  • 템플릿: {C_BOLD}{template_name}{C_RESET} ({meta.get('title', '')})"
    )
    print(f"  • SDK 버전: {C_BOLD}{selected_version}{C_RESET}")
    print(f"  • 패키지 매니저: {selected_pkg}")
    if selected_dbs:
        print(
            f"  • 로컬 데이터베이스: {C_CYAN}{', '.join(selected_dbs)}{C_RESET} (Multi-service Compose 모드)"
        )
    if ports:
        print(f"  • 노출 포트: {ports}")
    print(f"  • 한국 타임존: Asia/Seoul 적용")
    print(
        f"{C_GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━{C_RESET}"
    )
    print(f"\n{C_BOLD}시작 방법:{C_RESET}")
    print(
        f"  1. Neovim: 'nvim .' 실행 후 {C_CYAN}<Space>Ds{C_RESET} (Start) ➡️ {C_CYAN}<Space>Da{C_RESET} (Attach)"
    )
    print(
        f"  2. Antigravity IDE: 명령 팔레트에서 {C_CYAN}Dev Containers: Reopen in Container{C_RESET}"
    )
    print()


if __name__ == "__main__":
    main()
