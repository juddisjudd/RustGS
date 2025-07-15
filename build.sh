#!/bin/bash

set -e

# Configuration
DOCKER_USERNAME="${DOCKER_USERNAME:-ipajudd}"
IMAGE_NAME="rustgs"
IMAGE_TAG="${IMAGE_TAG:-latest}"
FULL_IMAGE_NAME="${DOCKER_USERNAME}/${IMAGE_NAME}:${IMAGE_TAG}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
}

info() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')] INFO: $1${NC}"
}

# Function to check if Docker is installed and running
check_docker() {
    if ! command -v docker &> /dev/null; then
        error "Docker is not installed. Please install Docker first."
        exit 1
    fi
    
    if ! docker info &> /dev/null; then
        error "Docker is not running. Please start Docker first."
        exit 1
    fi
    
    log "Docker is installed and running"
}

# Function to create directory structure
create_structure() {
    log "Creating directory structure..."
    
    mkdir -p scripts
    
    # Create scripts directory and files
    cat > scripts/entrypoint.sh << 'EOF'
#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
}

# Function to install/update Rust server
install_rust_server() {
    log "Installing/updating Rust server..."
    
    steamcmd +force_install_dir "${RUST_SERVER_DIR}" \
             +login anonymous \
             +app_update 258550 validate \
             +quit
    
    if [ $? -eq 0 ]; then
        log "Rust server installation completed"
    else
        error "Rust server installation failed"
        exit 1
    fi
}

# Function to install Oxide (uMod)
install_oxide() {
    if [ "${USE_OXIDE}" = "true" ]; then
        log "Installing Oxide (uMod)..."
        
        OXIDE_URL="https://umod.org/games/rust/download"
        OXIDE_ZIP="${OXIDE_DIR}/oxide.zip"
        
        # Download latest Oxide
        curl -L -o "${OXIDE_ZIP}" "${OXIDE_URL}"
        
        # Extract to server directory
        unzip -o "${OXIDE_ZIP}" -d "${RUST_SERVER_DIR}"
        
        # Create oxide config directory if it doesn't exist
        mkdir -p "${OXIDE_DIR}/config"
        mkdir -p "${OXIDE_DIR}/data"
        mkdir -p "${OXIDE_DIR}/plugins"
        
        log "Oxide installation completed"
    fi
}

# Function to install Carbon
install_carbon() {
    if [ "${USE_CARBON}" = "true" ]; then
        log "Installing Carbon..."
        
        CARBON_URL="https://github.com/CarbonCommunity/Carbon/releases/latest/download/Carbon.Linux.Release.tar.gz"
        CARBON_TAR="${CARBON_DIR}/carbon.tar.gz"
        
        # Download latest Carbon
        curl -L -o "${CARBON_TAR}" "${CARBON_URL}"
        
        # Extract to server directory
        tar -xzf "${CARBON_TAR}" -C "${RUST_SERVER_DIR}"
        
        # Create carbon config directory if it doesn't exist
        mkdir -p "${CARBON_DIR}/config"
        mkdir -p "${CARBON_DIR}/data"
        mkdir -p "${CARBON_DIR}/plugins"
        
        log "Carbon installation completed"
    fi
}

