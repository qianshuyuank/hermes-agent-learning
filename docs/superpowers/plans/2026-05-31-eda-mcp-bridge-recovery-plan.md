# EDA MCP Bridge Recovery Implementation Plan

> Update on 2026-05-31 after execution-time debugging: the original assumption in this plan that `jlcmcp/dist/index.js` should be started as a background daemon is incorrect. The actual implementation should keep `Gateway` resident and let Hermes launch `jlceda` on demand over stdio.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restore the LCEDA bridge connection by making the `EDA` operational scripts reliably start, check, and stop the `Gateway + MCP Server` stack.

**Architecture:** Keep the fix inside the `EDA/` operational layer instead of changing `jlcmcp` source code. Make startup explicit, make health checks runnable, and verify recovery with process-level checks before relying on the LCEDA UI.

**Tech Stack:** Bash, systemd unit file, Node.js runtime, `lsof`, `pgrep`

---

## File Map

- Modify: `EDA/start-eda-mcp.sh`
- Modify: `EDA/check-eda-mcp.sh`
- Modify: `EDA/eda-mcp-wrapper.sh`
- Review/Modify if needed: `EDA/eda-mcp.service`
- Verify against: `EDA/README.md`
- Verify runtime target: `/home/bitq/mcp-servers/jlcmcp/dist/index.js`

## Implementation Notes

- The current outage is not caused by a dead `Gateway`; `18800` already listens.
- The current failure is that `MCP Server` is absent, so the first implementation target is reliable `dist/index.js` startup.
- The upstream `BridgeClient` already falls back to `ws://127.0.0.1:18800/ws/bridge`, but the scripts should still export `GATEWAY_WS_URL` explicitly for clarity and operability.
- There is no existing automated test harness for these shell scripts, so verification is command-based and must be run after each task.

### Task 1: Make The Scripts Directly Runnable

**Files:**
- Modify: `EDA/start-eda-mcp.sh`
- Modify: `EDA/check-eda-mcp.sh`
- Modify: `EDA/stop-eda-mcp.sh`
- Modify: `EDA/eda-mcp-wrapper.sh`

- [ ] **Step 1: Capture the current failing behavior**

Run:

```bash
cd /home/bitq/github/hermes-agent-learning/EDA
./check-eda-mcp.sh
```

Expected: shell returns `权限不够` or an equivalent execute-permission error.

- [ ] **Step 2: Add execute permission to the operational scripts**

Run:

```bash
cd /home/bitq/github/hermes-agent-learning/EDA
chmod +x start-eda-mcp.sh check-eda-mcp.sh stop-eda-mcp.sh eda-mcp-wrapper.sh
```

Expected: command exits with code `0` and `ls -l *.sh` shows `x` bits for those files.

- [ ] **Step 3: Verify the scripts are now executable**

Run:

```bash
cd /home/bitq/github/hermes-agent-learning/EDA
ls -l start-eda-mcp.sh check-eda-mcp.sh stop-eda-mcp.sh eda-mcp-wrapper.sh
```

Expected: each file mode includes executable bits such as `-rwxrwxr-x` or equivalent.

- [ ] **Step 4: Commit the permission-only change**

Run:

```bash
cd /home/bitq/github/hermes-agent-learning
git add EDA/start-eda-mcp.sh EDA/check-eda-mcp.sh EDA/stop-eda-mcp.sh EDA/eda-mcp-wrapper.sh
git commit -m "chore: make EDA bridge scripts executable"
```

Expected: a commit is created containing mode changes only.

### Task 2: Harden The Startup Script Around MCP Server Launch

**Files:**
- Modify: `EDA/start-eda-mcp.sh`

- [ ] **Step 1: Confirm the current startup script does not fully express the runtime contract**

Read and compare the existing file:

```bash
cd /home/bitq/github/hermes-agent-learning/EDA
sed -n '1,200p' start-eda-mcp.sh
```

Expected: the script starts `node "$MCP_SERVER" &`, but it does not export `GATEWAY_WS_URL`, does not verify that the process survives beyond a minimal sleep, and does not surface startup logs.

- [ ] **Step 2: Replace `start-eda-mcp.sh` with an explicit and self-checking version**

Write this file content:

