#!/bin/bash
# EDA MCP 启动脚本（供 systemd service 使用）
# 先启动 Gateway，等待就绪，再启动 MCP Server

GATEWAY_DIR="$HOME/mcp-servers/jlcmcp/gateway"
MCP_SERVER="$HOME/mcp-servers/jlcmcp/dist/index.js"
GATEWAY_PORT=18800
GATEWAY_PID_FILE="/run/eda-gateway.pid"
MCP_PID_FILE="/run/eda-mcp.pid"

start_gateway() {
    cd "$GATEWAY_DIR"
    node server.js &
    echo $! > "$GATEWAY_PID_FILE"

    # 等待 Gateway 就绪
    for i in {1..10}; do
        if lsof -i :$GATEWAY_PORT >/dev/null 2>&1; then
            return 0
        fi
        sleep 0.5
    done
    return 1
}

start_mcp() {
    node "$MCP_SERVER" &
    echo $! > "$MCP_PID_FILE"
}

# 主逻辑
case "$1" in
    start)
        start_gateway && start_mcp
        ;;
    stop)
        [ -f "$MCP_PID_FILE" ] && kill $(cat "$MCP_PID_FILE") 2>/dev/null
        [ -f "$GATEWAY_PID_FILE" ] && kill $(cat "$GATEWAY_PID_FILE") 2>/dev/null
        rm -f "$MCP_PID_FILE" "$GATEWAY_PID_FILE"
        ;;
    *)
        echo "Usage: $0 {start|stop}"
        exit 1
        ;;
esac