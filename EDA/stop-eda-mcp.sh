#!/bin/bash
# 停止 EDA MCP 环境

echo "=== 停止 EDA MCP 环境 ==="

# 停止 MCP Server
MCP_PID=$(pgrep -f "jlcmcp/dist/index.js")
if [ -n "$MCP_PID" ]; then
    kill $MCP_PID 2>/dev/null && echo "[✓] MCP Server 已停止" || echo "[✗] MCP Server 停止失败"
else
    echo "[*] MCP Server 未运行"
fi

# Gateway 不建议直接 kill（可能有其他用途）
# 如果确定要停止 gateway：
# GATEWAY_PID=$(lsof -ti :18800)
# kill $GATEWAY_PID 2>/dev/null && echo "[✓] Gateway 已停止" || echo "[*] Gateway 未停止（可能其他进程使用）"

echo ""
echo "注意：如果需要停止 Gateway，请手动执行："
echo "  kill \$(lsof -ti :18800)"