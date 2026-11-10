FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive

# 기본 도구 및 런타임 설치 (Node.js, Python, OpenJDK 17, clang-format, curl, unzip)
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    unzip \
    clang-format \
    openjdk-17-jre-headless \
    nodejs \
    npm \
    python3 \
    python3-pip \
    && rm -rf /var/lib/apt/lists/*

# 1. Prettier (JS, TS, JSON, Markdown, CSS, SCSS)
RUN npm install -g --no-fund --no-audit prettier

# 2. Ruff & Black (Python)
RUN pip install --no-cache-dir --break-system-packages ruff black

# 3. Google Java Format (Java)
RUN curl -fsSL -o /usr/local/lib/google-java-format.jar \
    https://github.com/google/google-java-format/releases/download/v1.24.0/google-java-format-1.24.0-all-deps.jar && \
    printf '#!/bin/sh\nexec java -jar /usr/local/lib/google-java-format.jar "$@"\n' > /usr/local/bin/google-java-format && \
    chmod +x /usr/local/bin/google-java-format

# 4. StyLua (Lua) - 아키텍처 자동 감지 (arm64 / x86_64)
RUN ARCH=$(dpkg --print-architecture) && \
    if [ "$ARCH" = "arm64" ]; then STYLUA_ARCH="linux-aarch64"; else STYLUA_ARCH="linux-x86_64"; fi && \
    curl -fsSL -o /tmp/stylua.zip "https://github.com/JohnnyMorganz/StyLua/releases/download/v2.0.2/stylua-${STYLUA_ARCH}.zip" && \
    unzip /tmp/stylua.zip -d /usr/local/bin && \
    rm -f /tmp/stylua.zip && \
    chmod +x /usr/local/bin/stylua

WORKDIR /workspace
