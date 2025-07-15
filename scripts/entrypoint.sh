#!/bin/bash
echo "---Ensuring UID: ${UID} matches user---"
usermod -u ${UID} ${USER} 2>/dev/null || echo "UID ${UID} already exists, continuing..."
echo "---Ensuring GID: ${GID} matches user---"
groupmod -g ${GID} ${USER} > /dev/null 2>&1 ||:
usermod -g ${GID} ${USER} 2>/dev/null || echo "GID ${GID} already exists, continuing..."
echo "---Setting umask to ${UMASK}---"
umask ${UMASK}

echo "---Checking for optional scripts---"
cp -f /opt/custom/user.sh /opt/scripts/start-user.sh > /dev/null 2>&1 ||:
cp -f /opt/scripts/user.sh /opt/scripts/start-user.sh > /dev/null 2>&1 ||:

if [ -f /opt/scripts/start-user.sh ]; then
    echo "---Found optional script, executing---"
    chmod -f +x /opt/scripts/start-user.sh ||:
    /opt/scripts/start-user.sh || echo "---Optional Script has thrown an Error---"
else
    echo "---No optional script found, continuing---"
fi

echo "---Taking ownership of data...---"
chown -R root:${GID} /opt/scripts
chmod -R 750 /opt/scripts

# Create directories if they don't exist and set ownership
mkdir -p ${DATA_DIR} ${STEAMCMD_DIR} ${SERVER_DIR} ${OXIDE_DIR} ${CARBON_DIR} ${LOGS_DIR}
chown -R ${UID}:${GID} ${DATA_DIR}
chmod -R 755 ${DATA_DIR}

echo "---Starting RustGS Server...---"
term_handler() {
    echo "---Received shutdown signal---"
    kill -SIGINT $(pidof RustDedicated) 2>/dev/null || true
    tail --pid=$(pidof RustDedicated) -f 2>/dev/null || true
    sleep 0.5
    echo "---Server shutdown complete---"
    exit 143;
}

trap 'kill ${!}; term_handler' SIGTERM
su ${USER} -c "/opt/scripts/start-server.sh" &
killpid="$!"
while true
do
    wait $killpid
    exit 0;
done