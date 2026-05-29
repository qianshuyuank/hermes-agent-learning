# Ralph Hermes Skill — Design Doc

## Goal

将 [snarktank/ralph](https://github.com/snarktank/ralph) 的 PRD 驱动自主循环工作流封装为 Hermes 可调用技能 `ralph`，使用子 Agent 作为执行后端。

---

## Ralph 架构回顾

| Ralph 组件 | 作用 |
|------------|------|
| `prd.json` | 任务清单（stories 列表，含 `passes` 状态） |
| `skills/prd/` | 生成 Markdown PRD |
| `skills/ralph/` | 将 PRD 转换为 prd.json 格式 |
| `ralph.sh` | 循环驱动脚本，每次 spawn 新 AI 实例 |
| `CLAUDE.md` / `prompt.md` | 每次迭代的 AI 指令模板 |
| `progress.txt` | 记录已完成 story 和学到的代码模式 |

核心循环：`ralph.sh` 读取 `prd.json`，每次迭代 spawn 一个新的 Claude Code/Amp 实例执行**一个** story，完成后更新 `passes` 状态，重复直到所有 story 完成。

---

## Hermes 等价映射

| Ralph | Hermes |
|--------|--------|
| `ralph.sh` 循环 | Orchestrator subagent（单次调用内循环迭代） |
| Claude Code / Amp | `delegate_task` leaf subagent |
| `prd.json` + `progress.txt` | `./ralph/prd.json` + `./ralph/progress.md` |
| `CLAUDE.md` 指令模板 | Subagent `goal` 参数 + 上下文注入 |
| 分支管理 | 暂不自动化，用户手动切换 |

---

## 目录结构

```
./ralph/                    ← 用户项目下
├── prd.json                # 任务清单（用户创建或从 PRD 转换生成）
├── progress.md             # 进度日志（人类可读）
└── archive/                # 旧 run 的存档（branch 切换时自动归档）
```

启动后检测 `prd.json` 是否存在。不存在则报错退出。

---

## 技能结构

`ralph` 技能包含三个子组件：

### 1. `ralph:prd` — 生成 PRD

将用户的功能描述转化为结构化 PRD（Markdown），保存到 `./ralph/tasks/prd-[feature-name].md`。

**触发词：** `create a prd`、`write prd for`、`plan this feature`

**工作流程：**
1. 询问 3-5 个澄清问题（多选格式）
2. 生成 PRD
3. 保存到 `./ralph/tasks/prd-[feature-name].md`
4. 询问用户是否需要转换为 `prd.json`

### 2. `ralph:convert` — PRD → prd.json

将 Markdown PRD 转换为 `prd.json` 格式。

**触发词：** `convert this prd`、`turn this into ralph format`、`create prd.json from this`

**规则：**
- 每个 story 可在单次迭代中完成（上下文窗口限制）
- 按依赖排序（schema → backend → UI）
- 每个 story 必须有 "Typecheck passes" 验收标准
- UI story 必须有 "Verify in browser using dev-browser skill"
- 所有 `passes: false`，`notes: ""`

### 3. `ralph:run` — 执行循环（核心功能）

**触发词：** `run ralph`、`start ralph loop`、`execute ralph`

**工作流程：**

```
1. 读取 ./ralph/prd.json
2. 初始化 progress.md（如不存在）
3. 主循环（orchestrator subagent）：
   a. 找到最低 priority 且 passes=false 的 story
   b. Spawn leaf subagent 执行该 story
   c. 子 agent 返回执行结果
   d. 更新 prd.json 中该 story 的 passes=true
   e. 追加 progress.md
   f. 如所有 story 完成 → 输出 COMPLETE 信号
   g. 否则继续下一轮循环
4. 循环直到所有 passes=true 或达到最大迭代次数
```

---

## 关键设计决策

### 决策 1：循环驱动方式

选用 orchestrator subagent 单次调用内循环，而非 cronjob。

原因：Ralph 的核心体验是「一次启动，持续执行直到完成」。Cronjob 适合定期检查，但不适合这种主动的长时间运行任务。

### 决策 2：状态文件格式

- `prd.json` — 保留原版格式，直接读写
- `progress.md` — 使用 Markdown（人类可读性优先）

### 决策 3：Branch 管理

暂不实现自动化分支切换。用户需要手动 `git checkout -b ralph/xxx` 或确保已在正确分支。子 agent 被调用时会提示检查分支。

### 决策 4：归档行为

当 `prd.json` 的 `branchName` 与上一次不同时，自动将旧的 `prd.json` 和 `progress.md` 归档到 `./ralph/archive/YYYY-MM-DD-branch-name/`。

### 决策 5：Story 执行策略（自动判断）

小改动（直接执行）：
- 修改 ≤ 2 个文件
- 不涉及数据库迁移
- 不涉及多目录协调
- 不需要外部服务依赖变更

大改动（先 writing-plans）：
- 修改 > 5 个文件
- 涉及数据库迁移
- 跨多个目录/模块
- 需要协调多个服务

中间地带（3-5 个文件）：根据复杂度判断，难以决策时走 writing-plans。

### 决策 6：最大迭代次数

`max_iterations: 20`（默认），用户可通过参数覆盖。

---

## 数据流

```
用户调用 ralph:run
    ↓
读取 ./ralph/prd.json
    ↓
初始化 progress.md（首次）
    ↓
┌── 主循环（orchestrator） ──┐
│  选择下一个 story           │
│  spawn leaf subagent       │
│  更新 prd.json (passes)     │
│  追加 progress.md           │
│  检查完成状态               │
└────────────────────────────┘
    ↓
所有 story 完成 → 输出摘要
```

---

## 错误处理

| 场景 | 处理 |
|------|------|
| `./ralph/prd.json` 不存在 | 报错退出，提示先运行 `ralph:prd` 或 `ralph:convert` |
| 子 agent 执行失败 | 标记 story 为未完成，在 progress.md 中记录错误，继续下一轮 |
| typecheck / lint 失败 | 子 agent 应在返回前修复，不应带失败状态返回 |
| 最大迭代次数耗尽 | 输出当前状态摘要，提示用户检查 progress.md |
| branch 与 prd.json 不符 | 提示用户切换到正确分支，不自动执行 |

---

## 完成信号

当所有 story 的 `passes: true` 时，输出：

```
✓ Ralph completed all tasks!
  Completed N stories in M iterations
  
  Summary:
  - [US-001] story title
  - [US-002] story title
  ...
```

---

## 文件清单

| 文件 | 位置 | 说明 |
|------|------|------|
| `SKILL.md` | `skills/ralph/` | 主技能定义，含 prd/convert/run 三个入口 |
| `templates/prd-template.md` | skill 内 | PRD 生成模板 |
| `scripts/validate-prd.py` | skill 内 | prd.json 格式校验脚本 |

---

## 验收标准

1. `ralph:prd` 可生成结构化 PRD 并保存到 `./ralph/tasks/`
2. `ralph:convert` 可将 Markdown PRD 转换为符合规范的 `prd.json`
3. `ralph:run` 可驱动子 agent 循环执行直到所有 story 完成
4. progress.md 正确记录每个 story 的执行结果和学到的 patterns
5. 分支切换时自动归档旧 run
6. 完成时输出清晰的摘要报告