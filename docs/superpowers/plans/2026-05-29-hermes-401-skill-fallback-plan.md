# Hermes 401 技能场景回退鉴权问题 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 修复 Hermes 在普通对话后续阶段和 `brainstorming` 等 Skill 场景中再次出现的 `401 Invalid API key`，确保主模型与辅助模型统一使用本地代理鉴权。

**Architecture:** 先核对 Hermes 主模型、`auxiliary` 子配置、代理允许的 API Key 与环境变量污染情况，确认 `401` 来自本地鉴权链路而非上游网络。随后将主模型和所有辅助任务显式固定为同一套 `custom + localhost:8317 + local-proxy-key` 配置，重启 `cli-proxy-api` 与 `hermes gateway`，最后分别验证普通对话路径与 Skill 路径。

**Tech Stack:** YAML 配置、Bash、Hermes CLI、curl。

---

### Task 1: Inspect Current Auth Chain

**Files:**
- Inspect: `~/.hermes/config.yaml`
- Inspect: `~/.cli-proxy-api/config.yaml`
- Inspect: `~/.bashrc`

- [ ] **Step 1: 查看 Hermes 主模型与辅助模型配置**

Run:

```bash
sed -n '/^model:/,/^[^ ]/p' ~/.hermes/config.yaml
printf '\n--- auxiliary ---\n'
sed -n '/^auxiliary:/,$p' ~/.hermes/config.yaml
```

Expected: 输出中能看到 `model:` 与 `auxiliary:` 的 `provider`、`base_url`、`api_key`。如果部分 `auxiliary` 项的 `api_key` 与主模型不同，或为空字符串，则记录为高风险项。

- [ ] **Step 2: 查看代理允许的 API Key**

Run:

```bash
cat ~/.cli-proxy-api/config.yaml
```

Expected: `api-keys:` 下包含当前 Hermes 预期使用的本地 key，例如 `local-proxy-key`。如果仍存在 `dummy`、`sk-test-localhost-99999` 或其他历史值，记录为待清理项。

- [ ] **Step 3: 查看可能污染回退行为的环境变量来源**

Run:

```bash
grep -nE 'OPENAI_API_KEY|MINIMAX_CN_API_KEY|GEMINI|GOOGLE' ~/.bashrc || true
env | grep -E 'OPENAI_API_KEY|MINIMAX_CN_API_KEY|GEMINI|GOOGLE' || true
```

Expected: 即便存在环境变量，也只作为背景信息记录。若 `auxiliary.api_key` 为空，则这些变量会成为本次 `401` 的高风险污染源。

- [ ] **Step 4: 记录当前问题判断**

将检查结果整理为以下结论模板，写入执行日志或工作说明：

```text
1. 主模型是否固定为 custom + http://localhost:8317/v1 + local-proxy-key
2. auxiliary 是否全部与主模型一致
3. 代理 api-keys 是否仅包含 local-proxy-key
4. 是否存在 OPENAI_API_KEY 等环境变量污染风险
5. 当前问题是否仍应判定为本地 401 鉴权链路问题
```

Expected: 结论明确指向“继续修正配置”或“配置已一致，需要转向其他错误类型排查”。

- [ ] **Step 5: Commit**

此任务只做检查，不修改仓库文件，因此不提交代码。

---

### Task 2: Normalize Hermes And Proxy Configuration

**Files:**
- Modify: `~/.hermes/config.yaml`
- Modify: `~/.cli-proxy-api/config.yaml`

- [ ] **Step 1: 备份现有配置**

Run:

```bash
cp ~/.hermes/config.yaml ~/.hermes/config.yaml.bak.$(date +%Y%m%d%H%M%S)
cp ~/.cli-proxy-api/config.yaml ~/.cli-proxy-api/config.yaml.bak.$(date +%Y%m%d%H%M%S)
```

Expected: 两个备份文件创建成功，便于回滚。

- [ ] **Step 2: 将代理允许的 API Key 统一为本地 key**

将 `~/.cli-proxy-api/config.yaml` 调整为以下形态：

```yaml
host: ""
port: 8317
auth-dir: "~/.cli-proxy-api"
api-keys:
  - local-proxy-key
```

