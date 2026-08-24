# Hermes Direct MiniMax Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move the active Hermes runtime from local proxy routing to direct MiniMax access and retire the proxy only after successful validation.

**Architecture:** Detect the correct MiniMax endpoint first, then update the active Hermes config in place and restart the user-level gateway service. Keep the proxy intact until a direct Hermes request succeeds, then disable and remove the proxy service artifacts.

**Tech Stack:** Hermes config YAML, MiniMax OpenAI-compatible API, `systemd --user`, shell verification commands

---

### Task 1: Back Up Active Runtime State

**Files:**
- Modify: `/home/bitq/.hermes/config.yaml`
- Inspect: `/home/bitq/.config/systemd/user/cliproxyapi.service`

- [ ] **Step 1: Create a timestamped backup of the active Hermes config**

```bash
cp /home/bitq/.hermes/config.yaml /home/bitq/.hermes/config.yaml.bak.$(date +%Y%m%d%H%M%S)
```

- [ ] **Step 2: Save the current proxy service definition for rollback**

```bash
systemctl --user cat cliproxyapi.service > /home/bitq/.hermes/cliproxyapi.service.snapshot
```

- [ ] **Step 3: Verify both backup artifacts exist**

```bash
ls -l /home/bitq/.hermes/config.yaml.bak.* /home/bitq/.hermes/cliproxyapi.service.snapshot
```

### Task 2: Detect the Correct MiniMax Endpoint

**Files:**
- Modify: `/home/bitq/.hermes/.env`

- [ ] **Step 1: Probe the global MiniMax OpenAI-compatible endpoint with the provided key**

```bash
curl -sS https://api.minimax.io/v1/models \
  -H "Authorization: Bearer $MINIMAX_TEST_KEY"
```

- [ ] **Step 2: Probe the China MiniMax OpenAI-compatible endpoint with the provided key**

```bash
curl -sS https://api.minimaxi.com/v1/models \
  -H "Authorization: Bearer $MINIMAX_TEST_KEY"
```

- [ ] **Step 3: Persist only the working provider key into `/home/bitq/.hermes/.env`**

```bash
MINIMAX_API_KEY=...
# or
MINIMAX_CN_API_KEY=...
```

### Task 3: Reconfigure Hermes for Direct MiniMax

**Files:**
- Modify: `/home/bitq/.hermes/config.yaml`

- [ ] **Step 1: Replace the proxy-based model block with a direct MiniMax provider block**

```yaml
model:
  api_key: ""
  base_url: ""
  default: "<validated-model-id>"
  provider: minimax
```

- [ ] **Step 2: If the China endpoint is the only working path, use the China provider instead**

```yaml
model:
  api_key: ""
  base_url: ""
  default: "<validated-model-id>"
  provider: minimax-cn
```

- [ ] **Step 3: Keep the rest of the config unchanged and verify the updated model block**

```bash
sed -n '1,8p' /home/bitq/.hermes/config.yaml
```

### Task 4: Restart and Verify Hermes Direct Access

**Files:**
- Inspect: `/home/bitq/.hermes/config.yaml`

- [ ] **Step 1: Restart the Hermes gateway**

```bash
systemctl --user restart hermes-gateway.service
systemctl --user is-active hermes-gateway.service
```

- [ ] **Step 2: Verify Hermes can answer a minimal request through MiniMax**

```bash
hermes -z "test"
```

- [ ] **Step 3: Stop immediately if the request fails and capture the exact error**

```bash
journalctl --user -u hermes-gateway.service -n 50 --no-pager
```

### Task 5: Retire the Local Proxy

**Files:**
- Modify: `/home/bitq/.config/systemd/user/cliproxyapi.service`
- Modify: `/home/bitq/.cli-proxy-api/config.yaml`

- [ ] **Step 1: Stop and disable the proxy service only after Hermes direct validation passes**

```bash
systemctl --user stop cliproxyapi.service
systemctl --user disable cliproxyapi.service
```

- [ ] **Step 2: Remove the user service file and reload the user daemon**

```bash
rm -f /home/bitq/.config/systemd/user/cliproxyapi.service
systemctl --user daemon-reload
```

- [ ] **Step 3: Remove the local proxy config directory if no longer needed**

```bash
rm -rf /home/bitq/.cli-proxy-api
```