```bash
#!/bin/bash
set -u

GATEWAY_DIR="$HOME/mcp-servers/jlcmcp/gateway"
MCP_SERVER="$HOME/mcp-servers/jlcmcp/dist/index.js"
GATEWAY_PORT=18800
GATEWAY_WS_URL="ws://127.0.0.1:${GATEWAY_PORT}/ws/bridge"
LOG_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/eda-mcp"
MCP_LOG="$LOG_DIR/mcp-server.log"

mkdir -p "$LOG_DIR"

echo "=== 启动 EDA MCP 环境 ==="
echo "[*] Gateway URL: $GATEWAY_WS_URL"

if [ ! -f "$MCP_SERVER" ]; then
    echo "[✗] MCP Server 文件不存在: $MCP_SERVER"
    exit 1
fi

if lsof -i :"$GATEWAY_PORT" >/dev/null 2>&1; then
    echo "[✓] Gateway 已在运行 (端口 $GATEWAY_PORT)"
else
    echo "[*] 启动 Gateway..."
    (
        cd "$GATEWAY_DIR" || exit 1
        nohup node server.js >/dev/null 2>&1 &
    )
    sleep 1
    if lsof -i :"$GATEWAY_PORT" >/dev/null 2>&1; then
        echo "[✓] Gateway 启动成功"
    else
        echo "[✗] Gateway 启动失败"
        exit 1
    fi
fi

if pgrep -f "jlcmcp/dist/index.js" >/dev/null; then
    echo "[✓] MCP Server 已在运行"
else
    echo "[*] 启动 MCP Server..."
    export GATEWAY_WS_URL
    nohup node "$MCP_SERVER" >>"$MCP_LOG" 2>&1 &
    sleep 2
    if pgrep -f "jlcmcp/dist/index.js" >/dev/null; then
        echo "[✓] MCP Server 启动成功"
        echo "[*] 日志文件: $MCP_LOG"
    else
        echo "[✗] MCP Server 启动失败"
        echo "[*] 最近日志:"
        tail -n 50 "$MCP_LOG" 2>/dev/null || true
        exit 1
    fi
fi

echo
echo "=== 状态检查 ==="
lsof -i :"$GATEWAY_PORT" | grep -v "^COMMAND" || echo "Gateway: 未运行"
pgrep -af "jlcmcp/dist/index.js" || echo "MCP Server: 未运行"
```

- [ ] **Step 3: Run the startup script and verify process survival**

Run:

```bash
cd /home/bitq/github/hermes-agent-learning/EDA
./start-eda-mcp.sh
```

Expected:
- `Gateway` is reported as already running or started successfully
- `MCP Server 启动成功`
- output ends with a visible `pgrep -af "jlcmcp/dist/index.js"` match

- [ ] **Step 4: Confirm the recovery signals from the shell**

Run:

```bash
cd /home/bitq/github/hermes-agent-learning/EDA
lsof -i :18800
pgrep -af "jlcmcp/dist/index.js"
tail -n 20 "${XDG_STATE_HOME:-$HOME/.local/state}/eda-mcp/mcp-server.log"
```

Expected:
- `lsof` shows the `node server.js` listener
- `pgrep` shows a live `dist/index.js` process
- the log does not show an immediate crash loop

- [ ] **Step 5: Commit the startup hardening**

Run:

```bash
cd /home/bitq/github/hermes-agent-learning
git add EDA/start-eda-mcp.sh
git commit -m "fix: harden EDA MCP startup flow"
```

Expected: a commit is created for the startup-script change.

### Task 3: Make The Health Check Reflect The Real Recovery State

**Files:**
- Modify: `EDA/check-eda-mcp.sh`

- [ ] **Step 1: Confirm the health check currently reports only coarse status**

Read the current file:

```bash
cd /home/bitq/github/hermes-agent-learning/EDA
sed -n '1,200p' check-eda-mcp.sh
```

Expected: the script checks listener/process presence, but it does not show the configured bridge URL or surface helpful recovery context.

- [ ] **Step 2: Replace `check-eda-mcp.sh` with a more recovery-focused version**

Write this file content:

