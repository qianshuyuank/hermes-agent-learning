# 任务1：官方文档整理

## 高频用法、核心概念、快速入门

> 基于 Hermes Agent 官方文档整理，2026-05-24

---

## 一、核心概念

### 1.1 什么是 Hermes Agent

Hermes 是由 Nous Research开发的开源 AI Agent 框架，可运行于终端、消息平台和 IDE。它与 Claude Code (Anthropic)、Codex (OpenAI) 属于同一类别——通过工具调用与系统交互的自主编码和任务执行 Agent。

**核心特性：**
- **自我改进** — 通过 Skills 持久化学习到的流程和知识
- **跨会话记忆** — 记住用户偏好、环境细节、经验教训
- **多平台网关** — 同时运行在 Telegram、Discord、Slack、WhatsApp 等10+平台
- **Provider 无关** — 可随时切换模型和 Provider
- **多实例隔离** — 通过 Profiles 运行多个独立实例

### 1.2 关键术语

| 术语 | 解释 |
|------|------|
| **Toolset** | 工具集，如 `web`, `terminal`, `file`, `delegation` 等 |
| **Skill** | 可复用的技能文档，持久化到 `~/.hermes/skills/` |
| **Profile** | 独立配置实例，包含独立配置、会话、技能和记忆 |
| **Gateway** | 消息网关，连接各消息平台 |
| **Provider** | LLM 提供者（OpenRouter、Anthropic、MiniMax 等） |
| **Session** | 会话历史，存储在 `~/.hermes/sessions/` |
| **Cron** | 定时任务调度器 |
| **Curator** | 自动化的技能生命周期管理 |

### 1.3 工具集（Toolsets）

核心工具集（默认启用）：

| 工具集 | 功能 |
|--------|------|
| `terminal` | Shell 命令和进程管理 |
| `file` | 文件读写/搜索/补丁 |
| `delegation` | 子 Agent 任务委托 |
| `cronjob` | 定时任务管理 |
| `skills` | 技能浏览和管理 |
| `memory` | 跨会话持久记忆 |
| `session_search` | 搜索历史对话 |
| `clarify` | 向用户提问澄清 |
| `messaging` | 跨平台消息发送 |
| `todo` | 会话内任务规划 |

可选工具集：`web`, `browser`, `vision`, `image_gen`, `video`, `tts`, `spotify`, `homeassistant`, `discord`, `kanban` 等。

---

## 二、快速入门

### 2.1 安装

```bash
curl -fsSL https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.sh | bash
```

### 2.2 基本使用

```bash
# 交互式聊天（默认）
hermes

# 单次查询
hermes chat -q "What is the capital of France?"

# 设置向导
hermes setup

# 更换模型
hermes model

# 健康检查
hermes doctor
```

### 2.3 首次配置

```bash
# 交互式配置向导
hermes setup

# 或手动设置模型
hermes config set model.provider openrouter
hermes config set model.default anthropic/claude-sonnet-4
```

### 2.4 关键配置路径

| 路径 | 说明 |
|------|------|
| `~/.hermes/config.yaml` | 主配置 |
| `~/.hermes/.env` | API 密钥 |
| `~/.hermes/skills/` | 安装的技能 |
| `~/.hermes/sessions/` | 会话历史 |
| `~/.hermes/logs/` | 日志 |
| `~/.hermes/auth.json` | OAuth 凭证 |

---

## 三、高频用法

### 3.1 模型和 Provider 管理

```bash
# 切换模型（交互式）
hermes model

# 配置多 Provider
hermes config set model.provider openrouter
hermes config set model.default anthropic/claude-sonnet-4

# 添加凭证池
hermes auth add
hermes auth list

# OAuth 登录
hermes login --provider nous
```

**支持的 Provider：**

| Provider | 环境变量 |
|----------|----------|
| OpenRouter | `OPENROUTER_API_KEY` |
| Anthropic | `ANTHROPIC_API_KEY` |
| DeepSeek | `DEEPSEEK_API_KEY` |
| MiniMax CN | `MINIMAX_CN_API_KEY` |
| Google Gemini | `GOOGLE_API_KEY` |
| Hugging Face | `HF_TOKEN` |

### 3.2 技能（Skills）管理

