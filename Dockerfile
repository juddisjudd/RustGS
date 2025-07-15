FROM steamcmd/steamcmd:latest

LABEL org.opencontainers.image.authors="ipajudd"
LABEL org.opencontainers.image.source="https://github.com/juddisjudd/RustGS"

# Install dependencies
RUN apt-get update && apt-get install -y \
    curl \
    unzip \
    wget \
    ca-certificates \
    lib32gcc-s1 \
    libsqlite3-0 \
    net-tools \
    procps \
    && rm -rf /var/lib/apt/lists/*

# Environment variables
ENV DATA_DIR="/serverdata"
ENV STEAMCMD_DIR="${DATA_DIR}/steamcmd"
ENV SERVER_DIR="${DATA_DIR}/serverfiles"
ENV OXIDE_DIR="${DATA_DIR}/oxide"
ENV CARBON_DIR="${DATA_DIR}/carbon"
ENV LOGS_DIR="${DATA_DIR}/logs"

# Game specific variables
ENV GAME_ID="258550"
ENV GAME_NAME="Rust"
ENV GAME_PORT="28015"
ENV QUERY_PORT="28016"
ENV RCON_PORT="28016"
ENV APP_PORT="28082"

# Server configuration defaults
ENV SERVER_IDENTITY="rust-server"
ENV SERVER_NAME="My RustGS Server"
ENV SERVER_DESCRIPTION="A Rust server powered by RustGS Docker"
ENV SERVER_URL=""
ENV SERVER_HEADERIMAGE=""
ENV SERVER_MAXPLAYERS="100"
ENV SERVER_LEVEL="Procedural Map"
ENV SERVER_SEED="12345"
ENV SERVER_WORLDSIZE="3000"
ENV SERVER_LEVELURL=""
ENV SERVER_SAVEINTERVAL="600"
ENV FPS_LIMIT="30"
ENV SERVER_TICKRATE="30"
ENV SERVER_SECURE="true"
ENV SERVER_ENCRYPTION="1"

# RCON configuration
ENV RCON_PASSWORD=""
ENV RCON_WEB="1"

# Rust+ app configuration
ENV APP_PUBLICIP=""

# Mod configuration
ENV OXIDE_MOD="false"
ENV CARBON_MOD="false"
ENV FORCE_OXIDE_INSTALLATION="true"
ENV FORCE_CARBON_INSTALLATION="true"

# System configuration
ENV VALIDATE="false"
ENV UMASK="000"
ENV UID="99"
ENV GID="100"
ENV USERNAME=""
ENV PASSWRD=""
ENV USER="steam"
ENV DATA_PERM="770"

# Create directories and user
RUN mkdir -p $DATA_DIR $STEAMCMD_DIR $SERVER_DIR $OXIDE_DIR $CARBON_DIR $LOGS_DIR && \
    useradd -d $DATA_DIR -s /bin/bash $USER && \
    chown -R $USER:$USER $DATA_DIR && \
    ulimit -n 2048

# Copy scripts
COPY --chown=root:root scripts/ /opt/scripts/
RUN chmod -R 770 /opt/scripts/

# Expose ports
EXPOSE 28015/tcp 28015/udp 28016/tcp 28016/udp 28082/tcp

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=300s --retries=3 \
    CMD /opt/scripts/healthcheck.sh

# Volume for persistent data
VOLUME ["${DATA_DIR}"]

# Entry point
ENTRYPOINT ["/opt/scripts/start.sh"]