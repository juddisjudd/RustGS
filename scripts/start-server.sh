#!/bin/bash
set -e

# Colors for output (simplified for better compatibility)
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

warn() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] WARNING: $1"
}

error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1"
}

# Function to install/update SteamCMD
install_steamcmd() {
    if [ ! -f ${STEAMCMD_DIR}/steamcmd.sh ]; then
        log "SteamCMD not found, downloading..."
        wget -q -O ${STEAMCMD_DIR}/steamcmd_linux.tar.gz http://media.steampowered.com/client/steamcmd_linux.tar.gz 
        tar --directory ${STEAMCMD_DIR} -xvzf ${STEAMCMD_DIR}/steamcmd_linux.tar.gz
        rm ${STEAMCMD_DIR}/steamcmd_linux.tar.gz
    fi

    log "Updating SteamCMD..."
    if [ "${USERNAME}" == "" ]; then
        ${STEAMCMD_DIR}/steamcmd.sh +login anonymous +quit
    else
        ${STEAMCMD_DIR}/steamcmd.sh +login ${USERNAME} ${PASSWRD} +quit
    fi
}

# Function to install/update Rust server
install_rust_server() {
    log "Installing/updating Rust server..."
    
    if [ "${USERNAME}" == "" ]; then
        if [ "${VALIDATE}" == "true" ]; then
            log "Validating installation..."
            ${STEAMCMD_DIR}/steamcmd.sh \
                +force_install_dir ${SERVER_DIR} \
                +login anonymous \
                +app_update ${GAME_ID} validate \
                +quit
        else
            ${STEAMCMD_DIR}/steamcmd.sh \
                +force_install_dir ${SERVER_DIR} \
                +login anonymous \
                +app_update ${GAME_ID} \
                +quit
        fi
    else
        if [ "${VALIDATE}" == "true" ]; then
            log "Validating installation..."
            ${STEAMCMD_DIR}/steamcmd.sh \
                +force_install_dir ${SERVER_DIR} \
                +login ${USERNAME} ${PASSWRD} \
                +app_update ${GAME_ID} validate \
                +quit
        else
            ${STEAMCMD_DIR}/steamcmd.sh \
                +force_install_dir ${SERVER_DIR} \
                +login ${USERNAME} ${PASSWRD} \
                +app_update ${GAME_ID} \
                +quit
        fi
    fi
    
    if [ $? -eq 0 ]; then
        log "Rust server installation completed"
    else
        error "Rust server installation failed"
        sleep infinity
    fi
}

# Function to install Oxide
install_oxide() {
    if [ "${OXIDE_MOD}" == "true" ] && [ "${CARBON_MOD}" == "true" ]; then
        error "Oxide and Carbon mod enabled, you can only enable one at a time, putting container into sleep mode."
        sleep infinity
    fi

    if [ "${OXIDE_MOD}" == "true" ]; then
        log "Oxide Mod enabled!"
        CUR_V="$(find ${SERVER_DIR} -maxdepth 1 -name "OxideMod-*.zip" | cut -d '-' -f2)"
        LAT_V="$(wget -qO- https://api.github.com/repos/OxideMod/Oxide.Rust/releases/latest | grep tag_name | cut -d '"' -f4)"

        if [ -z ${LAT_V} ]; then
            if [ -z ${CUR_V%.*} ]; then
                error "Can't get latest Oxide Mod version and found no installed version, putting server into sleep mode!"
                sleep infinity
            else
                warn "Can't get latest Oxide Mod version, falling back to installed v${CUR_V%.*}!"
                LAT_V="${CUR_V%.*}"
            fi
        fi

        if [ -z "${CUR_V%.}" ]; then
            log "Oxide Mod not found, downloading..."
            rm -f ${SERVER_DIR}/OxideMod-*.zip
            cd ${SERVER_DIR}
            if wget -q -nc --show-progress --progress=bar:force:noscroll -O ${SERVER_DIR}/OxideMod-${LAT_V}.zip "https://github.com/OxideMod/Oxide.Rust/releases/download/${LAT_V}/Oxide.Rust-linux.zip" ; then
                log "Successfully downloaded Oxide Mod v${LAT_V}!"
            else
                error "Something went wrong, can't download Oxide Mod v${LAT_V}, putting server in sleep mode"
                sleep infinity
            fi
            unzip -o ${SERVER_DIR}/OxideMod-${LAT_V}.zip -d ${SERVER_DIR}
        elif [ "${LAT_V}" != "${CUR_V%.*}" ]; then
            cd ${SERVER_DIR}
            rm -rf ${SERVER_DIR}/OxideMod-*.zip
            log "Newer version of Oxide Mod v${LAT_V} found, currently installed: v${CUR_V%.*}"
            if wget -q -nc --show-progress --progress=bar:force:noscroll -O ${SERVER_DIR}/OxideMod-${LAT_V}.zip "https://github.com/OxideMod/Oxide.Rust/releases/download/${LAT_V}/Oxide.Rust-linux.zip" ; then
                log "Successfully downloaded Oxide Mod v${LAT_V}!"
            else
                error "Something went wrong, can't download Oxide Mod v${LAT_V}, putting server in sleep mode"
                sleep infinity
            fi
            unzip -o ${SERVER_DIR}/OxideMod-${LAT_V}.zip -d ${SERVER_DIR}
        elif [ "$LAT_V" == "${CUR_V%.*}" ]; then
            log "Oxide Mod v${CUR_V%.*} is Up-To-Date!"
        fi

        if [ "${FORCE_OXIDE_INSTALLATION}" == "true" ]; then
            unzip -o ${SERVER_DIR}/OxideMod-${LAT_V}.zip -d ${SERVER_DIR}
        fi

        # Create oxide directories
        mkdir -p "${OXIDE_DIR}/config"
        mkdir -p "${OXIDE_DIR}/data"
        mkdir -p "${OXIDE_DIR}/plugins"
        mkdir -p "${OXIDE_DIR}/logs"
    fi
}

