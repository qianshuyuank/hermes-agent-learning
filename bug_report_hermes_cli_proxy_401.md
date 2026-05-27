# Hermes + cli-proxy-api 401 认证错误 Bug 报告

**日期**: 2025-05-25  
**环境**: Ubuntu (Linux 6.8.0-111-generic)  
**用户**: bitq

---

## 问题描述

在新终端中启动 Hermes 时，通过 custom provider 调用 cli-proxy-api 代理的 Gemini 模型时报 401 认证错误：

```
API call failed (attempt 1/3): AuthenticationError [HTTP 401]
   🔌 Provider: custom  Model: gemini-3.1-pro-preview
   🌐 Endpoint: http://localhost:8317/v1
   📝 Error: HTTP 401: Error code: 401 - {'error': 'Invalid API key'}
```

---

## 已确认正常的组件

### 1. cli-proxy-api 服务 (PID: 644609)
```bash
$ ps aux | grep cli-proxy
bitq  644609  0.0  0.2  1302064  32984  ?  Ssl  5月25  0:00  /home/bitq/cliproxyapi/cli-proxy-api

$ ss -tlnp | grep 8317
LISTEN  0  4096  *:8317  *:*  users:(("cli-proxy-api",pid=644609,fd=8))
```

### 2. cli-proxy-api 配置文件
```yaml
# ~/.cli-proxy-api/config.yaml
host: ""
port: 8317
auth-dir: "~/.cli-proxy-api"
api-keys:
  - dummy
```

### 3. curl 直接测试 - 成功 ✓
```bash
$ curl -s -X POST http://localhost:8317/v1/chat/completions \
  -H "Authorization: Bearer dummy" \
  -H "Content-Type: application/json" \
  -d '{"model":"gemini-3.1-pro-preview","messages":[{"role":"user","content":"test"}],"max_tokens":5}'
  
{"id":"...","model":"gemini-3.1-pro-preview","choices":[{"message":{"content":"..."}}],...}
```

### 4. 模型列表确认
```bash
$ curl -s http://localhost:8317/v1/models -H "Authorization: Bearer dummy" | python3 -c "import sys,json; [print(m['id']) for m in json.load(sys.stdin)['data']]"
gemini-3-pro-preview
gemini-3.1-pro-preview
gemini-3-flash-preview
gemini-3.1-flash-lite-preview
gemini-2.5-pro
gemini-2.5-flash
gemini-2.5-flash-lite
```

---

## 配置文件

### ~/.hermes/config.yaml (相关部分)
```yaml
model:
  default: gemini-3.1-pro-preview  # 已从 gemini-2.5-flash 修改
  provider: custom
  base_url: http://localhost:8317/v1
  api_key: dummy                   # 第 5 行

providers: {}
fallback_providers: []
```

### ~/.bashrc (相关部分)
```bash
# 第 127 行
export HERMES_DEFAULT_MODEL="abab6.5-chat"  # MiniMax CN 模型
```

---

## 调查过程

### 1. 直接 curl 测试 → 成功
cli-proxy-api 本身正常工作，`dummy` API key 有效。

### 2. Hermes 当前配置 → 看起来正确
config.yaml 中 `api_key: dummy` 与 cli-proxy-api 白名单匹配。

### 3. 问题分析

**假设**: Hermes 启动时，可能从某个地方读取了错误的 api_key 或配置覆盖。

可能的原因：
1. 环境变量覆盖 `api_key` 配置
2. 辅助服务（如 vision, web_extract 等）使用不同的 api_key 设置失败
3. 启动脚本中设置了不同的 api_key
4. Hermes 版本问题或 custom provider 实现问题

---

## 待验证

1. Herms 启动时的实际环境变量
2. Herms 发送到 cli-proxy-api 的实际请求（需要抓包）
3. 辅助服务的 api_key 配置（全部是 `sk-tes...9999` 掩码值）

---

## 当前状态

- cli-proxy-api: 运行正常 ✓
- curl 直接调用: 成功 ✓  
- Hermes 调用: 失败 ✗ (401)
- 配置修改后重启: 完成 ✓

---

## 复现步骤

1. 在新终端中执行 `hermes` 或 `hermes gateway run`
2. 发送任何消息
3. 触发 401 错误

---

## 相关文件路径

- `/home/bitq/.hermes/config.yaml` - Hermes 配置
- `/home/bitq/.bashrc` - Shell 环境变量 (含 HERMES_DEFAULT_MODEL)
- `/home/bitq/.hermes/.env` - Herms 环境变量
- `/home/bitq/.cli-proxy-api/config.yaml` - cli-proxy-api 配置
- `/home/bitq/cliproxyapi/cli-proxy-api` - cli-proxy-api 可执行文件
- `/home/bitq/.hermes/hermes-agent/` - Herms Agent 安装目录