Expected: `api-keys` 中不再保留旧测试 key、占位 key 或无关 key。

- [ ] **Step 3: 将 Hermes 主模型固定到本地代理**

确保 `~/.hermes/config.yaml` 中主模型配置符合以下结构：

```yaml
model:
  default: gemini-3.1-pro-preview
  provider: custom
  base_url: http://localhost:8317/v1
  api_key: local-proxy-key
```

Expected: 主模型不再依赖环境变量或占位符 key。

- [ ] **Step 4: 将所有 auxiliary 任务显式固定到本地代理**

将 `~/.hermes/config.yaml` 中每个辅助任务都调整为以下结构，不留空 `api_key`：

```yaml
auxiliary:
  title_generation:
    provider: custom
    base_url: http://localhost:8317/v1
    api_key: local-proxy-key
  triage_specifier:
    provider: custom
    base_url: http://localhost:8317/v1
    api_key: local-proxy-key
  curator:
    provider: custom
    base_url: http://localhost:8317/v1
    api_key: local-proxy-key
```

Expected: 所有会在后台调用模型的任务都与主模型使用相同的代理地址和鉴权 key。若实际文件中还存在其他辅助任务，也按同样模式补齐。

- [ ] **Step 5: 回读配置确认已生效**

Run:

```bash
sed -n '/^model:/,/^[^ ]/p' ~/.hermes/config.yaml
printf '\n--- auxiliary ---\n'
sed -n '/^auxiliary:/,$p' ~/.hermes/config.yaml
printf '\n--- proxy ---\n'
cat ~/.cli-proxy-api/config.yaml
```

Expected: 主模型、所有辅助模型、代理允许的 key 三者完全一致，且 `auxiliary` 中不再出现空 `api_key`。

- [ ] **Step 6: Commit**

此任务修改的是 home 目录下配置文件，不在仓库中提交；如需记录，仅在执行日志中注明“已更新本地配置”。

---

### Task 3: Restart Services And Verify Both Paths

**Files:**
- Verify: `~/.cli-proxy-api/proxy.log`

- [ ] **Step 1: 重启 cli-proxy-api**

Run:

```bash
pkill -f "cli-proxy-api" || true
/home/bitq/cliproxyapi/cli-proxy-api -config ~/.cli-proxy-api/config.yaml > ~/.cli-proxy-api/proxy.log 2>&1 &
sleep 2
```

Expected: 命令正常返回，后台进程启动成功。

- [ ] **Step 2: 重启 Hermes Gateway**

Run:

```bash
hermes gateway restart
```

Expected: 输出显示 gateway 已重启，未出现配置解析错误。

- [ ] **Step 3: 先验证代理本身可用**

Run:

```bash
curl -s -X POST http://localhost:8317/v1/chat/completions \
  -H "Authorization: Bearer local-proxy-key" \
  -H "Content-Type: application/json" \
  -d '{"model":"gemini-3.1-pro-preview","messages":[{"role":"user","content":"test"}],"max_tokens":5}'
```

Expected: 返回 JSON 响应；如果这里直接返回 `401`，说明问题仍在代理配置或鉴权 key。

- [ ] **Step 4: 验证普通对话路径**

Run:

```bash
hermes -z "test"
```

Expected: 返回正常模型响应，不出现 `401 Invalid API key`。

- [ ] **Step 5: 验证 Skill 路径**

Run:

```bash
hermes -z "Use Skill: brainstorming"
```

Expected: Skill 可以启动或继续执行，不出现 `401 Invalid API key`。如果此时改为 `timeout`、`TCP timeout` 或连接失败，则说明鉴权问题已经剥离，应切换到网络可达性排查。

- [ ] **Step 6: 检查代理日志确认错误类型**

Run:

```bash
tail -n 50 ~/.cli-proxy-api/proxy.log
```

Expected: 日志中不再出现由错误 bearer token 导致的 `401`。若仍有失败，应能从日志判断是鉴权错误还是网络错误。

- [ ] **Step 7: Commit**

此任务只涉及服务重启与运行验证，不修改仓库文件，因此不提交代码。
