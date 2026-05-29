# Hermes 401 一键修复脚本设计方案

## 问题背景
用户反馈每次重新打开 Hermes 终端后，`401 Invalid API key` 问题有再次出现的倾向。结合现有排查文档与示例配置，这类问题更像是“终端重入后环境重新加载，导致 Hermes 鉴权链路再次被污染”，而不是单次配置失误。

仓库中的 `config/hermes.config.yaml` 已启用 `terminal.auto_source_bashrc: true`。这意味着每次新的终端会话都可能重新加载 `~/.bashrc` 中的环境变量。如果 Hermes 某些链路仍会 fallback 到 `OPENAI_API_KEY` 等变量，就可能让问题在“重新打开终端”后再次复发。

## 目标
本次设计聚焦于提供一个可重复执行的一键修复脚本，用于：

1. 统一 Hermes 与 `cli-proxy-api` 的本地鉴权配置。
2. 避免占位符 key、旧 key、空 `api_key` 或环境变量 fallback 造成的链路分叉。
3. 在执行后自动重启相关服务并做基础验证。
4. 将人工 checklist 收敛为一个稳定、低摩擦的日常修复入口。

## 非目标
- 不修改 Hermes 源码本身。
- 不在本次设计中自动处理宿主机 TUN、全局代理、DNS 或上游 Gemini 网络可达性问题。
- 不直接提供新的常驻启动包装脚本，本次只交付“一键修复脚本”。

## 方案对比

### 方案 A：只保留文档 checklist
优点：实现成本最低。
缺点：仍依赖人工执行，容易漏掉辅助模型配置、旧进程重启和验证步骤，不能解决“重复打开终端又忘了修”的问题。

### 方案 B：只做只读检查脚本
优点：风险低，不会修改用户环境。
缺点：每次发现异常后仍需人工修复，无法显著降低重复劳动。

### 方案 C：一键修复脚本
优点：直接覆盖当前最常见故障路径，能把备份、修复、重启、验证串成一次执行，最符合当前用户诉求。
缺点：会修改本地配置文件，需要谨慎做备份与输出说明。

推荐采用方案 C。

## 设计方案

### 1. 脚本位置与职责
新增仓库脚本 `scripts/fix-hermes-proxy-401.sh`，职责限定为：

- 备份 `~/.hermes/config.yaml`
- 备份 `~/.cli-proxy-api/config.yaml`
- 检查并修正本地代理允许的 `api-keys`
- 检查并修正 Hermes 主模型与全部 `auxiliary` 的 `provider`、`base_url`、`api_key`
- 重启 `cli-proxy-api`
- 重启 `hermes gateway`
- 执行基础连通性验证
- 输出成功/失败分类及下一步建议

脚本不依赖仓库内示例配置直接覆盖 home 目录文件，而是以当前本地文件为目标进行备份和规范化修正。

### 2. 规范化规则
脚本写入的目标配置规则如下：

- Hermes 主模型：
  - `provider: custom`
  - `base_url: http://localhost:8317/v1`
  - `api_key: local-proxy-key`
- Hermes 所有 `auxiliary` 子项：
  - `provider: custom`
  - `base_url: http://localhost:8317/v1`
  - `api_key: local-proxy-key`
- `cli-proxy-api`：
  - `port: 8317`
  - `api-keys` 仅保留 `local-proxy-key`

这样做的核心目的，是彻底消除空 `api_key`、占位符 key 和环境变量 fallback 对鉴权链路的影响。

### 3. 脚本执行流程
脚本按以下顺序工作：

1. 前置检查：确认 `hermes`、`curl`、`python3`、`cli-proxy-api` 二进制存在。
2. 备份现有配置：按时间戳生成备份文件。
3. 修正 `~/.cli-proxy-api/config.yaml`。
4. 用脚本化方式修正 `~/.hermes/config.yaml` 中 `model` 与 `auxiliary`。
5. 回显修正后的关键配置摘要。
6. 重启 `cli-proxy-api`。
7. 重启 `hermes gateway`。
8. 依次验证：
   - `curl` 直连代理
   - `hermes -z "test"`
9. 输出诊断分流：
   - 若仍是 `401`，提示继续检查本地配置未生效或旧进程未退出。
   - 若变成 `500`、`timeout` 或上游连接错误，提示鉴权已基本恢复，应转向网络问题排查。

### 4. 错误处理
脚本需要明确以下失败场景：

- 配置文件不存在：给出初始化提示，不静默失败。
- 备份失败：立即退出，避免直接覆盖。
- 重启代理失败：输出代理日志路径。
- `curl` 验证失败：明确标识是本地代理层失败。
- `hermes -z "test"` 失败：标识为 Hermes 主链路失败。

脚本退出码遵循“任一步骤失败即非零退出”，便于后续手工排查或集成到其他自动化流程。

### 5. 测试与验证
本次更适合采用“脚本可执行验证”而不是新增复杂自动化单测，验证重点包括：

- 脚本能创建备份。
- 脚本能重写目标配置。
- 脚本能在成功路径下完成重启与连通性检查。
- 脚本在失败路径下给出清晰提示，不伪装成成功。

## 验收标准
- 用户执行一次脚本后，本地配置被统一到 `custom + localhost:8317/v1 + local-proxy-key`。
- 代理层 `curl` 验证不再出现 `401 Invalid API key`。
- Hermes 主链路验证不再出现 `401 Invalid API key`。
- 脚本输出中能明确区分“仍是鉴权错误”与“已转为网络错误”。

## 风险与注意事项
- 若用户本地存在定制模型或非 Gemini 配置，本脚本会将相关链路统一到本地代理，应在输出中明确说明。
- 若 `cli-proxy-api` 实际安装路径不是 `/home/bitq/cliproxyapi/cli-proxy-api`，脚本需要允许通过变量覆盖或自动探测。
- 若问题根因已从 `401` 切换到上游超时，本脚本只能帮助确认问题边界，不能替代网络排障。
