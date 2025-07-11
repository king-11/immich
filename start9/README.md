# Immich Start9 Service Package

This directory contains the Start9 service package for Immich, a high-performance self-hosted photo and video management solution.

## Package Contents

- `manifest.yaml` - Start9 service manifest defining the service configuration
- `Dockerfile` - Custom Docker image for Start9 environment  
- `docker-compose.yml` - Multi-container setup for Immich components
- `docker_entrypoint.sh` - Service initialization and startup script
- `healthcheck.sh` - Health check script for service monitoring
- `backup.sh` - Backup and restore functionality
- `prepare.sh` - Build environment setup script for Debian systems
- `test.sh` - Package validation and testing script
- `update-version.sh` - Version synchronization script with main repository
- `LICENSE` - AGPL-3.0 license file (copied from main project)
- `assets/` - Service assets including icon and instructions

## Architecture

The Start9 package includes:

- **Immich Server**: Main application server
- **PostgreSQL**: Database for metadata and user data
- **Redis**: Caching and session management
- **Machine Learning**: AI features for face detection and search

## Features

- Automatic configuration for Start9 environment
- Integrated backup and restore functionality
- Health monitoring and status reporting
- Secure default configuration
- Mobile app support via Tor/LAN interfaces

## Storage Structure

```
/data/
├── library/          # User photos and videos
├── postgres/         # Database files
├── config/           # Configuration files
├── redis/            # Redis data
└── model-cache/      # ML model cache
```

## Building the Package

To build this as a Start9 service package:

1. **Environment Setup**: Run `./prepare.sh` to set up the build environment with Docker, Docker Buildx, yq, and Start9 SDK
2. **Version Sync**: Run `./update-version.sh` to sync with current Immich version and update changelog
3. **Validation**: Run `./test.sh` to validate package structure and required files
4. **Build**: Build the Docker image: `docker build -t immich-start9 .`
5. **Package**: Use Start9 SDK tools to create the service package
6. **Deploy**: Test deployment on Start9 development environment

## Configuration

The service is pre-configured with sensible defaults for the Start9 environment:

- **Port**: 2283 (mapped to standard HTTP/HTTPS ports via Start9)
- **Storage**: Persistent volumes for all data
- **Security**: Local-only access with optional Tor support
- **Performance**: Optimized for Start9 hardware constraints

## Support

For Start9-specific issues, please check:
- Start9 documentation
- Immich documentation at https://immich.app/docs
- Community support channels

## Development and Testing

### Build Environment Setup
The `prepare.sh` script automates the setup of build dependencies:
- Docker and Docker Buildx for containerization
- yq for YAML processing
- Start9 SDK for package creation

### Package Validation
The `test.sh` script validates:
- Required file presence and structure
- YAML syntax validation
- Script executable permissions
- Manifest field completeness

### Build Scripts
- `docker_entrypoint.sh` - Handles service initialization with Start9-specific configuration
- `healthcheck.sh` - Provides JSON-formatted health status for Start9 monitoring
- `backup.sh` - Implements create/restore functionality for Start9 backup system

### Version Management
The `update-version.sh` script automates version synchronization with GitHub releases:
- **Fetches Latest Release**: Automatically gets the latest version from GitHub using `gh` CLI or REST API
- **Real Changelog Integration**: Extracts actual release notes from GitHub releases with dates and full details
- **Multi-file Updates**: Updates `manifest.yaml`, `Dockerfile`, and `docker-compose.yml` with the latest version
- **Dependency Detection**: Checks for required tools (`yq`, `gh`/`curl`, `jq`) and provides installation guidance
- **Comprehensive Release Notes**: Combines official Immich changelog with Start9-specific package updates
- **Fallback Support**: Works with GitHub CLI (preferred) or falls back to curl + GitHub REST API

**Dependencies**: 
- `yq` (required) - YAML processing
- `gh` (preferred) or `curl` + `jq` - GitHub API access
- Run `./prepare.sh` to install all dependencies

## License

This packaging is provided under the same license as Immich (AGPL-3.0). The license file is included in this directory for compliance.