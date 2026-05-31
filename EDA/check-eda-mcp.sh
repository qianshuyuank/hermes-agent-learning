#!/bin/bash
set -u

GATEWAY_PORT=18800
GATEWAY_WS_URL="ws://127.0.0.1:${GATEWAY_PORT}/ws/bridge"
HERMES_PROFILE="${HERMES_PROFILE:-$HOME/.hermes/profiles/hw-engineer/config.yaml}"
EXPECTED_MCP_SERVER="$HOME/mcp-servers/jlcmcp/dist/index.js"
LCEDA_CONFIG="$HOME/文档/LCEDA-Pro/config.json"
MCP_PROCESS_PATTERN="node .*jlcmcp/dist/index.js"

validate_hermes_profile() {
    python3 - "$HERMES_PROFILE" "$EXPECTED_MCP_SERVER" "$GATEWAY_WS_URL" <<'PY'
import sys
from pathlib import Path
import yaml

config_path = Path(sys.argv[1])
expected_server = sys.argv[2]
expected_url = sys.argv[3]

if not config_path.exists():
    print(f"[✗] Hermes profile 不存在: {config_path}")
    raise SystemExit(1)

data = yaml.safe_load(config_path.read_text()) or {}
server = ((data.get("mcp_servers") or {}).get("jlceda") or {})
args = server.get("args")
env = server.get("env") or {}

if server.get("command") != "node":
    print("[✗] Hermes profile 的 jlceda.command 不是 node")
    raise SystemExit(1)

if not isinstance(args, list):
    print(f"[✗] Hermes profile 的 jlceda.args 必须是 YAML 数组，当前是 {type(args).__name__}")
    raise SystemExit(1)

if args != [expected_server]:
    print(f"[✗] Hermes profile 的 jlceda.args 不匹配: {args!r}")
    raise SystemExit(1)

if env.get("GATEWAY_WS_URL") != expected_url:
    print(f"[✗] Hermes profile 的 GATEWAY_WS_URL 不匹配: {env.get('GATEWAY_WS_URL')!r}")
    raise SystemExit(1)

print(f"[✓] Hermes profile: 已正确配置 jlceda -> {expected_server}")
PY
}

echo "=== EDA MCP 环境状态 ==="
echo "[*] Gateway URL: $GATEWAY_WS_URL"
echo

if lsof -i :"$GATEWAY_PORT" >/dev/null 2>&1; then
    echo "[✓] Gateway: 运行中 (端口 $GATEWAY_PORT)"
else
    echo "[✗] Gateway: 未运行"
fi

if pgrep -af "$MCP_PROCESS_PATTERN" >/dev/null; then
    echo "[*] MCP Server: 当前会话中运行"
    pgrep -af "$MCP_PROCESS_PATTERN"
else
    echo "[*] MCP Server: 当前未运行（这是正常的，Hermes 会按需通过 stdio 启动）"
fi

validate_hermes_profile

if [ -f "$LCEDA_CONFIG" ]; then
    MODE=$(grep -o '"type"[[:space:]]*:[[:space:]]*"[^"]*"' "$LCEDA_CONFIG" | head -1 | grep -o '"[^"]*"$' | tr -d '"')
    echo "[*] LCEDA Pro 模式: ${MODE:-unknown}"
else
    echo "[?] LCEDA Pro 配置未找到"
fi

if lsof -i :"$GATEWAY_PORT" >/dev/null 2>&1 && validate_hermes_profile >/dev/null; then
    echo
    echo "[✓] 恢复条件满足：Gateway 运行，Hermes 可按需启动 jlceda MCP Server"
else
    echo
    echo "[!] 恢复条件未满足：请先执行 ./start-eda-mcp.sh 并修复 Hermes profile"
fi