```bash
# 列出已安装技能
hermes skills list

# 浏览技能市场
hermes skills browse

# 搜索技能
hermes skills search QUERY

# 安装技能
hermes skills install SKILL_ID

# 加载技能到当前会话
/skill <name>

# 发布技能
hermes skills publish PATH
```

### 3.3 工具管理

```bash
# 列出所有工具
hermes tools list

# 启用/禁用工具集
hermes tools enable web
hermes tools disable browser

# 交互式管理
hermes tools
```

### 3.4 定时任务（Cron）

```bash
# 列出定时任务
hermes cron list

# 创建定时任务
hermes cron create "30m"
hermes cron create "every 2h"
hermes cron create "0 9 * * *"

# 编辑任务
hermes cron edit ID

# 暂停/恢复
hermes cron pause ID
hermes cron resume ID

# 手动触发
hermes cron run ID
```

**Cron 任务创建示例：**
```bash
hermes cron create "0 9 * * *" \
  --prompt "总结昨天的新闻并发送到邮箱" \
  --skill news-summarizer \
  --deliver telegram:-1001234567890
```

### 3.5 网关（Gateway）使用

```bash
# 启动网关
hermes gateway run

# 安装为后台服务
hermes gateway install

# 平台设置
hermes gateway setup

# 服务控制
hermes gateway start
hermes gateway stop
hermes gateway restart
hermes gateway status
```

**支持平台：** Telegram, Discord, Slack, WhatsApp, Signal, Email, SMS, Matrix, Mattermost, Home Assistant, DingTalk, Feishu, WeCom, WeChat, API Server, Webhooks

### 3.6 会话管理

```bash
# 列出最近会话
hermes sessions list

# 交互式选择
hermes sessions browse

# 恢复会话
hermes --continue
hermes --resume SESSION_ID

# 导出会话
hermes sessions export OUT.jsonl

# 重命名/删除
hermes sessions rename ID "新名称"
hermes sessions delete ID

# 清理旧会话
hermes sessions prune --older-than 30
```

### 3.7 多实例（Profiles）

```bash
# 列出实例
hermes profile list

# 创建实例
hermes profile create dev --clone

# 切换实例
hermes profile use dev

# 删除实例
hermes profile delete dev

# 导出/导入
hermes profile export dev
hermes profile import dev.tar.gz
```

---

## 四、Slash 命令（会话内）

### 4.1 会话控制

| 命令 | 说明 |
|------|------|
| `/new` 或 `/reset` | 新会话 |
| `/clear` | 清屏+新会话 |
| `/retry` | 重发上一条消息 |
| `/undo` | 撤销上一轮对话 |
| `/title [name]` | 命名会话 |
| `/compress` | 手动压缩上下文 |
| `/stop` | 终止后台进程 |
| `/rollback [N]` | 恢复文件系统检查点 |
| `/background <prompt>` | 后台执行 |
| `/queue <prompt>` | 排队下一轮执行 |
| `/resume [name]` | 恢复会话 |

### 4.2 配置调整

| 命令 | 说明 |
|------|------|
| `/model [name]` | 显示/切换模型 |
| `/personality [name]` | 设置人格 |
| `/verbose` | 切换详细模式 |
| `/yolo` | 切换绕过审批 |
| `/skills` | 管理技能 |
| `/tools` | 管理工具 |

### 4.3 信息查询

| 命令 | 说明 |
|------|------|
| `/help` | 显示命令列表 |
| `/status` | 会话信息 |
| `/usage` | Token 使用量 |
| `/insights` | 使用分析 |
| `/debug` | 上传调试报告 |

---

## 五、高级特性

### 5.1 子 Agent 委托（delegation）

```python
# 单任务委托
delegate_task(
    goal="研究 GRPO 论文并写总结",
    context="输出到 ~/research/grpo.md",
    toolsets=["web", "terminal", "file"]
)

# 并行多任务（最多3个）
delegate_task(tasks=[
    {"goal": "任务A", "toolsets": ["terminal"]},
    {"goal": "任务B", "toolsets": ["web"]},
    {"goal": "任务C", "toolsets": ["file"]}
])
```

### 5.2 MCP 服务器

```bash
# 启动 MCP 服务器
hermes mcp serve

# 添加 MCP 服务器
hermes mcp add NAME --url https://...
hermes mcp add NAME --command "npx ..."

# 列出/测试
hermes mcp list
hermes mcp test NAME
```

### 5.3 Webhook