# Function to install Carbon
install_carbon() {
    if [ "${CARBON_MOD}" == "true" ]; then
        log "Carbon Mod enabled!"
        CUR_V="$(find ${SERVER_DIR} -maxdepth 1 -name "CarbonMod-*.tar.gz" | cut -d '-' -f2)"
        LAT_V="$(wget -qO- https://api.github.com/repos/CarbonCommunity/Carbon/releases/latest | grep tag_name | cut -d '"' -f4)"

        if [ -z ${LAT_V} ]; then
            if [ -z ${CUR_V%.tar.gz} ]; then
                error "Can't get latest Carbon Mod version and found no installed version, putting server into sleep mode!"
                sleep infinity
            else
                warn "Can't get latest Carbon Mod version, falling back to installed v${CUR_V%.tar.gz}!"
                LAT_V="${CUR_V%.tar.gz}"
            fi
        fi

        if [ -z "${CUR_V%.tar.gz}" ]; then
            log "Carbon Mod not found, downloading..."
            rm -f ${SERVER_DIR}/CarbonMod-*.tar.gz
            cd ${SERVER_DIR}
            if wget -q -nc --show-progress --progress=bar:force:noscroll -O ${SERVER_DIR}/CarbonMod-${LAT_V}.tar.gz "https://github.com/CarbonCommunity/Carbon/releases/download/${LAT_V}/Carbon.Linux.Release.tar.gz" ; then
                log "Successfully downloaded Carbon Mod ${LAT_V}!"
            else
                error "Something went wrong, can't download Carbon Mod ${LAT_V}, putting server in sleep mode"
                sleep infinity
            fi
            tar -xvf ${SERVER_DIR}/CarbonMod-${LAT_V}.tar.gz -C ${SERVER_DIR}
        elif [ "${LAT_V}" != "${CUR_V%.tar.gz}" ]; then
            cd ${SERVER_DIR}
            rm -rf ${SERVER_DIR}/CarbonMod-*.tar.gz
            log "Newer version of Carbon Mod ${LAT_V} found, currently installed: v${CUR_V%.tar.gz}"
            if wget -q -nc --show-progress --progress=bar:force:noscroll -O ${SERVER_DIR}/CarbonMod-${LAT_V}.tar.gz "https://github.com/CarbonCommunity/Carbon/releases/download/${LAT_V}/Carbon.Linux.Release.tar.gz" ; then
                log "Successfully downloaded Carbon Mod ${LAT_V}!"
            else
                error "Something went wrong, can't download Carbon Mod ${LAT_V}, putting server in sleep mode"
                sleep infinity
            fi
            tar -xvf ${SERVER_DIR}/CarbonMod-${LAT_V}.tar.gz -C ${SERVER_DIR}
        elif [ "$LAT_V" == "${CUR_V%.tar.gz}" ]; then
            log "Carbon Mod ${CUR_V%.tar.gz} is Up-To-Date!"
        fi

        if [ "${FORCE_CARBON_INSTALLATION}" == "true" ]; then
            tar -xvf ${SERVER_DIR}/CarbonMod-${LAT_V}.tar.gz -C ${SERVER_DIR}
        fi
        
        # Source Carbon environment if available
        if [ -f "${SERVER_DIR}/carbon/tools/environment.sh" ]; then
            source "${SERVER_DIR}/carbon/tools/environment.sh"
        fi

        # Create carbon directories
        mkdir -p "${CARBON_DIR}/config"
        mkdir -p "${CARBON_DIR}/data"
        mkdir -p "${CARBON_DIR}/plugins"
        mkdir -p "${CARBON_DIR}/logs"
    fi
}

