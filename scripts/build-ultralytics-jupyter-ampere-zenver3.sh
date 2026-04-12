#!/usr/bin/env bash

# Enable BuildKit
export DOCKER_BUILDKIT=1

set -e
set -u
set -o pipefail

# --- Configuration ---
readonly DOCKER_USERNAME="neilpandya"
readonly IMAGE_NAME="ultralytics"
readonly DOCKERFILE_PATH="docker/Dockerfile-jupyter-ampere-zenver3"
readonly ARCH_TAG="jupyter-ampere-zen3"

echo "--- Starting Optimized Ultralytics Build ---"

# --- Version Detection ---
ULTRALYTICS_VERSION=$(grep '^__version__ = ' ultralytics/__init__.py | cut -d '"' -f 2)
PYTORCH_VERSION="2.11.0"

readonly FULL_VERSION_TAG="${DOCKER_USERNAME}/${IMAGE_NAME}:${ULTRALYTICS_VERSION}-torch${PYTORCH_VERSION}-${ARCH_TAG}"
readonly LATEST_TAG="${DOCKER_USERNAME}/${IMAGE_NAME}:latest"

# --- Build the Image ---
echo "🐳 Building Docker image using bespoke PyTorch..."
# We no longer use --target export because we aren't pulling a wheel out.
# We build the image directly.
docker buildx build \
    -f "$DOCKERFILE_PATH" \
    -t "${FULL_VERSION_TAG}" \
    --load .

echo "✅ Build complete!"
echo "Tags created:"
echo "  - ${FULL_VERSION_TAG}"