```bash
# 创建 Webhook 路由
hermes webhook subscribe myhook

# 测试
hermes webhook test myhook

# 列出/删除
hermes webhook list
hermes webhook remove myhook
```

### 5.4 长期目标（Goal）

```bash
# 设置长期目标
/goal 每天早上9点汇总行业新闻

# 查看状态
/goal status

# 暂停/继续/清除
/goal pause
/goal resume
/goal clear
```

### 5.5 记忆系统

```bash
# 记忆状态
hermes memory status

# 设置记忆 Provider
hermes memory setup

# 关闭/开启
hermes memory off
hermes memory on
```

**Provider 选项：** 内置、Honcho、Mem0

---

## 六、配置参考

### 6.1 主要配置项

```yaml
model:
  default: anthropic/claude-sonnet-4
  provider: openrouter

agent:
  max_turns: 90
  tool_use_enforcement: true

terminal:
  backend: local
  cwd: ~
  timeout: 180

compression:
  enabled: true
  threshold: 0.50
  target_ratio: 0.20

memory:
  memory_enabled: true
  user_profile_enabled: true
  provider: memory

delegation:
  max_iterations: 50
  max_concurrent_children: 3

checkpoints:
  enabled: true
  max_snapshots: 50
```

### 6.2 安全配置

```bash
# 命令审批模式
hermes config set approvals.mode smart  # 推荐
hermes config set approvals.mode off    # 跳过所有审批

# 秘密编辑（API Key 自动遮蔽）
hermes config set security.redact_secrets true

# PII 编辑
hermes config set privacy.redact_pii true
```

---

## 七、故障排除

### 7.1 常见问题

```bash
# 健康检查
hermes doctor

# 检查配置
hermes config check

# 重置凭证
hermes auth reset PROVIDER

# 查看日志
grep -i "failed" ~/.hermes/logs/gateway.log | tail -20
```

### 7.2 工具不工作

1. `hermes tools list` — 确认工具集已启用
2. 检查 `.env` 中的环境变量
3. `/reset` 后生效（新会话）

### 7.3 配置不生效

- **工具/技能**：`/reset` 开始新会话
- **配置**：网关需要 `/restart`，CLI 需要重启

---

## 八、扩展开发

### 8.1 添加新工具（3步）

**1. 创建工具文件 `tools/example_tool.py`：**
```python
import json, os
from tools.registry import registry

def check_requirements() -> bool:
    return bool(os.getenv("EXAMPLE_API_KEY"))

def example_tool(param: str, task_id: str = None) -> str:
    return json.dumps({"success": True, "data": "..."})

registry.register(
    name="example_tool",
    toolset="example",
    schema={"name": "example_tool", "description": "...", "parameters": {...}},
    handler=lambda args, **kw: example_tool(
        param=args.get("param", ""), task_id=kw.get("task_id")),
    check_fn=check_requirements,
    requires_env=["EXAMPLE_API_KEY"],
)
```

**2. 添加到 `toolsets.py`** → `_HERMES_CORE_TOOLS` 列表

**3. 自动发现** — 无需手动注册，有 `registry.register()` 调用的 `tools/*.py` 会自动导入

### 8.2 添加 Slash 命令

1. 在 `hermes_cli/commands.py` 添加 `CommandDef` 到 `COMMAND_REGISTRY`
2. 在 `cli.py` → `process_command()` 添加处理器

### 8.3 测试

```bash
# 完整测试套件
python -m pytest tests/ -o 'addopts=' -q

# 特定区域
python -m pytest tests/tools/ -q
```

---

## 九、资源链接

| 资源 | 链接 |
|------|------|
| 官方文档 | https://hermes-agent.nousresearch.com/docs/ |
| GitHub | https://github.com/NousResearch/hermes-agent |
| Skills 市场 | `hermes skills browse` |
| 配置文件参考 | https://hermes-agent.nousresearch.com/docs/user-guide/configuration |
| CLI 命令参考 | https://hermes-agent.nousresearch.com/docs/reference/cli-commands |
| Slash 命令参考 | https://hermes-agent.nousresearch.com/docs/reference/slash-commands |
| Provider 指南 | https://hermes-agent.nousresearch.com/docs/integrations/providers |
| 消息平台文档 | https://hermes-agent.nousresearch.com/docs/user-guide/messaging/ |