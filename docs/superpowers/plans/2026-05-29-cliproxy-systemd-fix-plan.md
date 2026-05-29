# CLIProxyAPI Systemd Fix Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 修正 `cliproxyapi.service` 的启动方式，使其稳定使用显式 `-config` 参数，并提供只重启 systemd 服务的安全脚本。

**Architecture:** 先修正用户级 `systemd` 服务，让 `cliproxyapi.service` 的 `ExecStart` 显式指向 `/home/bitq/.cli-proxy-api/config.yaml`，从根源消除“无参启动导致 Invalid API key”的问题。随后在仓库中补一个只通过 `systemctl --user restart` 管理服务的脚本，避免脚本和 systemd 争抢进程。

**Tech Stack:** systemd user service、Bash、Hermes CLI。

---

### Task 1: 修正 `cliproxyapi.service`

**Files:**
- Modify: `/home/bitq/.config/systemd/user/cliproxyapi.service`

- [ ] **Step 1: 读取当前服务定义**

Run:

```bash
systemctl --user cat cliproxyapi.service
```

Expected: `ExecStart` 当前为 `/home/bitq/cliproxyapi/cli-proxy-api`，尚未带 `-config` 参数。

- [ ] **Step 2: 将 `ExecStart` 改为显式配置启动**

把服务中的这一行：

```ini
ExecStart=/home/bitq/cliproxyapi/cli-proxy-api
```

改成：

```ini
ExecStart=/home/bitq/cliproxyapi/cli-proxy-api -config /home/bitq/.cli-proxy-api/config.yaml
```

Expected: systemd 以后重启或开机自启时，都使用同一份显式代理配置。

- [ ] **Step 3: 重新加载并重启服务**

Run:

```bash
systemctl --user daemon-reload
systemctl --user restart cliproxyapi.service
systemctl --user status cliproxyapi.service --no-pager
```

Expected: 服务成功重启，状态为 `active (running)`。

- [ ] **Step 4: 验证进程命令行**

Run:

```bash
ps -ef | grep cli-proxy-api | grep -v grep
```

Expected: 进程命令行中可见 `-config /home/bitq/.cli-proxy-api/config.yaml`。

---

### Task 2: 增加安全重启脚本

**Files:**
- Create: `/home/bitq/github/hermes-agent-learning/scripts/restart-hermes-proxy-services.sh`

- [ ] **Step 1: 先写一个最小失败检查脚本思路**

脚本需要覆盖以下约束：

```text
1. 只通过 systemctl --user restart 管理服务
2. 不直接 pkill，不直接手动起二进制
3. 依次重启 cliproxyapi.service 和 hermes-gateway.service
4. 输出两个服务的状态摘要
```

Expected: 设计上避免和 systemd 竞争进程控制权。

- [ ] **Step 2: 创建脚本**

脚本内容写成：

```bash
#!/usr/bin/env bash
set -euo pipefail

services=(
  cliproxyapi.service
  hermes-gateway.service
)

for service in "${services[@]}"; do
  echo "==> Restarting ${service}"
  systemctl --user restart "${service}"
  systemctl --user is-active --quiet "${service}"
  echo "    ${service}: active"
done

echo
echo "==> Service summary"
systemctl --user --no-pager --plain --full status cliproxyapi.service hermes-gateway.service
```

Expected: 脚本职责单一，只做安全重启和状态确认。

- [ ] **Step 3: 赋予执行权限**

Run:

```bash
chmod +x /home/bitq/github/hermes-agent-learning/scripts/restart-hermes-proxy-services.sh
```

Expected: 脚本可直接执行。

- [ ] **Step 4: 运行脚本验证**

Run:

```bash
/home/bitq/github/hermes-agent-learning/scripts/restart-hermes-proxy-services.sh
```

Expected: 两个服务均被正常重启并显示 `active`。

---

### Task 3: 端到端验证

**Files:**
- Verify: `/home/bitq/.config/systemd/user/cliproxyapi.service`
- Verify: `/home/bitq/github/hermes-agent-learning/scripts/restart-hermes-proxy-services.sh`

- [ ] **Step 1: 验证代理层不再回到 `Invalid API key`**

Run:

```bash
curl -s -S -X POST http://localhost:8317/v1/chat/completions \
  -H "Authorization: Bearer local-proxy-key" \
  -H "Content-Type: application/json" \
  -d '{"model":"gemini-3.1-pro-preview","messages":[{"role":"user","content":"test"}],"max_tokens":5}'
```

Expected: 不再出现 `Invalid API key`；若失败，也应是上游网络类错误。

- [ ] **Step 2: 验证 Hermes 主链路**

Run:

```bash
hermes -z "test"
```

Expected: 返回正常响应，或至少不再出现本地 `401/Invalid API key`。

- [ ] **Step 3: 记录操作前提**

最终说明明确写出：

```text
此脚本的前提是 cliproxyapi.service 已经修正为带 -config 的 ExecStart。
在此前提下，脚本可以无脑运行，因为它只重启 systemd 服务，不直接管理底层进程。
```

Expected: 用户对“是否可无脑运行”有明确答案。
