#!/bin/bash
# 检查 EDA MCP 环境状态

GATEWAY_PORT=18800

echo "=== EDA MCP 环境状态 ==="
echo ""

# Gateway 状态
if lsof -i :$GATEWAY_PORT >/dev/null 2>&1; then
    echo "[✓] Gateway: 运行中 (端口 $GATEWAY_PORT)"
else
    echo "[✗] Gateway: 未运行"
fi

# MCP Server 状态
if pgrep -f "jlcmcp/dist/index.js" >/dev/null; then
    echo "[✓] MCP Server: 运行中"
else
    echo "[✗] MCP Server: 未运行"
fi

# LCEDA Pro 状态（检查配置文件）
CONFIG_PATH="$HOME/文档/LCEDA-Pro/config.json"
if [ -f "$CONFIG_PATH" ]; then
    MODE=$(grep -o '"type"[[:space:]]*:[[:space:]]*"[^"]*"' "$CONFIG_PATH" | head -1 | grep -o '"[^"]*"$' | tr -d '"')
    echo "[*] LCEDA Pro 模式: $MODE"
else
    echo "[?] LCEDA Pro 配置未找到"
fi

# jlc-bridge 扩展目录
EXT_DIR="$HOME/文档/LCEDA-Pro/extensions"
if [ -d "$EXT_DIR" ]; then
    EXT_COUNT=$(find "$EXT_DIR" -maxdepth 1 -type d | wc -l)
    echo "[*] 已安装扩展数: $((EXT_COUNT - 1))"
fi