```bash
#!/bin/bash
set -u

GATEWAY_PORT=18800
GATEWAY_WS_URL="ws://127.0.0.1:${GATEWAY_PORT}/ws/bridge"
MCP_PATTERN="jlcmcp/dist/index.js"
CONFIG_PATH="$HOME/文档/LCEDA-Pro/config.json"

echo "=== EDA MCP 环境状态 ==="
echo "[*] Gateway URL: $GATEWAY_WS_URL"
echo

if lsof -i :"$GATEWAY_PORT" >/dev/null 2>&1; then
    echo "[✓] Gateway: 运行中 (端口 $GATEWAY_PORT)"
else
    echo "[✗] Gateway: 未运行"
fi

if pgrep -f "$MCP_PATTERN" >/dev/null; then
    echo "[✓] MCP Server: 运行中"
    pgrep -af "$MCP_PATTERN"
else
    echo "[✗] MCP Server: 未运行"
fi

if [ -f "$CONFIG_PATH" ]; then
    MODE=$(grep -o '"type"[[:space:]]*:[[:space:]]*"[^"]*"' "$CONFIG_PATH" | head -1 | grep -o '"[^"]*"$' | tr -d '"')
    echo "[*] LCEDA Pro 模式: ${MODE:-unknown}"
else
    echo "[?] LCEDA Pro 配置未找到"
fi

if lsof -i :"$GATEWAY_PORT" >/dev/null 2>&1 && pgrep -f "$MCP_PATTERN" >/dev/null; then
    echo
    echo "[✓] 恢复条件满足：Gateway 与 MCP Server 均已运行"
else
    echo
    echo "[!] 恢复条件未满足：请先执行 ./start-eda-mcp.sh"
fi
```

- [ ] **Step 3: Run the updated health check**

Run:

```bash
cd /home/bitq/github/hermes-agent-learning/EDA
./check-eda-mcp.sh
```

Expected:
- script runs without permission errors
- it prints `Gateway URL`
- it reports `Gateway` and `MCP Server` status clearly
- if Task 2 succeeded, it ends with `恢复条件满足`

- [ ] **Step 4: Commit the health-check improvement**

Run:

```bash
cd /home/bitq/github/hermes-agent-learning
git add EDA/check-eda-mcp.sh
git commit -m "fix: improve EDA MCP health check"
```

Expected: a commit is created for the health-check update.

### Task 4: Align The Wrapper And Service With The Same Runtime Assumptions

**Files:**
- Modify: `EDA/eda-mcp-wrapper.sh`
- Review/Modify if needed: `EDA/eda-mcp.service`

- [ ] **Step 1: Inspect the current wrapper and service**

Run:

```bash
cd /home/bitq/github/hermes-agent-learning/EDA
sed -n '1,220p' eda-mcp-wrapper.sh
sed -n '1,200p' eda-mcp.service
```

Expected: the wrapper starts both processes, but it does not export `GATEWAY_WS_URL`, does not log MCP failures, and stores PID files without verifying the launched process survived.

- [ ] **Step 2: Replace `eda-mcp-wrapper.sh` with a service-safe variant**

Write this file content:

```bash
#!/bin/bash
set -eu

GATEWAY_DIR="$HOME/mcp-servers/jlcmcp/gateway"
MCP_SERVER="$HOME/mcp-servers/jlcmcp/dist/index.js"
GATEWAY_PORT=18800
GATEWAY_WS_URL="ws://127.0.0.1:${GATEWAY_PORT}/ws/bridge"
RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/eda-mcp"
GATEWAY_PID_FILE="$RUNTIME_DIR/eda-gateway.pid"
MCP_PID_FILE="$RUNTIME_DIR/eda-mcp.pid"
MCP_LOG="$STATE_DIR/mcp-server.log"

mkdir -p "$RUNTIME_DIR" "$STATE_DIR"

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

start_mcp() {
    export GATEWAY_WS_URL
    nohup node "$MCP_SERVER" >>"$MCP_LOG" 2>&1 &
    echo $! > "$MCP_PID_FILE"
    sleep 2
    pgrep -f "jlcmcp/dist/index.js" >/dev/null
}

stop_if_present() {
    local pid_file="$1"
    if [ -f "$pid_file" ]; then
        kill "$(cat "$pid_file")" 2>/dev/null || true
        rm -f "$pid_file"
    fi
}

case "${1:-}" in
    start)
        start_gateway
        start_mcp
        ;;
    stop)
        stop_if_present "$MCP_PID_FILE"
        stop_if_present "$GATEWAY_PID_FILE"
        ;;
    *)
        echo "Usage: $0 {start|stop}"
        exit 1
        ;;
esac
```

