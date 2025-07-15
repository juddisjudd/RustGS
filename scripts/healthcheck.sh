#!/bin/bash

# Health check script for RustGS server
# Checks if the server is running and responding

# Check if RustDedicated process is running
if ! pgrep -f "RustDedicated" > /dev/null; then
    echo "RustDedicated process not found"
    exit 1
fi

# Check if the server port is listening
if ! netstat -tuln | grep -q ":${GAME_PORT}"; then
    echo "Server port ${GAME_PORT} not listening"
    exit 1
fi

# Check if RCON port is listening (only if RCON password is set)
if [ -n "${RCON_PASSWORD}" ] && [ "${RCON_WEB}" = "1" ]; then
    if ! netstat -tuln | grep -q ":${RCON_PORT}"; then
        echo "RCON port ${RCON_PORT} not listening"
        exit 1
    fi
fi

# Check if log file exists and is being written to
if [ ! -f "${LOGS_DIR}/server.log" ]; then
    echo "Log file ${LOGS_DIR}/server.log not found"
    exit 1
fi

# Check if log file has been modified in the last 5 minutes
if [ $(find "${LOGS_DIR}/server.log" -mmin -5 2>/dev/null | wc -l) -eq 0 ]; then
    echo "Log file hasn't been modified in the last 5 minutes"
    exit 1
fi

echo "Health check passed"
exit 0