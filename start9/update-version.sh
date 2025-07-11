#!/bin/bash

set -euo pipefail

# update-version.sh - Updates manifest.yaml and Dockerfile with current Immich version and changelog

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

echo "Updating Start9 package with current Immich version..."

# Function to get latest release version from GitHub
get_latest_version() {
    local repo="immich-app/immich"

    # Try GitHub CLI first (preferred)
    if command -v gh &> /dev/null; then
        echo "📡 Fetching latest release using GitHub CLI..." >&2
        gh api repos/$repo/releases/latest --jq '.tag_name' 2>/dev/null | sed 's/^v//'
    else
        # Fallback to curl with GitHub API
        echo "📡 Fetching latest release using GitHub API..." >&2
        curl -s "https://api.github.com/repos/$repo/releases/latest" | \
            grep '"tag_name":' | \
            sed 's/.*"tag_name": "v\?\([^"]*\)".*/\1/'
    fi
}

# Function to get release information from GitHub
get_release_info() {
    local repo="immich-app/immich"
    local version="$1"

    # Try GitHub CLI first (preferred)
    if command -v gh &> /dev/null; then
        echo "📖 Fetching release info using GitHub CLI..." >&2
        gh api repos/$repo/releases/tags/v$version --jq '{body: .body, published_at: .published_at}' 2>/dev/null
    else
        # Fallback to curl with GitHub API
        echo "📖 Fetching release info using GitHub API..." >&2
        curl -s "https://api.github.com/repos/$repo/releases/tags/v$version" | \
            jq -r '{body: .body, published_at: .published_at}'
    fi
}

# Function to format and generate release notes from GitHub release
get_release_notes() {
    local version="$1"
    local release_info_json="$2"

    # Extract release body and date
    local release_body=""
    local published_date=""

    if [ -n "$release_info_json" ] && [ "$release_info_json" != "null" ]; then
        # Parse JSON using jq if available, otherwise fallback to basic parsing
        if command -v jq &> /dev/null; then
            release_body=$(echo "$release_info_json" | jq -r '.body // ""')
            published_date=$(echo "$release_info_json" | jq -r '.published_at // ""')
        else
            # Basic parsing without jq
            release_body=$(echo "$release_info_json" | sed -n 's/.*"body": *"\([^"]*\)".*/\1/p' | sed 's/\\n/\n/g')
            published_date=$(echo "$release_info_json" | sed -n 's/.*"published_at": *"\([^"]*\)".*/\1/p')
        fi
    fi

    # Format the date if available
    local date_str=""
    if [ -n "$published_date" ]; then
        date_str=" (Released: $(date -d "$published_date" "+%B %d, %Y" 2>/dev/null || echo "$published_date"))"
    fi

    # Generate comprehensive release notes
    cat <<EOF
Start9 packaging for Immich v${version}${date_str}

IMMICH RELEASE NOTES:
$(if [ -n "$release_body" ] && [ "$release_body" != "null" ] && [ "$release_body" != "" ]; then
    # Clean up and format the release body
    echo "$release_body" | sed 's/\\n/\n/g' | sed 's/^/  /'
else
    echo "  See full release notes at: https://github.com/immich-app/immich/releases/tag/v${version}"
fi)

START9 PACKAGE UPDATES:
- Updated to Immich server v${version}

EOF
}

# Function to update manifest.yaml
update_manifest() {
    local version="$1"
    local release_notes="$2"
    local manifest_file="$SCRIPT_DIR/manifest.yaml"

    if [ ! -f "$manifest_file" ]; then
        echo "Error: manifest.yaml not found at $manifest_file" >&2
        exit 1
    fi

    echo "Updating manifest.yaml with version $version..."

    # Create a temporary file for the updated manifest
    local temp_file=$(mktemp)

    # Use yq to update version and release notes, preserving formatting
    yq eval ".version = \"$version\"" "$manifest_file" > "$temp_file"

    # Update release notes (escape special characters for yq)
    local escaped_notes=$(printf '%s\n' "$release_notes" | sed 's/"/\\"/g' | sed 's/$/\\n/' | tr -d '\n' | sed 's/\\n$//')
    yq eval ".release-notes = \"$escaped_notes\"" "$temp_file" > "$temp_file.tmp"
    mv "$temp_file.tmp" "$temp_file"

    # Replace original file
    mv "$temp_file" "$manifest_file"

    echo "✅ Updated manifest.yaml"
}

