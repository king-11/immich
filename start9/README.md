# Immich Start9 Service Package

This directory contains the Start9 service package for Immich, a high-performance self-hosted photo and video management solution.

## Package Contents

- `manifest.yaml` - Start9 service manifest defining the service configuration
- `Dockerfile` - Custom Docker image for Start9 environment  
- `docker-compose.yml` - Multi-container setup for Immich components
- `start.sh` - Service initialization and startup script
- `healthcheck.sh` - Health check script for service monitoring
- `backup.sh` - Backup and restore functionality
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

1. Ensure all files are present in the `start9/` directory
2. Build the Docker image: `docker build -t immich-start9 .`
3. Package using Start9 SDK tools
4. Test deployment on Start9 development environment

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

## License

This packaging is provided under the same license as Immich (AGPL-3.0).