# Function to build server command
build_server_command() {
    local cmd="${RUST_SERVER_DIR}/RustDedicated"
    
    # Basic parameters
    cmd="${cmd} -batchmode -nographics"
    cmd="${cmd} -logfile \"${LOGFILE_PATH}\""
    
    # Server identity and networking
    cmd="${cmd} +server.identity \"${SERVER_IDENTITY}\""
    cmd="${cmd} +server.port ${SERVER_PORT}"
    cmd="${cmd} +server.queryport ${SERVER_QUERYPORT}"
    
    # RCON configuration
    cmd="${cmd} +rcon.port ${RCON_PORT}"
    cmd="${cmd} +rcon.password \"${RCON_PASSWORD}\""
    cmd="${cmd} +rcon.web ${RCON_WEB}"
    
    # Server information
    cmd="${cmd} +server.hostname \"${SERVER_HOSTNAME}\""
    cmd="${cmd} +server.description \"${SERVER_DESCRIPTION}\""
    
    if [ -n "${SERVER_URL}" ]; then
        cmd="${cmd} +server.url \"${SERVER_URL}\""
    fi
    
    if [ -n "${SERVER_HEADERIMAGE}" ]; then
        cmd="${cmd} +server.headerimage \"${SERVER_HEADERIMAGE}\""
    fi
    
    cmd="${cmd} +server.maxplayers ${SERVER_MAXPLAYERS}"
    
    # World configuration
    cmd="${cmd} +server.level \"${SERVER_LEVEL}\""
    cmd="${cmd} +server.seed ${SERVER_SEED}"
    cmd="${cmd} +server.worldsize ${SERVER_WORLDSIZE}"
    
    if [ -n "${SERVER_LEVELURL}" ]; then
        cmd="${cmd} +server.levelurl \"${SERVER_LEVELURL}\""
    fi
    
    cmd="${cmd} +server.saveinterval ${SERVER_SAVEINTERVAL}"
    
    # Performance settings
    cmd="${cmd} +fps.limit ${FPS_LIMIT}"
    cmd="${cmd} +server.tickrate ${SERVER_TICKRATE}"
    
    # Rust+ app configuration
    cmd="${cmd} +app.port ${APP_PORT}"
    
    if [ -n "${APP_PUBLICIP}" ]; then
        cmd="${cmd} +app.publicip \"${APP_PUBLICIP}\""
    fi
    
    # Security settings
    cmd="${cmd} +server.secure ${SERVER_SECURE}"
    cmd="${cmd} +server.encryption ${SERVER_ENCRYPTION}"
    
    # Mod parameters
    if [ "${USE_OXIDE}" = "true" ]; then
        cmd="${cmd} +oxide.directory \"${OXIDE_DIR}\""
    fi
    
    if [ "${USE_CARBON}" = "true" ]; then
        cmd="${cmd} -carbon.rootdir \"${CARBON_DIR}\""
    fi
    
    echo "${cmd}"
}

# Function to create necessary directories
create_directories() {
    log "Creating necessary directories..."
    
    mkdir -p "${RUST_SERVER_DIR}"
    mkdir -p "${LOGS_DIR}"
    mkdir -p "${OXIDE_DIR}"
    mkdir -p "${CARBON_DIR}"
    
    # Create identity directory
    mkdir -p "${RUST_SERVER_DIR}/server/${SERVER_IDENTITY}"
}

# Function to handle graceful shutdown
graceful_shutdown() {
    log "Received shutdown signal. Shutting down gracefully..."
    
    if [ ! -z "${RUST_PID}" ]; then
        kill -TERM "${RUST_PID}"
        wait "${RUST_PID}"
    fi
    
    log "Server shutdown complete"
    exit 0
}

# Set up signal handlers
trap graceful_shutdown SIGTERM SIGINT

# Main execution
log "Starting RustGS Docker Container"
log "Server Identity: ${SERVER_IDENTITY}"
log "Server Port: ${SERVER_PORT}"
log "Max Players: ${SERVER_MAXPLAYERS}"
log "Use Oxide: ${USE_OXIDE}"
log "Use Carbon: ${USE_CARBON}"

# Create directories
create_directories

# Install/update server
install_rust_server

# Install mods if enabled
install_oxide
install_carbon

# Build and execute server command
SERVER_CMD=$(build_server_command)
log "Starting server with command: ${SERVER_CMD}"

# Start the server
eval "${SERVER_CMD}" &
RUST_PID=$!

# Wait for the server process
wait "${RUST_PID}"
EOF

    cat > scripts/healthcheck.sh << 'EOF'
#!/bin/bash

# Health check script for Rust server
# Checks if the server is running and responding

# Check if RustDedicated process is running
if ! pgrep -f "RustDedicated" > /dev/null; then
    echo "RustDedicated process not found"
    exit 1
fi

# Check if the server port is listening
if ! netstat -tuln | grep -q ":${SERVER_PORT}"; then
    echo "Server port ${SERVER_PORT} not listening"
    exit 1
fi

# Check if RCON port is listening (if enabled)
if [ "${RCON_WEB}" = "1" ]; then
    if ! netstat -tuln | grep -q ":${RCON_PORT}"; then
        echo "RCON port ${RCON_PORT} not listening"
        exit 1
    fi
fi

# Check if log file exists and is being written to
if [ ! -f "${LOGFILE_PATH}" ]; then
    echo "Log file ${LOGFILE_PATH} not found"
    exit 1
fi

# Check if log file has been modified in the last 5 minutes
if [ $(find "${LOGFILE_PATH}" -mmin -5 | wc -l) -eq 0 ]; then
    echo "Log file hasn't been modified in the last 5 minutes"
    exit 1
fi

