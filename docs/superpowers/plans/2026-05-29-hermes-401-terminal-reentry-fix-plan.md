# Hermes 401 Terminal Reentry Fix Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 优先修复“重新打开 Hermes 终端后再次出现 401”的复发根因，降低环境变量在新终端会话中重新污染鉴权链路的概率。

**Architecture:** 先将仓库内示例配置中的 `terminal.auto_source_bashrc` 从 `true` 改为 `false`，明确禁止 Hermes 新终端自动 source `~/.bashrc`。随后补充排查文档，说明该项与 `OPENAI_API_KEY` 等环境变量污染的关系，并通过代理链路、Hermes 主链路和终端重开后的复测来验证复发是否停止。

**Tech Stack:** YAML、Markdown、Hermes CLI、curl、Bash。

---

### Task 1: 固化终端重入配置

**Files:**
- Modify: `config/hermes.config.yaml`

- [ ] **Step 1: 确认当前示例配置中的终端行为开关**

Run:

```bash
grep -n "auto_source_bashrc" /home/bitq/github/hermes-agent-learning/config/hermes.config.yaml
```

Expected: 输出包含 `auto_source_bashrc: true`，确认当前仓库示例配置仍允许 Hermes 在新终端自动 source `~/.bashrc`。

- [ ] **Step 2: 写一个失败前提说明到工作记录**

将以下结论写入本次实现说明或提交说明草稿中：

```text
当前 401 的复发更像是终端重入问题，而不是主配置缺失问题。
因为 model 与 auxiliary 已显式固定为 custom + localhost:8317 + local-proxy-key，
但 terminal.auto_source_bashrc 仍为 true，新终端会重新加载 ~/.bashrc，
从而让某些 fallback 链路再次接触 OPENAI_API_KEY 等环境变量。
```

Expected: 说明聚焦“为什么要改这个开关”，避免把本次修复误写成单纯文档同步。

- [ ] **Step 3: 将示例配置改为禁止自动 source bashrc**

把 `config/hermes.config.yaml` 中这一段：

```yaml
terminal:
  backend: local
  modal_mode: auto
  cwd: .
  timeout: 180
  env_passthrough: []
  shell_init_files: []
  auto_source_bashrc: true
```

改成：

```yaml
terminal:
  backend: local
  modal_mode: auto
  cwd: .
  timeout: 180
  env_passthrough: []
  shell_init_files: []
  auto_source_bashrc: false
```

Expected: 新终端不再自动继承 `~/.bashrc` 导出的环境变量，降低 fallback 污染风险。

- [ ] **Step 4: 回读配置，确认改动精确落位**

Run:

```bash
sed -n '66,76p' /home/bitq/github/hermes-agent-learning/config/hermes.config.yaml
```

Expected: 输出中出现 `auto_source_bashrc: false`，且相邻配置未被意外破坏。

- [ ] **Step 5: Commit**

```bash
git add /home/bitq/github/hermes-agent-learning/config/hermes.config.yaml
git commit -m "fix: disable bashrc auto-source in hermes config example"
```

Expected: 只提交配置示例中的终端行为修复。

---

### Task 2: 更新排查文档，明确复发根因与建议修复

**Files:**
- Modify: `docs/troubleshooting-hermes-cli-proxy-401.md`

- [ ] **Step 1: 在根因总结中补充“终端重入环境污染”小节**

在 `## 1. 根本原因总结` 下新增一个小节，插入以下内容：

```md
### 1.4 新终端自动 source `~/.bashrc` 导致复发
如果 Hermes 终端配置启用了自动 source `~/.bashrc`，那么每次重新打开新的 Hermes 终端时，shell 环境变量都会再次被注入当前会话。
在已经存在 `OPENAI_API_KEY`、`MINIMAX_CN_API_KEY` 等环境变量的机器上，这会放大 fallback 链路被污染的概率，使问题表现为“刚修好，重开终端后又出现 401”。

**修复方法**：在 Hermes 终端配置中关闭自动 source shell 初始化文件，例如：
```yaml
terminal:
  auto_source_bashrc: false
```
```

Expected: 文档从“单次修复”升级到“解释为什么会复发”。

- [ ] **Step 2: 在 checklist 中追加终端配置检查项**

在 “### 第三步：清理 Hermes 辅助模型配置” 后追加一个新步骤，内容写成：

```md
### 第四步：检查终端是否会重新注入环境变量
- [ ] 检查 Hermes 终端配置是否启用了 `auto_source_bashrc: true`。如果开启，每次新终端都可能重新加载 `~/.bashrc` 中的 `OPENAI_API_KEY` 等变量，导致 401 在重开终端后复发。
- [ ] 建议改为 `auto_source_bashrc: false`，除非你明确依赖 shell 初始化逻辑。
```

并把原文后续步骤标题顺延。

Expected: checklist 可以覆盖“为什么重开终端又坏了”这一类现象。

- [ ] **Step 3: 在判定说明后追加复测建议**

在 `**判定说明：**` 所在段落后增加以下内容：

```md
- 如果你已经修复主模型、辅助模型和代理配置，但只要重新打开 Hermes 终端就再次出现 `401`，应优先检查是否是新终端重新 source `~/.bashrc` 导致环境变量重新污染。
- 建议在修改终端配置后，关闭当前 Hermes 会话，重新打开一个全新的 Hermes 终端，再重复执行 `hermes -z "test"` 与必要的 Skill 验证。
```

