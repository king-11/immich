#!/bin/bash

set -euo pipefail

echo "Testing Start9 Immich package structure..."

# Check required files
REQUIRED_FILES=(
    "manifest.yaml"
    "Dockerfile"
    "docker-compose.yml"
    "start.sh"
    "healthcheck.sh"
    "backup.sh"
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
python3 -c "import yaml; yaml.safe_load(open('manifest.yaml'))" && echo "✅ manifest.yaml is valid"
python3 -c "import yaml; yaml.safe_load(open('docker-compose.yml'))" && echo "✅ docker-compose.yml is valid"

# Check script permissions
for script in start.sh healthcheck.sh backup.sh; do
    if [ -x "$script" ]; then
        echo "✅ $script is executable"
    else
        echo "❌ $script is not executable"
        exit 1
    fi
done

# Validate manifest structure
echo "Checking manifest structure..."
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

echo "✅ All tests passed! Start9 package structure is valid."