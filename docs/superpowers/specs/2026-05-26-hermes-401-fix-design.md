# Hermes 401 认证错误修复设计方案

## 问题背景
在启动 Hermes 时，通过 custom provider 调用 `cli-proxy-api` 代理的 Gemini 模型时报 401 认证错误。
经过排查发现，Hermes 源码 (`hermes_cli/auth.py`) 中包含一个 `_PLACEHOLDER_SECRET_VALUES` 列表，其中 `dummy` 被视为无效的占位符密钥。因此，当 Hermes 读取 `~/.hermes/config.yaml` 中配置的 `api_key: dummy` 时，会将其判定为无效并忽略，进而退而求其次读取了环境变量 `OPENAI_API_KEY`（在 `~/.bashrc` 中配置为 Minimax 密钥）。最终导致 Hermes 将错误的密钥发送给代理服务，触发 401 错误。

## 解决方案架构
为了不修改 Hermes 的源码逻辑并彻底解决该冲突，我们将把 Hermes 与代理服务通信的 API Key 替换为一个不在占位符黑名单中的有效字符串。

### 1. 修改 `cli-proxy-api` 配置
- **目标文件**: `~/.cli-proxy-api/config.yaml`
- **修改内容**:
  将 `api-keys` 列表下的 `dummy` 修改为 `local-proxy-key`。

### 2. 修改 Hermes 配置
- **目标文件**: `~/.hermes/config.yaml`
- **修改内容**:
  将 `model.api_key` 的值从 `dummy` 修改为 `local-proxy-key`。

### 3. 重启并验证
- **操作**: 找到当前运行的 `cli-proxy-api` 进程，将其结束并重新启动。
- **验证**: 重新使用 Hermes 执行聊天命令（如 `hermes chat "hello"`），验证是否能够成功通信并不再报 401 错误。

## 影响范围
- 仅影响本地的 `cli-proxy-api` 服务以及 Hermes 的配置。不影响其他模型提供商的连接。
- 保证 Hermes 能安全正确地将此 custom token 发送，避免密钥泄露到错误的服务端点。