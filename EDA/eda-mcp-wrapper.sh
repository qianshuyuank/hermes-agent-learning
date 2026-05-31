#!/bin/bash
set -eu

GATEWAY_DIR="$HOME/mcp-servers/jlcmcp/gateway"
GATEWAY_PORT=18800
RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
GATEWAY_PID_FILE="$RUNTIME_DIR/eda-gateway.pid"

start_gateway() {
    if [ -f "$HOME/.nvm/nvm.sh" ]; then
        export NVM_DIR="$HOME/.nvm"
        . "$NVM_DIR/nvm.sh"
    fi
    cd "$GATEWAY_DIR" || exit 1
    exec node server.js
}

stop_gateway_if_present() {
    if [ -f "$GATEWAY_PID_FILE" ]; then
        kill "$(cat "$GATEWAY_PID_FILE")" 2>/dev/null || true
        rm -f "$GATEWAY_PID_FILE"
    fi
}

case "${1:-}" in
    start)
        start_gateway
        ;;
    stop)
        stop_gateway_if_present
        ;;
    *)
        echo "Usage: $0 {start|stop}"
        exit 1
        ;;
esac
