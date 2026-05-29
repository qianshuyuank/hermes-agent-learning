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

### 1.4 新终端自动 source `~/.bashrc` 导致复发
如果 Hermes 终端配置启用了自动 source `~/.bashrc`，那么每次重新打开新的 Hermes 终端时，shell 环境变量都会再次被注入当前会话。
在已经存在 `OPENAI_API_KEY`、`MINIMAX_CN_API_KEY` 等环境变量的机器上，这会放大 fallback 链路被污染的概率，使问题表现为“刚修好，重开终端后又出现 401”。

**修复方法**：在 Hermes 终端配置中关闭自动 source shell 初始化文件，例如：
```yaml
terminal:
  auto_source_bashrc: false
```

---

## 2. 修复实施步骤 (Checklist)

当遇到 401 错误时，请按以下顺序执行自检和修复：

### 第一步：检查代理服务配置
- [ ] 检查 `~/.cli-proxy-api/config.yaml`，确保 `api-keys` 列表中使用的是自定义的非占位符 Key（如 `local-proxy-key`），**不要使用 `dummy`**。

### 第二步：检查 Hermes 主模型配置
- [ ] 检查 `~/.hermes/config.yaml`，确保 `model.api_key` 与代理服务中的 Key 严格一致。

### 第三步：清理 Hermes 辅助模型配置
- [ ] 检查 `~/.hermes/config.yaml`，确保所有辅助任务（如 `title_generation`, `triage_specifier` 等）的 `provider` 设为 `custom`，`base_url` 设为代理地址，`api_key` 设为与主模型一致的 Key。不要留空（`""`），以防受到 `OPENAI_API_KEY` 环境变量的干扰。

### 第四步：检查终端是否会重新注入环境变量
- [ ] 检查 Hermes 终端配置是否启用了 `auto_source_bashrc: true`。如果开启，每次新终端都可能重新加载 `~/.bashrc` 中的 `OPENAI_API_KEY` 等变量，导致 401 在重开终端后复发。
- [ ] 建议改为 `auto_source_bashrc: false`，除非你明确依赖 shell 初始化逻辑。

### 第五步：清理后台并重启服务
配置修改后，**必须**重启所有相关后台进程：

```bash
# 1. 重启代理服务 (必须带上 -config 参数指定绝对路径，否则代理可能因找不到配置文件而崩溃)
pkill -f "cli-proxy-api"
/home/bitq/cliproxyapi/cli-proxy-api -config ~/.cli-proxy-api/config.yaml > ~/.cli-proxy-api/proxy.log 2>&1 &

# 2. 重启 Hermes 守护进程
hermes gateway restart
```

### 第六步：连通性验证
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

**判定说明：**
- 如果前两个命令都成功，说明主链路的鉴权已经恢复，`401` 问题基本可以判定为已解决。
- 第三个命令用于触发辅助模型/Skill 链路，但它**不是最理想的 oneshot 健康检查**，因为 `brainstorming` 本身是偏交互式的 Skill，可能进入等待提问、等待确认，或者在 CLI 中表现为卡住后被手动中断。
- 因此，若执行 `hermes -z "Use Skill: brainstorming"` 时没有直接出现 `401`，而是表现为等待、中断，或后续出现 `500`，不要再将其归类为鉴权问题，应结合代理日志继续区分是 Skill 的交互特性，还是上游网络问题。
- 如果你已经修复主模型、辅助模型和代理配置，但只要重新打开 Hermes 终端就再次出现 `401`，应优先检查是否是新终端重新 source `~/.bashrc` 导致环境变量重新污染。
- 建议在修改终端配置后，关闭当前 Hermes 会话，重新打开一个全新的 Hermes 终端，再重复执行 `hermes -z "test"` 与必要的 Skill 验证。
- 建议同时检查代理日志：
```bash
tail -n 50 ~/.cli-proxy-api/proxy.log
```
- 如果日志中连续出现多个 `200`，最后才出现单个 `500`，这说明本地 Bearer Token 已经被正确接受，问题已经从 `401` 鉴权错误切换为上游请求失败或网络问题。

---

## 3. 其他可能导致报错的网络因素
如果认证 (401) 问题已解决，但出现 `500 Internal Server Error (TCP timeout)`，这通常是因为代理请求上游 API (如 `oauth2.googleapis.com`) 时受到网络环境限制。
**解决方法**：请确保宿主机开启了 TUN 模式或正确配置了全局代理规则。

### 3.1 本轮排查新增结论
根据本轮实际验证，出现了如下更细的分界：

- `curl` 直连本地代理成功：说明 `cli-proxy-api` 配置与 `Authorization: Bearer local-proxy-key` 已经匹配。
- `hermes -z "test"` 成功：说明 Hermes 主模型链路已经不再触发 `401`。
- `hermes -z "Use Skill: brainstorming"` 未再出现 `401`，但在代理日志中可见多次 `200` 后出现单个 `500`：这说明辅助模型链路的鉴权也已经基本恢复，剩余问题更接近上游超时、Google OAuth 请求失败，或宿主机网络代理规则未覆盖到 Gemini 相关流量。

换言之：

- **`401 Invalid API key`**：优先排查本地配置、辅助模型覆盖、环境变量污染、服务未重启。
- **`500 Internal Server Error` / `TCP timeout` / `oauth2.googleapis.com` 超时**：优先排查宿主机网络、TUN 模式、全局代理、DNS 或出口连通性。