# Function to build server command
build_server_command() {
    local cmd="${SERVER_DIR}/RustDedicated"
    
    # Basic parameters
    cmd="${cmd} -batchmode -nographics"
    cmd="${cmd} -logfile \"${LOGS_DIR}/server.log\""
    
    # Server identity and networking
    cmd="${cmd} +server.identity \"${SERVER_IDENTITY}\""
    cmd="${cmd} +server.port ${GAME_PORT}"
    cmd="${cmd} +server.queryport ${QUERY_PORT}"
    
    # RCON configuration
    cmd="${cmd} +rcon.port ${RCON_PORT}"
    
    # Only add RCON password if it's set
    if [ -n "${RCON_PASSWORD}" ]; then
        cmd="${cmd} +rcon.password \"${RCON_PASSWORD}\""
        cmd="${cmd} +rcon.web ${RCON_WEB}"
    else
        warn "RCON password not set - RCON will be disabled"
        cmd="${cmd} +rcon.web 0"
    fi
    
    # Server information
    cmd="${cmd} +server.hostname \"${SERVER_NAME}\""
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
    
    # Performance settings - only add if explicitly set and not default
    if [ "${FPS_LIMIT}" != "30" ] && [ -n "${FPS_LIMIT}" ]; then
        cmd="${cmd} +fps.limit ${FPS_LIMIT}"
    fi
    
    if [ "${SERVER_TICKRATE}" != "30" ] && [ -n "${SERVER_TICKRATE}" ]; then
        cmd="${cmd} +server.tickrate ${SERVER_TICKRATE}"
    fi
    
    # Rust+ app configuration
    cmd="${cmd} +app.port ${APP_PORT}"
    
    if [ -n "${APP_PUBLICIP}" ]; then
        cmd="${cmd} +app.publicip \"${APP_PUBLICIP}\""
    fi
    
    # Security settings - only add if explicitly set and not default
    if [ "${SERVER_SECURE}" != "true" ] && [ -n "${SERVER_SECURE}" ]; then
        cmd="${cmd} +server.secure ${SERVER_SECURE}"
    fi
    
    if [ "${SERVER_ENCRYPTION}" != "1" ] && [ -n "${SERVER_ENCRYPTION}" ]; then
        cmd="${cmd} +server.encryption ${SERVER_ENCRYPTION}"
    fi
    
    # Mod parameters
    if [ "${OXIDE_MOD}" == "true" ]; then
        cmd="${cmd} +oxide.directory \"${OXIDE_DIR}\""
    fi
    
    if [ "${CARBON_MOD}" == "true" ]; then
        cmd="${cmd} -carbon.rootdir \"${CARBON_DIR}\""
    fi
    
    echo "${cmd}"
}

# Main execution
log "Starting RustGS Server Setup"
log "Server Identity: ${SERVER_IDENTITY}"
log "Server Port: ${GAME_PORT}"
log "Max Players: ${SERVER_MAXPLAYERS}"
log "Oxide Mod: ${OXIDE_MOD}"
log "Carbon Mod: ${CARBON_MOD}"

# Create log directory
mkdir -p "${LOGS_DIR}"

# Install/update components
install_steamcmd
install_rust_server
install_oxide
install_carbon

# Prepare server
log "Preparing server..."
chmod -R ${DATA_PERM} ${DATA_DIR}

log "Setting library path..."
export LD_LIBRARY_PATH=":/bin/RustDedicated_Data/Plugins/x86_64"

log "Server ready!"

# Start server
log "Starting Rust server..."
cd ${SERVER_DIR}

if [ ! -f ${SERVER_DIR}/RustDedicated ]; then
    error "Can't find game executable (RustDedicated), putting server into sleep mode!"
    sleep infinity
else
    SERVER_CMD=$(build_server_command)
    log "Starting server with command: ${SERVER_CMD}"
    eval "${SERVER_CMD}"
fi