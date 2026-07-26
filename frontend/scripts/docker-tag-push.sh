#!/bin/bash

# Faraja Frontend - Tag & Push All Versions
set -e

IMAGE="faraja-frontend"
DOCKER_USERNAME="teqiee"

echo "Tag & Push Frontend Image"
echo ""

# Check Docker
if ! docker info &>/dev/null; then
    echo "ERROR: Docker is not running"
    exit 1
fi

# Check login
if ! docker system info | grep -q "Username"; then
    echo "ERROR: Not logged in to Docker Hub"
    echo "Run: docker login"
    exit 1
fi

# Show existing images
echo "Images found:"
docker images | grep ${IMAGE}

# Tag and push latest
if [[ -n "$(docker images -q ${IMAGE}:latest 2>/dev/null)" ]]; then
    echo ""
    echo "[1/2] Tagging and pushing latest..."
    docker tag ${IMAGE}:latest ${DOCKER_USERNAME}/${IMAGE}:latest
    docker push ${DOCKER_USERNAME}/${IMAGE}:latest
    echo "Pushed: ${DOCKER_USERNAME}/${IMAGE}:latest"
fi

# Get version tag from build
VERSION=$(docker images --format "{{.Tag}}" ${IMAGE} | grep -v "latest" | head -1)

if [[ -n "$VERSION" ]]; then
    echo ""
    echo "[2/2] Tagging and pushing version: ${VERSION}..."
    docker tag ${IMAGE}:${VERSION} ${DOCKER_USERNAME}/${IMAGE}:${VERSION}
    docker push ${DOCKER_USERNAME}/${IMAGE}:${VERSION}
    echo "Pushed: ${DOCKER_USERNAME}/${IMAGE}:${VERSION}"
fi

echo ""
echo "Complete!"
echo ""
echo "Images pushed:"
echo "  ${DOCKER_USERNAME}/${IMAGE}:latest"
[[ -n "$VERSION" ]] && echo "  ${DOCKER_USERNAME}/${IMAGE}:${VERSION}"
echo ""
echo "Pull:  docker pull ${DOCKER_USERNAME}/${IMAGE}:latest"
echo "Run:   docker run -d -p 3001:3001 ${DOCKER_USERNAME}/${IMAGE}:latest"