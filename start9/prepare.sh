#!/bin/bash

set -euo pipefail

# prepare.sh - Setup build environment for Debian system
# This script prepares the environment for building Start9 packages

echo "Setting up Start9 build environment..."

# Update package lists
apt-get update

# Install essential build tools
apt-get install -y \
    curl \
    wget \
    git \
    build-essential \
    ca-certificates \
    gnupg \
    lsb-release

# Install Docker if not present
if ! command -v docker &> /dev/null; then
    echo "Installing Docker..."
    curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io
fi

# Install Docker Buildx if not present
if ! docker buildx version &> /dev/null; then
    echo "Installing Docker Buildx..."
    mkdir -p ~/.docker/cli-plugins/
    curl -SL https://github.com/docker/buildx/releases/latest/download/buildx-$(uname -s | tr '[:upper:]' '[:lower:]')-$(uname -m) -o ~/.docker/cli-plugins/docker-buildx
    chmod +x ~/.docker/cli-plugins/docker-buildx
fi

# Install yq for YAML processing
if ! command -v yq &> /dev/null; then
    echo "Installing yq..."
    wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
    chmod +x /usr/local/bin/yq
fi

# Install Start9 SDK
if ! command -v start-sdk &> /dev/null; then
    echo "Installing Start9 SDK..."
    curl -sSL https://start9.com/install/sdk | bash
fi

# Verify installations
echo "Verifying installations..."
docker --version
docker buildx version
yq --version
start-sdk --version

echo "Build environment setup completed successfully!"