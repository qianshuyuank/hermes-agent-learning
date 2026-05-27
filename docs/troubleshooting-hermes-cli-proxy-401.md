# Hermes + cli-proxy-api 401 认证错误排查指南

本文档总结了在使用 Hermes 结合本地 `cli-proxy-api` 代理时，可能遇到的 `401 Invalid API key` 错误的排查与修复方法。

---

## 1. 根本原因总结

### 1.1 主模型 API Key 占位符被拦截
Hermes 源码中内置了一个黑名单机制，如果 `model.api_key` 被设置为 `dummy`、`example`、`changeme` 等占位符，它会将其视为无效，并回退读取环境变量（如 `OPENAI_API_KEY` 或 `MINIMAX_CN_API_KEY`）。这导致实际发送给 `cli-proxy-api` 的鉴权 Key 是错误的，从而触发 401 错误。

**修复方法**：使用一个不在黑名单中的真实（或自定义）字符串作为 API Key。例如：`local-proxy-key`。

### 1.2 辅助模型配置覆盖 (以及环境变量干扰)
Hermes 在后台会运行诸多辅助任务（如：标题生成、Triage 分发、工具调用）。这些任务在 `~/.hermes/config.yaml` 中有独立的配置块。
如果仅修改了主模型的 API Key，当这些后台任务触发时可能会报错。
**特别是**：如果用户的 `~/.bashrc` 中导出了 `OPENAI_API_KEY`（例如指向了其他大模型供应商的占位符或真实 Key），当辅助模型的 `api_key` 为 `""` 且 `provider` 为 `auto` 时，Hermes 可能会 fallback 去读取系统环境变量 `OPENAI_API_KEY`，从而将错误的 Key 发送给本地代理。

**修复方法**：明确将所有辅助模型的 `provider` 设为 `custom`，并显式指定 `base_url` 和 `api_key`，避免受到环境变量污染：
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
```

### 1.3 服务重启未生效
- `cli-proxy-api`：修改了代理的配置文件后，旧的后台进程可能仍在内存中缓存旧配置。
- `Hermes Gateway`：Hermes 是以后台守护进程（Gateway Daemon）运行的。修改了 `~/.hermes/config.yaml` 后，如果未重启守护进程，修改将不会生效。

---

## 2. 修复实施步骤 (Checklist)

当遇到 401 错误时，请按以下顺序执行自检和修复：

### 第一步：检查代理服务配置
- [ ] 检查 `~/.cli-proxy-api/config.yaml`，确保 `api-keys` 列表中使用的是自定义的非占位符 Key（如 `local-proxy-key`），**不要使用 `dummy`**。

### 第二步：检查 Hermes 主模型配置
- [ ] 检查 `~/.hermes/config.yaml`，确保 `model.api_key` 与代理服务中的 Key 严格一致。

### 第三步：清理 Hermes 辅助模型配置
- [ ] 检查 `~/.hermes/config.yaml`，确保所有辅助任务（如 `title_generation`, `triage_specifier` 等）的 `provider` 设为 `custom`，`base_url` 设为代理地址，`api_key` 设为与主模型一致的 Key。不要留空（`""`），以防受到 `OPENAI_API_KEY` 环境变量的干扰。

### 第四步：清理后台并重启服务
配置修改后，**必须**重启所有相关后台进程：

```bash
# 1. 重启代理服务 (必须带上 -config 参数指定绝对路径，否则代理可能因找不到配置文件而崩溃)
pkill -f "cli-proxy-api"
/home/bitq/cliproxyapi/cli-proxy-api -config ~/.cli-proxy-api/config.yaml > ~/.cli-proxy-api/proxy.log 2>&1 &

# 2. 重启 Hermes 守护进程
hermes gateway restart
```

### 第五步：连通性验证
- [ ] 测试代理本身是否连通：
```bash
curl -s -X POST http://localhost:8317/v1/chat/completions \
  -H "Authorization: Bearer local-proxy-key" \
  -H "Content-Type: application/json" \
  -d '{"model":"gemini-3.1-pro-preview","messages":[{"role":"user","content":"test"}],"max_tokens":5}'
```
- [ ] 测试 Hermes 是否连通：
```bash
hermes -z "test"
```
- [ ] 测试后台/技能是否连通：
```bash
hermes -z "Use Skill: brainstorming"
```

---

## 3. 其他可能导致报错的网络因素
如果认证 (401) 问题已解决，但出现 `500 Internal Server Error (TCP timeout)`，这通常是因为代理请求上游 API (如 `oauth2.googleapis.com`) 时受到网络环境限制。
**解决方法**：请确保宿主机开启了 TUN 模式或正确配置了全局代理规则。
