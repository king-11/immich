FROM ghcr.io/immich-app/immich-server:release

# Install dependencies for Start9 integration
RUN apt-get update && apt-get install -y \
    curl \
    jq \
    yq \
    postgresql-client \
    && rm -rf /var/lib/apt/lists/*

# Create directories for Start9
RUN mkdir -p /data/library /data/postgres /data/config

# Copy Start9 specific scripts
COPY docker_entrypoint.sh /usr/local/bin/docker_entrypoint.sh
COPY healthcheck.sh /usr/local/bin/healthcheck.sh
COPY backup.sh /usr/local/bin/backup.sh

# Make scripts executable
RUN chmod +x /usr/local/bin/docker_entrypoint.sh /usr/local/bin/healthcheck.sh /usr/local/bin/backup.sh

# Set environment variables for Start9
ENV UPLOAD_LOCATION=/data/library
ENV DB_DATA_LOCATION=/data/postgres
ENV IMMICH_CONFIG_FILE=/data/config/immich.json

EXPOSE 2283

CMD ["/usr/local/bin/docker_entrypoint.sh"]