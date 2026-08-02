#!/bin/bash
# 启动 EDA MCP 环境
# 1. Gateway (WebSocket 中转层)
# 2. MCP Server (jlceda)

GATEWAY_DIR="$HOME/mcp-servers/jlcmcp/gateway"
MCP_SERVER="$HOME/mcp-servers/jlcmcp/dist/index.js"
GATEWAY_PORT=18800

echo "=== 启动 EDA MCP 环境 ==="

# 检查 gateway 是否运行
if lsof -i :$GATEWAY_PORT >/dev/null 2>&1; then
    echo "[✓] Gateway 已在运行 (端口 $GATEWAY_PORT)"
else
    echo "[*] 启动 Gateway..."
    cd "$GATEWAY_DIR" && node server.js &
    sleep 1
    if lsof -i :$GATEWAY_PORT >/dev/null 2>&1; then
        echo "[✓] Gateway 启动成功"
    else
        echo "[✗] Gateway 启动失败"
    fi
fi

# 检查 MCP server 是否运行
if pgrep -f "jlcmcp/dist/index.js" >/dev/null; then
    echo "[✓] MCP Server 已在运行"
else
    echo "[*] 启动 MCP Server..."
    node "$MCP_SERVER" &
    sleep 1
    if pgrep -f "jlcmcp/dist/index.js" >/dev/null; then
        echo "[✓] MCP Server 启动成功"
    else
        echo "[✗] MCP Server 启动失败"
    fi
fi

echo ""
echo "=== 状态检查 ==="
lsof -i :$GATEWAY_PORT | grep -v "^COMMAND" || echo "Gateway: 未运行"
pgrep -f "jlcmcp/dist/index.js" >/dev/null && echo "MCP Server: 运行中" || echo "MCP Server: 未运行"