Expected: 文档把“复发”与“首次修复失败”区分开。

- [ ] **Step 4: 回读更新后的关键文档段落**

Run:

```bash
sed -n '1,120p' /home/bitq/github/hermes-agent-learning/docs/troubleshooting-hermes-cli-proxy-401.md
```

Expected: 新增小节、追加 checklist 和复测建议都能看到，文档结构仍顺畅。

- [ ] **Step 5: Commit**

```bash
git add /home/bitq/github/hermes-agent-learning/docs/troubleshooting-hermes-cli-proxy-401.md
git commit -m "docs: document terminal reentry as a 401 recurrence cause"
```

Expected: 文档提交只包含复发根因与复测说明。

---

### Task 3: 验证“关闭自动 source bashrc”是否抑制复发

**Files:**
- Verify: `~/.hermes/config.yaml`
- Verify: `~/.cli-proxy-api/config.yaml`
- Verify: `~/.cli-proxy-api/proxy.log`

- [ ] **Step 1: 备份用户实际运行态配置**

Run:

```bash
cp ~/.hermes/config.yaml ~/.hermes/config.yaml.bak.$(date +%Y%m%d%H%M%S)
```

Expected: 生成一个时间戳备份，避免直接修改运行态配置后无法回退。

- [ ] **Step 2: 将运行态配置中的终端开关也改为 false**

把 `~/.hermes/config.yaml` 中这一段：

```yaml
terminal:
  backend: local
  modal_mode: auto
  cwd: .
  timeout: 180
  env_passthrough: []
  shell_init_files: []
  auto_source_bashrc: true
```

改成：

```yaml
terminal:
  backend: local
  modal_mode: auto
  cwd: .
  timeout: 180
  env_passthrough: []
  shell_init_files: []
  auto_source_bashrc: false
```

Expected: 用户实际运行的 Hermes 新终端也不再自动 source `~/.bashrc`。

- [ ] **Step 3: 回读运行态配置确认修改成功**

Run:

```bash
grep -n "auto_source_bashrc" ~/.hermes/config.yaml
```

Expected: 输出 `auto_source_bashrc: false`。

- [ ] **Step 4: 重启代理和 Hermes Gateway**

Run:

```bash
pkill -f "cli-proxy-api" || true
/home/bitq/cliproxyapi/cli-proxy-api -config ~/.cli-proxy-api/config.yaml > ~/.cli-proxy-api/proxy.log 2>&1 &
sleep 2
hermes gateway restart
```

Expected: 代理和 gateway 都用当前配置重启成功，没有配置解析错误。

- [ ] **Step 5: 验证代理本身仍可用**

Run:

```bash
curl -s -X POST http://localhost:8317/v1/chat/completions \
  -H "Authorization: Bearer local-proxy-key" \
  -H "Content-Type: application/json" \
  -d '{"model":"gemini-3.1-pro-preview","messages":[{"role":"user","content":"test"}],"max_tokens":5}'
```

Expected: 返回 JSON，而不是 `401 Invalid API key`。

- [ ] **Step 6: 验证 Hermes 主链路**

Run:

```bash
hermes -z "test"
```

Expected: 返回正常响应，不出现 `401 Invalid API key`。

- [ ] **Step 7: 关闭当前会话后重新打开 Hermes 终端，再做复测**

Run:

```bash
hermes -z "test"
```

Expected: 在“全新打开的 Hermes 终端”中仍然成功，若这里复发 `401`，则说明问题不只来自 `auto_source_bashrc`。

- [ ] **Step 8: 如需辅助链路复测，执行最小 Skill 验证**

Run:

```bash
hermes -z "Use Skill: brainstorming"
tail -n 50 ~/.cli-proxy-api/proxy.log
```

Expected: 不再出现 `401`。如果变成 `500` 或 `TCP timeout`，说明鉴权问题已基本剥离，后续应转入网络排查。

- [ ] **Step 9: 记录结论，不提交 home 目录配置**

将结果按以下模板记录到交付说明中：

```text
1. auto_source_bashrc 已从 true 调整为 false
2. curl 代理验证是否成功
3. hermes -z "test" 首次验证是否成功
4. 重开 Hermes 终端后的复测是否仍成功
5. Skill 链路是否还出现 401，还是已切换为 500/timeout
```

Expected: 结论能明确回答“是否还需要额外脚本兜底”。

---

### Task 4: 根据验证结果决定是否保留脚本方案

**Files:**
- Reference: `docs/superpowers/specs/2026-05-29-hermes-401-repair-script-design.md`

- [ ] **Step 1: 按验证结果做分流决策**

使用以下标准：

```text
如果关闭 auto_source_bashrc 后，普通链路和重开终端后的复测都稳定通过，
则脚本不是必需项，可保留为备用设计，不立刻实现。

如果关闭 auto_source_bashrc 后仍偶发复发 401，
则说明还存在其他重置入口或人工误操作风险，应回到脚本方案。
```

Expected: 决策依据来自验证结果，而不是主观判断。

- [ ] **Step 2: 在最终说明中写出明确建议**

根据分流结果，交付说明必须二选一：

```text
建议 A：根因修复已足够，当前不实现脚本。
建议 B：根因修复不足，下一步实现一键修复脚本。
```

Expected: 用户能直接决定是否进入下一轮实现。
