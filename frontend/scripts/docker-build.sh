#!/bin/bash

# Faraja Frontend - Docker Build Script
set -e

IMAGE="faraja-frontend"
VERSION=$(date +%Y%m%d-%H%M%S)

echo "Building Frontend Image"

# Check Docker
if ! docker info &>/dev/null; then
    echo "ERROR: Docker is not running"
    exit 1
fi

echo "Building: ${IMAGE}:${VERSION}"
docker build -t ${IMAGE}:${VERSION} -t ${IMAGE}:latest .

echo ""
echo "Build complete!"
echo ""
echo "Images:"
docker images | grep ${IMAGE}
echo ""
echo "Run: docker run -d -p 3001:3001 ${IMAGE}:latest"