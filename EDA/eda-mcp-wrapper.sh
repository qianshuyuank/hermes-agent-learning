#!/bin/bash
set -eu

GATEWAY_DIR="$HOME/mcp-servers/jlcmcp/gateway"
GATEWAY_PORT=18800
RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
GATEWAY_PID_FILE="$RUNTIME_DIR/eda-gateway.pid"

start_gateway() {
    if lsof -i :"$GATEWAY_PORT" >/dev/null 2>&1; then
        return 0
    fi

    (
        cd "$GATEWAY_DIR" || exit 1
        nohup node server.js >/dev/null 2>&1 &
        echo $! > "$GATEWAY_PID_FILE"
    )

    for _ in 1 2 3 4 5 6 7 8 9 10; do
        if lsof -i :"$GATEWAY_PORT" >/dev/null 2>&1; then
            return 0
        fi
        sleep 0.5
    done
    return 1
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
