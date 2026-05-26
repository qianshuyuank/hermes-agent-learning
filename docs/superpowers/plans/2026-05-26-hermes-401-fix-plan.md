# Hermes 401 认证错误修复 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 修复 Hermes 使用 custom provider 访问本地 `cli-proxy-api` 时遇到的 401 认证错误。

**Architecture:** 主要是通过修改配置文件中使用的 API Key，将原有的占位符 `dummy` 替换为不受 Hermes 内部规则限制的有效密钥 `local-proxy-key`，避免回退使用环境变量中的错误密钥。

**Tech Stack:** YAML 配置、Bash。

---

### Task 1: Update cli-proxy-api configuration

**Files:**
- Modify: `~/.cli-proxy-api/config.yaml`

- [ ] **Step 1: Check existing proxy config**

```bash
cat ~/.cli-proxy-api/config.yaml
```
Expected: output shows `api-keys:` containing `- dummy`

- [ ] **Step 2: Replace 'dummy' with 'local-proxy-key'**

Modify `~/.cli-proxy-api/config.yaml` to change `dummy` to `local-proxy-key`:

```yaml
host: ""
port: 8317
auth-dir: "~/.cli-proxy-api"
api-keys:
  - local-proxy-key
```

- [ ] **Step 3: Commit config change (if tracked)**
*(Not applicable for home directory config files, but note for completeness)*

---

### Task 2: Update Hermes configuration

**Files:**
- Modify: `~/.hermes/config.yaml`

- [ ] **Step 1: Check existing Hermes config**

```bash
cat ~/.hermes/config.yaml | grep -A 5 "model:"
```
Expected: output shows `api_key: dummy`

- [ ] **Step 2: Replace 'dummy' with 'local-proxy-key'**

Modify `~/.hermes/config.yaml` to change `api_key: dummy` to `api_key: local-proxy-key`:

```yaml
model:
  default: gemini-3.1-pro-preview
  provider: custom
  base_url: http://localhost:8317/v1
  api_key: local-proxy-key
```

---

### Task 3: Restart proxy and verify

- [ ] **Step 1: Find and kill existing proxy process**

```bash
pkill -f "cli-proxy-api"
```

- [ ] **Step 2: Start proxy in background**

```bash
/home/bitq/cliproxyapi/cli-proxy-api > ~/.cli-proxy-api/proxy.log 2>&1 &
```

- [ ] **Step 3: Verify the proxy is running**

```bash
ps aux | grep cli-proxy
```
Expected: The process is listed.

- [ ] **Step 4: Verify the fix with Hermes**

```bash
hermes chat "hello"
```
Expected: Returns a successful completion instead of a 401 AuthenticationError.
