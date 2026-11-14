#!/usr/bin/env python3
"""Dev Container SDK/언어 최신 버전 동적 수집기 및 스마트 캐시 엔진.

공식 릴리스 API를 통해 활성 최신 버전 3~4개를 조회하고,
성공 시 로컬 캐시(~/.cache/dotconfig/devcontainer-versions.json)에 자동 저장합니다.
오프라인 또는 타임아웃 시 캐시된 버전 또는 안전한 Fallback 목록을 반환합니다.
"""

from datetime import datetime, timezone
import json
import os
import sys
import urllib.request

TIMEOUT_SECONDS = 1.5

CACHE_DIR = os.path.expanduser("~/.cache/dotconfig")
CACHE_FILE = os.path.join(CACHE_DIR, "devcontainer-versions.json")

# 오프라인 및 최초 실행 시 사용할 안전한 기본 Fallback 버전 목록
DEFAULT_FALLBACKS = {
    "node-ts": ["22 (LTS)", "20 (LTS - 권장)", "18 (Maintenance)"],
    "python-ai": ["3.12 (권장)", "3.11", "3.10"],
    "go-backend": ["1.23 (권장)", "1.22", "1.21"],
    "java": ["21 (LTS - 권장)", "17 (LTS)", "11 (LTS)"],
    "rust": ["stable (권장)", "nightly", "beta"],
    "react-native": ["20 (Node.js LTS - 권장)", "18 (Node.js LTS)"],
    "42-c-valgrind": ["Ubuntu 24.04 (Noble)", "Ubuntu 22.04 (Jammy)"],
    "devops-cloud": ["1.9 (Terraform LTS)", "1.8", "1.7"],
    "fullstack-db": ["20 (Node.js LTS)", "18 (Node.js LTS)"],
}


def _http_get_json(url: str, timeout: float = TIMEOUT_SECONDS):
    """표준 라이브러리 기반 경량 JSON GET 요청 (User-Agent 포함)"""
    req = urllib.request.Request(
        url,
        headers={"User-Agent": "Dotconfig-Devcontainer-Init/2.0"},
    )
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        return json.loads(resp.read().decode("utf-8"))


def fetch_node_versions() -> list[str]:
    """Node.js 공식 dist 인덱스에서 최신 LTS 및 Current 버전 3개 추출"""
    data = _http_get_json("https://nodejs.org/dist/index.json")
    results = []
    seen_majors = set()

    for item in data:
        ver = item.get("version", "").lstrip("v")
        major = ver.split(".")[0]
        lts = item.get("lts")

        if major not in seen_majors:
            seen_majors.add(major)
            if lts:
                label = f"{major} (LTS: {lts})"
            else:
                label = f"{major} (Current)"
            results.append(label)
            if len(results) >= 3:
                break

    return results if results else DEFAULT_FALLBACKS["node-ts"]


def fetch_python_versions() -> list[str]:
    """endoflife.date API에서 EOL 이전 활성 Python 버전 추출"""
    data = _http_get_json("https://endoflife.date/api/python.json")
    results = []
    now = datetime.now(timezone.utc).strftime("%Y-%m-%d")

    for item in data:
        cycle = item.get("cycle", "")
        eol = item.get("eol", "")
        # eol이 미래이거나 아직 지원 중인 버전
        if isinstance(eol, str) and eol >= now:
            results.append(cycle)
            if len(results) >= 4:
                break

    if results:
        # 첫 번째는 최신, 두 번째는 안정 권장
        labeled = [f"{results[0]} (Latest)"]
        if len(results) > 1:
            labeled.append(f"{results[1]} (권장)")
        for r in results[2:]:
            labeled.append(r)
        return labeled
    return DEFAULT_FALLBACKS["python-ai"]


def fetch_go_versions() -> list[str]:
    """go.dev 공식 다운로드 목록에서 최신 3개 안정 버전 추출"""
    data = _http_get_json("https://go.dev/dl/?mode=json")
    results = []
    seen = set()

    for item in data:
        ver = item.get("version", "").replace("go", "")
        parts = ver.split(".")
        if len(parts) >= 2:
            major_minor = f"{parts[0]}.{parts[1]}"
            if major_minor not in seen:
                seen.add(major_minor)
                results.append(major_minor)
                if len(results) >= 3:
                    break

    if results:
        return [f"{results[0]} (권장)"] + results[1:]
    return DEFAULT_FALLBACKS["go-backend"]


def load_cached_versions() -> dict:
    """로컬 캐시 파일 로드"""
    if os.path.exists(CACHE_FILE):
        try:
            with open(CACHE_FILE, "r", encoding="utf-8") as f:
                return json.load(f)
        except Exception:
            return {}
    return {}


def save_cached_versions(versions: dict):
    """로컬 캐시 파일 저장"""
    try:
        os.makedirs(CACHE_DIR, exist_ok=True)
        with open(CACHE_FILE, "w", encoding="utf-8") as f:
            json.dump(versions, f, indent=2, ensure_ascii=False)
    except Exception:
        pass


def get_template_versions(template_name: str) -> list[str]:
    """주어진 템플릿의 최신 버전 목록을 반환합니다.

    1. 온라인 조회를 시도하여 성공하면 캐시 갱신 후 반환.
    2. 실패(타임아웃/오프라인) 시 로컬 캐시 조회.
    3. 캐시 부재 시 내장 DEFAULT_FALLBACKS 반환.
    """
    cached = load_cached_versions()

    fetchers = {
        "node-ts": fetch_node_versions,
        "react-native": fetch_node_versions,
        "fullstack-db": fetch_node_versions,
        "python-ai": fetch_python_versions,
        "go-backend": fetch_go_versions,
    }

    fetcher = fetchers.get(template_name)
    if fetcher:
        try:
            fresh_versions = fetcher()
            if fresh_versions:
                # 온라인 조회 성공: 로컬 캐시 자동 업데이트
                cached[template_name] = fresh_versions
                save_cached_versions(cached)
                return fresh_versions
        except Exception:
            pass  # 타임아웃 또는 네트워크 오류 시 캐시 사용

    # 캐시에 저장된 버전이 있으면 사용
    if template_name in cached and cached[template_name]:
        return cached[template_name]

    # 최종 fallback
    return DEFAULT_FALLBACKS.get(template_name, ["default"])


if __name__ == "__main__":
    target = sys.argv[1] if len(sys.argv) > 1 else "node-ts"
    versions = get_template_versions(target)
    print(f"Template: {target}")
    print("Versions:", versions)