# Function to update Dockerfile
update_dockerfile() {
    local version="$1"
    local dockerfile="$SCRIPT_DIR/Dockerfile"

    if [ ! -f "$dockerfile" ]; then
        echo "Error: Dockerfile not found at $dockerfile" >&2
        exit 1
    fi

    echo "Updating Dockerfile with version $version..."

    # Update the FROM line to use the specific version
    sed -i.bak "s|FROM ghcr.io/immich-app/immich-server:.*|FROM ghcr.io/immich-app/immich-server:v$version|" "$dockerfile"

    # Remove backup file
    rm -f "$dockerfile.bak"

    echo "✅ Updated Dockerfile"
}

# Function to update docker-compose.yml
update_docker_compose() {
    local version="$1"
    local compose_file="$SCRIPT_DIR/docker-compose.yml"

    if [ ! -f "$compose_file" ]; then
        echo "Error: docker-compose.yml not found at $compose_file" >&2
        exit 1
    fi

    echo "Updating docker-compose.yml with version $version..."

    # Update machine learning image version
    sed -i.bak "s|ghcr.io/immich-app/immich-machine-learning:.*|ghcr.io/immich-app/immich-machine-learning:v$version|" "$compose_file"

    # Remove backup file
    rm -f "$compose_file.bak"

    echo "✅ Updated docker-compose.yml"
}

# Function to validate required dependencies
check_dependencies() {
    local missing_deps=()

    if ! command -v yq &> /dev/null; then
        missing_deps+=("yq")
    fi

    # Check for either gh CLI or curl+jq
    if ! command -v gh &> /dev/null; then
        if ! command -v curl &> /dev/null; then
            missing_deps+=("curl (or gh CLI)")
        fi
        if ! command -v jq &> /dev/null; then
            echo "⚠️  Warning: jq not found. JSON parsing will use basic sed (less reliable)" >&2
        fi
    fi

    if [ ${#missing_deps[@]} -gt 0 ]; then
        echo "Error: Missing required dependencies: ${missing_deps[*]}" >&2
        echo "Please install missing tools or run: ./prepare.sh" >&2
        echo "" >&2
        echo "Installation commands:" >&2
        for dep in "${missing_deps[@]}"; do
            case "$dep" in
                "yq") echo "  - yq: https://github.com/mikefarah/yq" >&2 ;;
                "curl"*) echo "  - curl: brew install curl (or your package manager)" >&2 ;;
                "gh") echo "  - GitHub CLI: brew install gh" >&2 ;;
            esac
        done
        exit 1
    fi
}

# Main execution
main() {
    echo "🔄 Start9 Immich Package Version Updater"
    echo "========================================"

    # Check dependencies
    check_dependencies

    # Get latest version from GitHub
    local latest_version
    latest_version=$(get_latest_version)

    if [ -z "$latest_version" ]; then
        echo "❌ Failed to fetch latest version from GitHub" >&2
        exit 1
    fi

    echo "📦 Latest Immich version: $latest_version"

    # Get release information
    local release_info
    release_info=$(get_release_info "$latest_version")

    # Generate release notes with GitHub data
    local release_notes
    release_notes=$(get_release_notes "$latest_version" "$release_info")

    # Update files
    update_manifest "$latest_version" "$release_notes"
    update_dockerfile "$latest_version"
    update_docker_compose "$latest_version"

    echo ""
    echo "✅ Successfully updated Start9 package to Immich v$latest_version"
    echo ""
    echo "Updated files:"
    echo "  - manifest.yaml (version and release notes)"
    echo "  - Dockerfile (base image version)"
    echo "  - docker-compose.yml (service image versions)"
    echo ""
    echo "Next steps:"
    echo "  1. Review the changes: git diff"
    echo "  2. Test the package: ./test.sh"
    echo "  3. Build and deploy: docker build -t immich-start9 ."
}

# Run main function
main "$@"
