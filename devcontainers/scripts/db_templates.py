"""Dev Container 로컬 데이터베이스 사이드카 모듈 정의 및 Docker Compose 변환기.

PostgreSQL, Redis, MySQL, MongoDB 등의 로컬 데이터베이스를 선택 시
단일 컨테이너 구조를 멀티 컨테이너 docker-compose.yml 구조로 자동 승격합니다.
외부 의존성 없이 표준 라이브러리만으로 YAML 렌더링을 지원합니다.
"""

# 지원되는 데이터베이스 사이드카 카탈로그
SUPPORTED_DATABASES = {
    "postgres": {
        "name": "PostgreSQL 16",
        "default_port": 5432,
        "image": "postgres:16-alpine",
        "env": {
            "POSTGRES_USER": "devuser",
            "POSTGRES_PASSWORD": "devpassword",
            "POSTGRES_DB": "devdb",
        },
        "ports": ["5432:5432"],
        "volume": "postgres-data:/var/lib/postgresql/data",
        "volume_name": "postgres-data",
    },
    "redis": {
        "name": "Redis 7",
        "default_port": 6379,
        "image": "redis:7-alpine",
        "env": {},
        "ports": ["6379:6379"],
        "volume": "redis-data:/data",
        "volume_name": "redis-data",
    },
    "mysql": {
        "name": "MySQL 8.4 LTS",
        "default_port": 3306,
        "image": "mysql:8.4",
        "env": {
            "MYSQL_ROOT_PASSWORD": "devpassword",
            "MYSQL_DATABASE": "devdb",
            "MYSQL_USER": "devuser",
            "MYSQL_PASSWORD": "devpassword",
        },
        "ports": ["3306:3306"],
        "volume": "mysql-data:/var/lib/mysql",
        "volume_name": "mysql-data",
    },
    "mongo": {
        "name": "MongoDB 7",
        "default_port": 27017,
        "image": "mongo:7",
        "env": {
            "MONGO_INITDB_ROOT_USERNAME": "devuser",
            "MONGO_INITDB_ROOT_PASSWORD": "devpassword",
        },
        "ports": ["27017:27017"],
        "volume": "mongo-data:/data/db",
        "volume_name": "mongo-data",
    },
}


def render_compose_yaml(
    base_image: str = "",
    dockerfile: str = "",
    selected_dbs: list = None,
    custom_ports: list = None,
) -> str:
    """단일 컨테이너 정보와 선택된 DB 사이드카들을 조합하여 완전한 docker-compose.yml 텍스트를 생성합니다."""
    selected_dbs = selected_dbs or []
    lines = ["version: '3.8'", "", "services:", "  app:"]

    if dockerfile:
        lines.append(f"    build:")
        lines.append(f"      context: .")
        lines.append(f"      dockerfile: {dockerfile}")
    elif base_image:
        lines.append(f"    image: {base_image}")
    else:
        lines.append("    image: mcr.microsoft.com/devcontainers/base:ubuntu")

    lines.append("    restart: unless-stopped")
    lines.append("    volumes:")
    lines.append("      - ..:/workspaces/${localWorkspaceFolderBasename}:cached")

    if custom_ports:
        lines.append("    ports:")
        for port in custom_ports:
            lines.append(f'      - "{port}:{port}"')

    lines.append("    # 백그라운드 무한 대기 실행")
    lines.append("    command: sleep infinity")

    volumes_to_create = []

    # 선택된 DB 서비스 추가
    for db_key in selected_dbs:
        if db_key not in SUPPORTED_DATABASES:
            continue
        cfg = SUPPORTED_DATABASES[db_key]
        lines.append("")
        lines.append(f"  {db_key}:")
        lines.append(f"    image: {cfg['image']}")
        lines.append("    restart: unless-stopped")

        if cfg["env"]:
            lines.append("    environment:")
            for k, v in cfg["env"].items():
                lines.append(f"      {k}: {v}")

        if cfg["ports"]:
            lines.append("    ports:")
            for p in cfg["ports"]:
                lines.append(f'      - "{p}"')

        if cfg["volume"]:
            lines.append("    volumes:")
            lines.append(f"      - {cfg['volume']}")
            volumes_to_create.append(cfg["volume_name"])

    if volumes_to_create:
        lines.append("")
        lines.append("volumes:")
        for v in volumes_to_create:
            lines.append(f"  {v}:")

    return "\n".join(lines) + "\n"
