# Start9 Immich Service Package Makefile

.PHONY: build test clean validate lint

IMAGE_NAME := immich-start9
PACKAGE_NAME := immich

# Build the Docker image
build:
	@echo "Building Start9 Immich Docker image..."
	docker build -t $(IMAGE_NAME) .

# Run validation tests
test:
	@echo "Running Start9 package validation tests..."
	./test.sh

# Validate YAML files
validate:
	@echo "Validating YAML configuration files..."
	@python3 -c "import yaml; yaml.safe_load(open('manifest.yaml'))" && echo "✅ manifest.yaml is valid"
	@python3 -c "import yaml; yaml.safe_load(open('docker-compose.yml'))" && echo "✅ docker-compose.yml is valid"

# Lint shell scripts
lint:
	@echo "Linting shell scripts..."
	@which shellcheck > /dev/null || (echo "shellcheck not found, install with: apt-get install shellcheck" && exit 1)
	shellcheck *.sh

# Clean up build artifacts
clean:
	@echo "Cleaning up build artifacts..."
	docker rmi $(IMAGE_NAME) 2>/dev/null || true

# Package for Start9 (requires Start9 SDK)
package: validate test
	@echo "Creating Start9 package..."
	@echo "Note: This requires Start9 SDK to be installed"
	@echo "Run: start-sdk pack"

# Help
help:
	@echo "Available targets:"
	@echo "  build     - Build the Docker image"
	@echo "  test      - Run validation tests"
	@echo "  validate  - Validate YAML files"
	@echo "  lint      - Lint shell scripts (requires shellcheck)"
	@echo "  clean     - Clean up build artifacts"
	@echo "  package   - Create Start9 package (requires Start9 SDK)"
	@echo "  help      - Show this help message"