echo "Health check passed"
exit 0
EOF

    chmod +x scripts/*.sh
    
    log "Directory structure created successfully"
}

# Function to build Docker image
build_image() {
    log "Building Docker image: ${FULL_IMAGE_NAME}"
    
    docker build -t "${FULL_IMAGE_NAME}" .
    
    if [ $? -eq 0 ]; then
        log "Docker image built successfully"
    else
        error "Docker image build failed"
        exit 1
    fi
}

# Function to test the image locally
test_image() {
    log "Testing Docker image locally..."
    
    # Run a quick test to make sure the image starts correctly
    docker run --rm -d --name rust-server-test "${FULL_IMAGE_NAME}" &
    TEST_CONTAINER_PID=$!
    
    # Wait a bit for the container to start
    sleep 30
    
    # Check if container is still running
    if docker ps | grep -q rust-server-test; then
        log "Container test passed"
        docker stop rust-server-test
    else
        error "Container test failed"
        docker logs rust-server-test
        exit 1
    fi
}

# Function to push to Docker Hub
push_image() {
    log "Pushing image to Docker Hub..."
    
    # Check if user is logged in
    if ! docker info | grep -q "Username"; then
        warn "You are not logged in to Docker Hub. Please run 'docker login' first."
        read -p "Do you want to login now? (y/n): " -r
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            docker login
        else
            error "Cannot push without logging in"
            exit 1
        fi
    fi
    
    docker push "${FULL_IMAGE_NAME}"
    
    if [ $? -eq 0 ]; then
        log "Image pushed successfully to Docker Hub"
        info "Image available at: https://hub.docker.com/r/${DOCKER_USERNAME}/${IMAGE_NAME}"
    else
        error "Failed to push image to Docker Hub"
        exit 1
    fi
}

# Function to clean up
cleanup() {
    log "Cleaning up..."
    
    # Remove dangling images
    docker image prune -f
    
    log "Cleanup completed"
}

# Main execution
main() {
    log "Starting RustGS Docker build and publish process"
    
    # Check prerequisites
    check_docker
    
    # Create directory structure
    create_structure
    
    # Build the image
    build_image
    
    # Test the image
    test_image
    
    # Ask if user wants to push to Docker Hub
    read -p "Do you want to push the image to Docker Hub? (y/n): " -r
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        push_image
    else
        log "Skipping Docker Hub push"
    fi
    
    # Cleanup
    cleanup
    
    log "Process completed successfully!"
    info "To run your server locally, use:"
    info "docker run -d -p 28015:28015 -p 28016:28016 -p 28082:28082 ${FULL_IMAGE_NAME}"
    info "Or use the provided docker-compose.yml file"
}

# Run main function
main

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
}

info() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')] INFO: $1${NC}"
}

# Function to check if Docker is installed and running
check_docker() {
    if ! command -v docker &> /dev/null; then
        error "Docker is not installed. Please install Docker first."
        exit 1
    fi
    
    if ! docker info &> /dev/null; then
        error "Docker is not running. Please start Docker first."
        exit 1
    fi
    
    log "Docker is installed and running"
}

# Function to create directory structure
create_structure() {
    log "Creating directory structure..."
    
    mkdir -p scripts
    
    # Create scripts directory and files
    cat > scripts/entrypoint.sh << 'EOF'
#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
}

# Function to install/update Rust server
install_rust_server() {
    log "Installing/updating Rust server..."
    
    steamcmd +force_install_dir "${RUST_SERVER_DIR}" \
             +login anonymous \
             +app_update 258550 validate \
             +quit
    
    if [ $? -eq 0 ]; then
        log "Rust server installation completed"
    else
        error "Rust server installation failed"
        exit 1
    fi
}

# Function to install Oxide (uMod)
install_oxide() {
    if [ "${USE_OXIDE}" = "true" ]; then
        log "Installing Oxide (uMod)..."
        
        OXIDE_URL="https://umod.org/games/rust/download"
        OXIDE_ZIP="${OXIDE_DIR}/oxide.zip"
        
        # Download latest Oxide
        curl -L -o "${OXIDE_ZIP}" "${OXIDE_URL}"
        
        # Extract to server directory
        unzip -o "${OXIDE_ZIP}" -d "${RUST_SERVER_DIR}"
        
        # Create oxide config directory if it doesn't exist
        mkdir -p "${OXIDE_DIR}/config"
        mkdir -p "${OXIDE_DIR}/data"
        mkdir -p "${OXIDE_DIR}/plugins"
        
        log "Oxide installation completed"
    fi
}

# Function to install Carbon
install_carbon() {
    if [ "${USE_CARBON}" = "true" ]; then
        log "Installing Carbon..."
        
        CARBON_URL="https://github.com/CarbonCommunity/Carbon/releases/latest/download/Carbon.Linux.Release.tar.gz"
        CARBON_TAR="${CARBON_DIR}/carbon.tar.gz"
        
        # Download latest Carbon
        curl -L -o "${CARBON_TAR}" "${CARBON_URL}"
        
        # Extract to server directory
        tar -xzf "${CARBON_TAR}" -C "${RUST_SERVER_DIR}"
        
        # Create carbon config directory if it doesn't exist
        mkdir -p "${CARBON_DIR}/config"
        mkdir -p "${CARBON_DIR}/data"
        mkdir -p "${CARBON_DIR}/plugins"
        
        log "Carbon installation completed"
    fi
}

# Function to build server command
build_server_command() {
    local cmd="${RUST_SERVER_DIR}/RustDedicated"
    
    # Basic parameters
    cmd="${cmd} -batchmode -nographics"
    cmd="${cmd} -logfile \"${LOGFILE_PATH}\""
    
    # Server identity and networking
    cmd="${cmd} +server.identity \"${SERVER_IDENTITY}\""
    cmd="${cmd} +server.port ${SERVER_PORT}"
    cmd="${cmd} +server.queryport ${SERVER_QUERYPORT}"
    
    # RCON configuration
    cmd="${cmd} +rcon.port ${RCON_PORT}"
    cmd="${cmd} +rcon.password \"${RCON_PASSWORD}\""
    cmd="${cmd} +rcon.web ${RCON_WEB}"
    
    # Server information
    cmd="${cmd} +server.hostname \"${SERVER_HOSTNAME}\""
    cmd="${cmd} +server.description \"${SERVER_DESCRIPTION}\""
    
    if [ -n "${SERVER_URL}" ]; then
        cmd="${cmd} +server.url \"${SERVER_URL}\""
    fi
    
    if [ -n "${SERVER_HEADERIMAGE}" ]; then
        cmd="${cmd} +server.headerimage \"${SERVER_HEADERIMAGE}\""
    fi
    
    cmd="${cmd} +server.maxplayers ${SERVER_MAXPLAYERS}"
    
    # World configuration
    cmd="${cmd} +server.level \"${SERVER_LEVEL}\""
    cmd="${cmd} +server.seed ${SERVER_SEED}"
    cmd="${cmd} +server.worldsize ${SERVER_WORLDSIZE}"
    
    if [ -n "${SERVER_LEVELURL}" ]; then
        cmd="${cmd} +server.levelurl \"${SERVER_LEVELURL}\""
    fi
    
    cmd="${cmd} +server.saveinterval ${SERVER_SAVEINTERVAL}"
    
    # Performance settings
    cmd="${cmd} +fps.limit ${FPS_LIMIT}"
    cmd="${cmd} +server.tickrate ${SERVER_TICKRATE}"
    
    # Rust+ app configuration
    cmd="${cmd} +app.port ${APP_PORT}"
    
    if [ -n "${APP_PUBLICIP}" ]; then
        cmd="${cmd} +app.publicip \"${APP_PUBLICIP}\""
    fi
    
    # Security settings
    cmd="${cmd} +server.secure ${SERVER_SECURE}"
    cmd="${cmd} +server.encryption ${SERVER_ENCRYPTION}"
    
    # Mod parameters
    if [ "${USE_OXIDE}" = "true" ]; then
        cmd="${cmd} +oxide.directory \"${OXIDE_DIR}\""
    fi
    
    if [ "${USE_CARBON}" = "true" ]; then
        cmd="${cmd} -carbon.rootdir \"${CARBON_DIR}\""
    fi
    
    echo "${cmd}"
}

# Function to create necessary directories
create_directories() {
    log "Creating necessary directories..."
    
    mkdir -p "${RUST_SERVER_DIR}"
    mkdir -p "${LOGS_DIR}"
    mkdir -p "${OXIDE_DIR}"
    mkdir -p "${CARBON_DIR}"
    
    # Create identity directory
    mkdir -p "${RUST_SERVER_DIR}/server/${SERVER_IDENTITY}"
}

# Function to handle graceful shutdown
graceful_shutdown() {
    log "Received shutdown signal. Shutting down gracefully..."
    
    if [ ! -z "${RUST_PID}" ]; then
        kill -TERM "${RUST_PID}"
        wait "${RUST_PID}"
    fi
    
    log "Server shutdown complete"
    exit 0
}

# Set up signal handlers
trap graceful_shutdown SIGTERM SIGINT

# Main execution
log "Starting Rust Game Server Docker Container"
log "Server Identity: ${SERVER_IDENTITY}"
log "Server Port: ${SERVER_PORT}"
log "Max Players: ${SERVER_MAXPLAYERS}"
log "Use Oxide: ${USE_OXIDE}"
log "Use Carbon: ${USE_CARBON}"

# Create directories
create_directories

# Install/update server
install_rust_server

# Install mods if enabled
install_oxide
install_carbon

# Build and execute server command
SERVER_CMD=$(build_server_command)
log "Starting server with command: ${SERVER_CMD}"

# Start the server
eval "${SERVER_CMD}" &
RUST_PID=$!

# Wait for the server process
wait "${RUST_PID}"
EOF

    cat > scripts/healthcheck.sh << 'EOF'
#!/bin/bash

# Health check script for Rust server
# Checks if the server is running and responding

# Check if RustDedicated process is running
if ! pgrep -f "RustDedicated" > /dev/null; then
    echo "RustDedicated process not found"
    exit 1
fi

# Check if the server port is listening
if ! netstat -tuln | grep -q ":${SERVER_PORT}"; then
    echo "Server port ${SERVER_PORT} not listening"
    exit 1
fi

# Check if RCON port is listening (if enabled)
if [ "${RCON_WEB}" = "1" ]; then
    if ! netstat -tuln | grep -q ":${RCON_PORT}"; then
        echo "RCON port ${RCON_PORT} not listening"
        exit 1
    fi
fi

# Check if log file exists and is being written to
if [ ! -f "${LOGFILE_PATH}" ]; then
    echo "Log file ${LOGFILE_PATH} not found"
    exit 1
fi

# Check if log file has been modified in the last 5 minutes
if [ $(find "${LOGFILE_PATH}" -mmin -5 | wc -l) -eq 0 ]; then
    echo "Log file hasn't been modified in the last 5 minutes"
    exit 1
fi

echo "Health check passed"
exit 0
EOF

    chmod +x scripts/*.sh
    
    log "Directory structure created successfully"
}

# Function to build Docker image
build_image() {
    log "Building Docker image: ${FULL_IMAGE_NAME}"
    
    docker build -t "${FULL_IMAGE_NAME}" .
    
    if [ $? -eq 0 ]; then
        log "Docker image built successfully"
    else
        error "Docker image build failed"
        exit 1
    fi
}

# Function to test the image locally
test_image() {
    log "Testing Docker image locally..."
    
    # Run a quick test to make sure the image starts correctly
    docker run --rm -d --name rust-server-test "${FULL_IMAGE_NAME}" &
    TEST_CONTAINER_PID=$!
    
    # Wait a bit for the container to start
    sleep 30
    
    # Check if container is still running
    if docker ps | grep -q rust-server-test; then
        log "Container test passed"
        docker stop rust-server-test
    else
        error "Container test failed"
        docker logs rust-server-test
        exit 1
    fi
}

# Function to push to Docker Hub
push_image() {
    log "Pushing image to Docker Hub..."
    
    # Check if user is logged in
    if ! docker info | grep -q "Username"; then
        warn "You are not logged in to Docker Hub. Please run 'docker login' first."
        read -p "Do you want to login now? (y/n): " -r
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            docker login
        else
            error "Cannot push without logging in"
            exit 1
        fi
    fi
    
    docker push "${FULL_IMAGE_NAME}"
    
    if [ $? -eq 0 ]; then
        log "Image pushed successfully to Docker Hub"
        info "Image available at: https://hub.docker.com/r/${DOCKER_USERNAME}/${IMAGE_NAME}"
    else
        error "Failed to push image to Docker Hub"
        exit 1
    fi
}

# Function to clean up
cleanup() {
    log "Cleaning up..."
    
    # Remove dangling images
    docker image prune -f
    
    log "Cleanup completed"
}

# Main execution
main() {
    log "Starting Rust Game Server Docker build and publish process"
    
    # Check prerequisites
    check_docker
    
    # Create directory structure
    create_structure
    
    # Build the image
    build_image
    
    # Test the image
    test_image
    
    # Ask if user wants to push to Docker Hub
    read -p "Do you want to push the image to Docker Hub? (y/n): " -r
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        push_image
    else
        log "Skipping Docker Hub push"
    fi
    
    # Cleanup
    cleanup
    
    log "Process completed successfully!"
    info "To run your server locally, use:"
    info "docker run -d -p 28015:28015 -p 28016:28016 -p 28082:28082 ${FULL_IMAGE_NAME}"
    info "Or use the provided docker-compose.yml file"
}

# Run main function
main