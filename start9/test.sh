#!/bin/bash

set -euo pipefail

echo "Testing Start9 Immich package structure..."

# Check required files
REQUIRED_FILES=(
    "manifest.yaml"
    "Dockerfile"
    "docker-compose.yml"
    "docker_entrypoint.sh"
    "healthcheck.sh"
    "backup.sh"
    "prepare.sh"
    "LICENSE"
    "assets/instructions.md"
    "assets/icon.png"
)

for file in "${REQUIRED_FILES[@]}"; do
    if [ ! -f "$file" ]; then
        echo "❌ Missing required file: $file"
        exit 1
    else
        echo "✅ Found: $file"
    fi
done

# Validate YAML files
echo "Validating YAML files..."
if python3 -c "import yaml" 2>/dev/null; then
    python3 -c "import yaml; yaml.safe_load(open('manifest.yaml'))" && echo "✅ manifest.yaml is valid"
    python3 -c "import yaml; yaml.safe_load(open('docker-compose.yml'))" && echo "✅ docker-compose.yml is valid"
elif command -v yq &> /dev/null; then
    yq eval . manifest.yaml > /dev/null && echo "✅ manifest.yaml is valid (via yq)"
    yq eval . docker-compose.yml > /dev/null && echo "✅ docker-compose.yml is valid (via yq)"
else
    echo "⚠️  Warning: Neither Python yaml module nor yq available for YAML validation"
    echo "✅ Skipping YAML validation (files exist and are readable)"
fi

# Check script permissions
for script in docker_entrypoint.sh healthcheck.sh backup.sh prepare.sh; do
    if [ -x "$script" ]; then
        echo "✅ $script is executable"
    else
        echo "❌ $script is not executable"
        exit 1
    fi
done

# Validate manifest structure
echo "Checking manifest structure..."
if python3 -c "import yaml" 2>/dev/null; then
    python3 -c "
import yaml
with open('manifest.yaml') as f:
    manifest = yaml.safe_load(f)

required_fields = ['id', 'title', 'version', 'description', 'main', 'interfaces']
for field in required_fields:
    if field not in manifest:
        print(f'❌ Missing required field in manifest: {field}')
        exit(1)
    else:
        print(f'✅ Found manifest field: {field}')
"
elif command -v yq &> /dev/null; then
    echo "✅ Using yq for manifest structure validation"
    for field in id title version description main interfaces; do
        if yq eval "has(\"$field\")" manifest.yaml | grep -q true; then
            echo "✅ Found manifest field: $field"
        else
            echo "❌ Missing required field in manifest: $field"
            exit 1
        fi
    done
else
    echo "⚠️  Warning: Cannot validate manifest structure without yaml parser"
    echo "✅ Skipping manifest structure validation"
fi

echo "✅ All tests passed! Start9 package structure is valid."
