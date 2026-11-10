#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE_NAME="dotconfig-formatter:latest"

echo "[INFO] Building formatter Docker image: ${IMAGE_NAME}..."
docker build -t "${IMAGE_NAME}" "${SCRIPT_DIR}"
echo "[OK] Formatter image built successfully: ${IMAGE_NAME}"
