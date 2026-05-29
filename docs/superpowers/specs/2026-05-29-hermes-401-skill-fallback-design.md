# Hermes 401 技能场景回退鉴权问题设计方案

## 问题背景
用户反馈 Gemini 在普通对话开始时通常可以访问，但在继续对话几次后，或者进入 `brainstorming` 等 Skill 场景时，会再次出现 `401 Invalid API key`。

结合已有排查文档与历史设计记录，这类现象更符合 Hermes 在后台辅助任务链路中发送了错误 API Key，而不是上游 Gemini 服务被封控。若是网络限制或上游不可达，更常见的表现应为 `500 Internal Server Error (TCP timeout)`、连接超时，或与 `oauth2.googleapis.com` 相关的访问失败，而非 `401`。

## 目标
本次设计的目标不是直接处理所有 Gemini 网络可用性问题，而是先将当前故障明确收敛到本地鉴权链路，确保以下两条路径都使用相同的本地代理配置：

1. 普通对话主模型调用。
2. Skill、标题生成、Triage 等辅助模型调用。

## 根本原因假设
当前最可能的根因是以下两类之一，或两者叠加：

1. `~/.hermes/config.yaml` 中部分 `auxiliary` 任务的 `provider`、`base_url` 或 `api_key` 与主模型不一致，导致 Skill 场景使用了另一套鉴权配置。
2. 某些 `auxiliary` 任务的 `api_key` 留空，触发 Hermes 回退读取系统环境变量，例如 `OPENAI_API_KEY`，最终把其他供应商的 Key 发送给本地 `cli-proxy-api`，从而触发 `401`。

## 非目标
- 不将当前 `401` 直接归因于 Gemini 上游封控。
- 不在本设计中处理 TUN、全局代理或宿主机网络策略问题，除非错误类型已经从 `401` 变化为超时或连接失败。

## 设计方案

### 1. 统一主模型与辅助模型配置
将 `~/.hermes/config.yaml` 中主模型与所有 `auxiliary` 任务统一固定为本地代理配置，而不是依赖隐式继承或环境变量回退。

推荐配置原则如下：

- `provider` 固定为 `custom`
- `base_url` 固定为 `http://localhost:8317/v1`
- `api_key` 固定为 `local-proxy-key`

不建议将 `auxiliary.api_key` 设置为空字符串。虽然空字符串看似可以继承主模型，但在当前问题场景下，这会引入环境变量污染风险，使 Skill 链路与主模型链路发生分叉。

### 2. 统一代理允许的 API Key
检查 `~/.cli-proxy-api/config.yaml`，确保 `api-keys` 中包含且仅包含 Hermes 当前应发送的本地 Key，例如 `local-proxy-key`。这样可以避免旧测试 Key、占位符 Key 或其他历史残留值继续干扰判断。

### 3. 明确环境变量仅作背景信息，不参与本链路鉴权
保留 `OPENAI_API_KEY`、`MINIMAX_CN_API_KEY` 等环境变量并非绝对错误，但本次设计要求 Hermes 调用本地代理时不再依赖这些变量参与决策。只要 `auxiliary` 配置被显式写死，环境变量就不会再成为本故障的主因。

### 4. 配置变更后强制重启后台进程
即便配置文件已经修正，如果 `cli-proxy-api` 或 Hermes Gateway 仍在使用旧进程，旧配置可能仍会驻留在内存中。因此修复后必须同时重启：

- `cli-proxy-api`
- `hermes gateway`

## 验证流程

### 第一步：配置核对
按以下顺序检查配置是否一致：

1. `~/.hermes/config.yaml` 中主模型配置。
2. `~/.hermes/config.yaml` 中所有 `auxiliary` 子项。
3. `~/.cli-proxy-api/config.yaml` 中允许的 `api-keys`。
4. 当前 shell 或 `~/.bashrc` 中可能干扰回退行为的环境变量。

### 第二步：行为验证
修复并重启后，必须分别验证两条路径：

1. 普通对话路径：确认主模型调用不再出现 `401`。
2. Skill 路径：使用 `Use Skill: brainstorming` 等触发辅助任务，确认后台链路也不再出现 `401`。

### 第三步：错误分类切换
如果上述两条路径均不再出现 `401`，但随后改为出现超时、TCP timeout 或上游连接失败，则说明鉴权问题已被剥离，此时才进入网络封控或上游可达性排查。

## 验收标准
- 普通对话可以稳定调用本地代理，不再出现 `401 Invalid API key`。
- `brainstorming` 等 Skill 场景也不再出现 `401 Invalid API key`。
- 修复后若仍有故障，其错误类型应从鉴权错误切换为网络类错误，便于进入下一阶段排查。

## 风险与注意事项
- 只修正主模型、不修正 `auxiliary`，会导致问题在 Skill 场景中复发。
- 将 `auxiliary.api_key` 留空会让环境变量 fallback 继续成为不稳定因素。
- 修改配置后若未重启后台进程，可能出现“文件已正确、运行态仍报错”的假象。
