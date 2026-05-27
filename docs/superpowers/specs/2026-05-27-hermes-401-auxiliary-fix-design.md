# Hermes 401 认证错误修复 (辅助模型) 设计方案

## 问题背景
用户反馈在成功对话两次后，或者使用 `brainstorming` Skill 时，再次出现 401 Invalid API key 错误。
经排查发现，这并非由于访问速度过快导致的服务器封控（429 错误），而是由于 Hermes 内部的**辅助模型配置（Auxiliary Models）**导致的。

## 根本原因 (Root Cause)
Hermes 在后台会运行一些辅助任务（如：生成对话标题、Triage 分发、总结上下文、Skill 内部调用等）。在 `~/.hermes/config.yaml` 中，这些辅助任务（如 `title_generation`, `triage_specifier`, `curator` 等）的 `api_key` 被单独配置为了 `sk-test-localhost-99999`。
当我们之前修复主模型配置时，只修改了主模型的 `api_key` 为 `local-proxy-key`，而没有修改这些辅助模型的配置。因此，当 Hermes 触发这些后台任务时，仍然发送了 `sk-test-localhost-99999`，被本地代理 `cli-proxy-api` 拒绝，从而抛出 401 错误。

## 解决方案设计
1. **清空辅助模型 API Key**：将 `~/.hermes/config.yaml` 中所有辅助任务的 `api_key: sk-test-localhost-99999` 的配置项，统一替换为 `api_key: ""`（空字符串）。
2. **避免影响其他模型**：将其设置为空字符串后，Hermes 的辅助任务会自动继承主模型（或环境变量）的鉴权信息。这样不仅能解决当前代理的 401 错误，还能保证当您切换到 Minimax 等其他模型时，辅助任务也能正确继承相应的 API Key 而不报错。
3. **无需重启代理**：由于代理端 `cli-proxy-api` 已经正确配置为接收 `local-proxy-key`，只需修正 Hermes 客户端的配置即可。