- [ ] **Step 3: Keep the service file minimal unless verification proves a mismatch**

Use this service content only if the current file needs alignment after Step 2:

```ini
[Unit]
Description=EDA MCP Service (Gateway + Server)
After=network.target

[Service]
Type=oneshot
RemainAfterExit=yes
User=bitq
Environment="HOME=/home/bitq"
ExecStart=/home/bitq/github/hermes-agent-learning/EDA/eda-mcp-wrapper.sh start
ExecStop=/home/bitq/github/hermes-agent-learning/EDA/eda-mcp-wrapper.sh stop
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
```

If the file already matches this content, do not modify it.

- [ ] **Step 4: Verify the wrapper start/stop flow outside systemd first**

Run:

```bash
cd /home/bitq/github/hermes-agent-learning/EDA
./eda-mcp-wrapper.sh stop || true
./eda-mcp-wrapper.sh start
./check-eda-mcp.sh
./eda-mcp-wrapper.sh stop || true
./check-eda-mcp.sh
```

Expected:
- `start` leaves both services running
- first `check` reports recovery conditions satisfied
- `stop` removes the MCP process started by the wrapper
- second `check` reflects the stopped state

- [ ] **Step 5: Commit the wrapper/service alignment**

Run:

```bash
cd /home/bitq/github/hermes-agent-learning
git add EDA/eda-mcp-wrapper.sh EDA/eda-mcp.service
git commit -m "fix: align EDA MCP wrapper and service"
```

Expected: a commit is created, or if `eda-mcp.service` was unchanged only the wrapper is committed.

### Task 5: Run End-To-End Verification And Capture The User Handoff

**Files:**
- Verify: `EDA/start-eda-mcp.sh`
- Verify: `EDA/check-eda-mcp.sh`
- Review: `EDA/TROUBLE_HANDOFF.md`

- [ ] **Step 1: Bring the stack up using the intended user-facing entry point**

Run:

```bash
cd /home/bitq/github/hermes-agent-learning/EDA
./start-eda-mcp.sh
./check-eda-mcp.sh
```

Expected: both commands succeed and the check script ends with `恢复条件满足`.

- [ ] **Step 2: Run the final shell verification set**

Run:

```bash
cd /home/bitq/github/hermes-agent-learning/EDA
lsof -i :18800
pgrep -af "jlcmcp/dist/index.js"
```

Expected:
- a `node server.js` listener on `18800`
- a live `node /home/bitq/mcp-servers/jlcmcp/dist/index.js` process

- [ ] **Step 3: Perform the manual LCEDA verification**

Manual check:

```text
Open LCEDA Pro -> jlc-bridge extension -> confirm the bridge no longer shows
"Connect timeout after 8000ms" and instead shows a connected state.
```

Expected: UI no longer reports the timeout and shows `connected: true` or equivalent connected state.

- [ ] **Step 4: If LCEDA still fails, collect the next diagnostic payload instead of guessing**

Run:

```bash
cd /home/bitq/github/hermes-agent-learning/EDA
./check-eda-mcp.sh
tail -n 50 "${XDG_STATE_HOME:-$HOME/.local/state}/eda-mcp/mcp-server.log"
```

Expected: enough evidence to determine whether the remaining issue is on the MCP runtime side or the LCEDA plugin permission side.

- [ ] **Step 5: Commit the final operational state**

Run:

```bash
cd /home/bitq/github/hermes-agent-learning
git status --short
```

Expected: only the intended `EDA` script changes remain uncommitted or are already committed; there should be no surprise edits outside this scope.

## Self-Review Checklist

- Spec coverage: startup reliability, health check clarity, wrapper alignment, and verification are all covered by Tasks 2-5.
- Placeholder scan: no `TODO`, `TBD`, or undefined "write tests later" instructions remain.
- Type consistency: all commands and file paths consistently use `jlcmcp/dist/index.js`, `18800`, and `ws://127.0.0.1:18800/ws/bridge`.
