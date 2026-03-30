#!/usr/bin/env bash

# This script automates the build and push process for the custom Ultralytics Docker image.
# It dynamically detects the Ultralytics and PyTorch versions to create versioned tags.
#
# USAGE:
#   Run this script from the root of the ultralytics project directory.
#   ./build_docker_image.sh

# Exit immediately if a command exits with a non-zero status.
set -e
# Treat unset variables as an error when substituting.
set -u
# Return value of a pipeline is the value of the last command to exit with a non-zero status.
set -o pipefail

# --- Configuration ---
# Your Docker Hub username.
readonly DOCKER_USERNAME="neilpandya"
# The name of the image on Docker Hub.
readonly IMAGE_NAME="ultralytics"
# Path to the Dockerfile.
readonly DOCKERFILE_PATH="docker/Dockerfile-ampere-zen3"
# The hardware-specific architecture tag for this build.
readonly ARCH_TAG="ampere-zen3"

echo "--- Starting Ultralytics Docker Build Script ---"

# --- Dynamic Version Detection ---
echo "🔍 Detecting software versions..."

# Find Ultralytics version from the project's __init__.py file.
# Search for the line that starts with '__version__ = ' to get an exact match.
# - grep '^__version__ = ': Finds the exact definition line.
# - cut -d '"' -f 2: Splits the line by the double-quote and gets the second field.
ULTRALYTICS_VERSION=$(grep '^__version__ = ' ultralytics/__init__.py | cut -d '"' -f 2)
if [ -z "$ULTRALYTICS_VERSION" ]; then
    echo "❌ Error: Could not find Ultralytics version in ultralytics/__init__.py." >&2
    exit 1
fi

# Find PyTorch version from the FROM instruction in the Dockerfile.
# - grep 'FROM pytorch/pytorch:': Finds the base image line.
# - head -n 1: Ensures we only get the first match (for multi-stage builds).
# - cut -d ':' -f 2: Splits by the colon and gets the version part (e.g., '2.9.1-cuda...').
# - cut -d '-' -f 1: Splits by the hyphen and gets the clean version number (e.g., '2.9.1').
PYTORCH_VERSION=$(grep 'FROM pytorch/pytorch:' "$DOCKERFILE_PATH" | head -n 1 | cut -d ':' -f 2 | cut -d '-' -f 1)
if [ -z "$PYTORCH_VERSION" ]; then
    echo "❌ Error: Could not find PyTorch version in $DOCKERFILE_PATH." >&2
    exit 1
fi

echo "Ultralytics Version: $ULTRALYTICS_VERSION"
echo "PyTorch Version:     $PYTORCH_VERSION"
echo

# --- Define Image Tags ---
# The most specific tag, including all version and architecture info.
readonly FULL_VERSION_TAG="${DOCKER_USERNAME}/${IMAGE_NAME}:${ULTRALYTICS_VERSION}-torch${PYTORCH_VERSION}-${ARCH_TAG}"
# The general 'latest' tag for this specific export-focused build.
readonly LATEST_TAG="${DOCKER_USERNAME}/${IMAGE_NAME}:latest"

echo "--- Tags to be built and pushed ---"
echo "  1. ${FULL_VERSION_TAG}"
echo "  2. ${LATEST_TAG}"
echo

# --- Docker Commands ---
echo "🐳 Starting Docker build..."
# Build once with the most specific tag. The --load flag is crucial to make the image
# available to the local Docker daemon for the subsequent 'docker tag' commands.
docker buildx build -f "$DOCKERFILE_PATH" -t "${FULL_VERSION_TAG}" . --load

echo "🏷️  Adding additional tags to the image..."
docker tag "${FULL_VERSION_TAG}" "${LATEST_TAG}"

echo "--- Local build complete! Images are ready for scheduled push. ---"
