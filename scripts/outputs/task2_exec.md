# 任务2：网络优质资源筛选

## 常用技能、优质教程、社区资源甄别

> 整理精选的 Hermes Agent 优质学习资源，2026-05-25

---

## 资源分类概览

本章节按以下**分类**整理资源：
- **官方资源** — 文档、Blog、GitHub
- **社区项目** — GitHub 热门项目、生态项目
- **Skills 技能** — 官方和社区精选技能
- **学习路径** — 入门/进阶/高手路径
- **Provider** — 模型提供商选择
- **工具链** — 配合使用的工具

---

## 一、官方资源（首选）

### 1.1 官方文档站

| 资源 | 链接 | 说明 |
|------|------|------|
| [官方文档首页](https://hermes-agent.nousresearch.com/docs/) | https://hermes-agent.nousresearch.com/docs/ | 最权威的文档入口 |
| [GitHub 仓库](https://github.com/NousResearch/hermes-agent) | https://github.com/NousResearch/hermes-agent | 源码、Issue、Releases |
| [Skills 市场](https://hermes-agent.nousresearch.com/docs/reference/skills-catalog) | https://hermes-agent.nousresearch.com/docs/reference/skills-catalog | 官方技能库 |

### 1.2 关键文档页面

| 文档 | 链接 |
|------|------|
| [快速入门](https://hermes-agent.nousresearch.com/docs/) | https://hermes-agent.nousresearch.com/docs/ |
| [配置指南](https://hermes-agent.nousresearch.com/docs/user-guide/configuration) | https://hermes-agent.nousresearch.com/docs/user-guide/configuration |
| [CLI 命令参考](https://hermes-agent.nousresearch.com/docs/reference/cli-commands) | https://hermes-agent.nousresearch.com/docs/reference/cli-commands |
| [Slash 命令参考](https://hermes-agent.nousresearch.com/docs/reference/slash-commands) | https://hermes-agent.nousresearch.com/docs/reference/slash-commands |
| [Provider 指南](https://hermes-agent.nousresearch.com/docs/integrations/providers) | https://hermes-agent.nousresearch.com/docs/integrations/providers |
| [消息平台文档](https://hermes-agent.nousresearch.com/docs/user-guide/messaging/) | https://hermes-agent.nousresearch.com/docs/user-guide/messaging/ |
| [定时任务 Cron](https://hermes-agent.nousresearch.com/docs/user-guide/features/cron) | https://hermes-agent.nousresearch.com/docs/user-guide/features/cron |
| [记忆系统](https://hermes-agent.nousresearch.com/docs/user-guide/features/memory) | https://hermes-agent.nousresearch.com/docs/user-guide/features/memory |
| [MCP 服务器](https://hermes-agent.nousresearch.com/docs/user-guide/features/mcp) | https://hermes-agent.nousresearch.com/docs/user-guide/features/mcp |
| [Skills 开发](https://hermes-agent.nousresearch.com/docs/developer-guide/) | https://hermes-agent.nousresearch.com/docs/developer-guide/ |
| [工具参考](https://hermes-agent.nousresearch.com/docs/reference/tools-reference) | https://hermes-agent.nousresearch.com/docs/reference/tools-reference |
| [环境变量参考](https://hermes-agent.nousresearch.com/docs/reference/environment-variables) | https://hermes-agent.nousresearch.com/docs/reference/environment-variables |

### 1.3 官方 Blog/更新

| 资源 | 链接 |
|------|------|
| [Nous Research Blog](https://nousresearch.com/blog/) | https://nousresearch.com/blog/ |
| [GitHub Releases](https://github.com/NousResearch/hermes-agent/releases) | https://github.com/NousResearch/hermes-agent/releases |

---

## 二、社区精选项目

### 2.1 GitHub 热门项目

| 项目 | Stars | 链接 | 说明 |
|------|-------|------|------|
| **superpowers** | 204k | https://github.com/obra/superpowers | Agentic skills 框架 + 开发方法论，强烈推荐 |
| **AutoResearchClaw** | - | https://github.com/aiming-lab/AutoResearchClaw | 自动化研究工具 |
| **ralph** | - | https://github.com/snarktank/ralph | 轻量级 Agent 框架 |
| **delta** | - | https://github.com/dandavison/delta | Git diff 优化工具 |
| **fzf** | - | https://github.com/junegunn/fzf | 模糊搜索工具 |
| **jq** | - | https://stedolan.github.io/jq | JSON 处理工具 |

### 2.2 Hermes 生态项目

| 项目 | 链接 | 说明 |
|------|------|------|
| [hermes-agent (官方)](https://github.com/NousResearch/hermes-agent) | https://github.com/NousResearch/hermes-agent | 主仓库 |
| [hermes-agent/docs](https://github.com/NousResearch/hermes-agent/tree/main/website/docs) | https://github.com/NousResearch/hermes-agent/tree/main/website/docs | 文档源码 |

---

## 三、Skills 技能精选

通过 `hermes skills browse` 可浏览全部技能，以下是精选推荐：

### 3.1 编码相关

| 技能 | 命令 | 说明 |
|------|------|------|
| `claude-code` | `hermes skills install claude-code` | Claude Code CLI 集成 |
| `codex` | `hermes skills install codex` | OpenAI Codex 集成 |
| `opencode` | `hermes skills install opencode` | OpenCode 集成 |

### 3.2 GitHub 工作流

| 技能 | 命令 | 说明 |
|------|------|------|
| `github-pr-workflow` | `hermes skills install github-pr-workflow` | PR 生命周期管理 |
| `github-code-review` | `hermes skills install github-code-review` | PR 代码审查 |
| `github-issues` | `hermes skills install github-issues` | Issue 管理 |
| `github-repo-management` | `hermes skills install github-repo-management` | 仓库管理 |

### 3.3 数据科学/ML

| 技能 | 命令 | 说明 |
|------|------|------|
| `dspy` | `hermes skills install dspy` | 声明式 LM 程序 |
| `llama-cpp` | `hermes skills install llama-cpp` | 本地 GGUF 推理 |
| `serving-llms-vllm` | `hermes skills install serving-llms-vllm` | vLLM 高吞吐服务 |
| `huggingface-hub` | `hermes skills install huggingface-hub` | HuggingFace 模型管理 |

### 3.4 媒体处理

| 技能 | 命令 | 说明 |
|------|------|------|
| `spotify` | `hermes skills install spotify` | Spotify 播放控制 |
| `youtube-content` | `hermes skills install youtube-content` | YouTube 内容处理 |
| `comfyui` | `hermes skills install comfyui` | 图像/视频生成 |

### 3.5 效率工具

| 技能 | 命令 | 说明 |
|------|------|------|
| `notion` | `hermes skills install notion` | Notion API 集成 |
| `linear` | `hermes skills install linear` | Linear 项目管理 |
| `obsidian` | `hermes skills install obsidian` | Obsidian 笔记 |
| `airtable` | `hermes skills install airtable` | Airtable API |

---

## 四、学习路径推荐

### 4.1 入门路径（1-2天）

```
Day 1: 安装和基础使用
  1. 安装 Hermes
     curl -fsSL https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.sh | bash
  2. 运行 hermes setup（交互式配置向导）
  3. 尝试基本对话：hermes chat -q "你好"
  4. 学习基础命令：/help, /model, /tools

Day 2: 核心功能
  1. 配置 Provider（推荐 OpenRouter）
  2. 启用额外工具集：hermes tools enable web
  3. 安装技能：hermes skills install github-pr-workflow
  4. 体验 Cron：hermes cron create "30m"
```

### 4.2 进阶路径（1周）

```
Week 1: 深度使用
  1. 掌握 delegate_task 并行任务委托
  2. 配置 Gateway：hermes gateway setup
  3. 掌握 Profile 多实例：hermes profile create dev
  4. 掌握会话管理：hermes --continue, hermes sessions list
  5. 尝试 Skill 开发：阅读 hermes-agent/docs/developer-guide/
```

### 4.3 高手路径（长期）

```
长期:
  1. 阅读源码贡献代码：~/.hermes/hermes-agent/
  2. 开发自定义工具和插件
  3. 搭建 Agent 团队工作流（参考 Superpowers）
  4. 研究自主 Agent 架构
```

---

## 五、Provider 选择指南

### 5.1 推荐 Provider

| 场景 | 推荐 Provider | 理由 |
|------|---------------|------|
| 通用对话 | OpenRouter | 模型多，灵活 |
| 代码任务 | Claude (Anthropic) | 编码能力强 |
| 中国用户 | MiniMax CN / 硅基流动 | 国内访问快 |
| 成本敏感 | DeepSeek / Qwen | 性价比高 |
| 本地部署 | ollama / llama.cpp | 隐私优先 |

### 5.2 免费额度

| Provider | 免费额度 | 链接 |
|----------|----------|------|
| OpenRouter | 每月免费配额 | https://openrouter.ai |
| Groq | 限速免费 | https://groq.com |
| DeepSeek | 有免费额度 | https://platform.deepseek.com |
| 硅基流动 | 新用户有免费额度 | https:// account.siliconflow.cn |

---

## 六、工具链推荐

### 6.1 与 Hermes 配合的工具

| 工具 | 安装 | 用途 |
|------|------|------|
| tmux | `apt install tmux` | 多 Agent 管理 |
| delta | https://github.com/dandavison/delta | Git diff 优化 |
| fzf | https://github.com/junegunn/fzf | 模糊搜索 |
| jq | https://stedolan.github.io/jq | JSON 处理 |
| ripgrep | https://github.com/BurntSushi/ripgrep | 代码搜索 |

### 6.2 模型管理

| 工具 | 链接 | 用途 |
|------|------|------|
| ollama | https://ollama.com | 本地模型 |
| vLLM | https://docs.vllm.ai | 高性能推理 |
| llama.cpp | https://github.com/ggerganov/llama.cpp | 量化推理 |

---

## 七、资源质量评估标准

本项目使用的筛选标准：

| 标准 | 说明 |
|------|------|
| **官方优先** | 官方文档 > 社区文章 > 博客 |
| **活跃度** | GitHub stars > 1000，2年内有更新 |
| **实用性** | 有可运行的代码示例 |
| **可验证性** | 能实际测试验证 |
| **完整性** | 有使用文档和示例 |

---

## 八、避坑指南

### 8.1 不推荐的做法

- ❌ 盲目信任博客教程（可能过时）
- ❌ 使用非官方 API Key 来源
- ❌ 在生产环境使用 `approvals.mode: off`
- ❌ 忽略日志和错误信息

### 8.2 推荐的做法

- ✅ 优先阅读官方文档
- ✅ 使用 `hermes doctor` 检查问题
- ✅ 先在测试环境验证
- ✅ 关注 GitHub Releases 了解更新
- ✅ 使用 `hermes config check` 验证配置