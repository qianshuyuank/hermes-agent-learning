# Ralph Hermes Skill — Implementation Plan

> **For Hermes:** Use subagent-driven-development skill to implement this plan task-by-task.

**Goal:** 将 Ralph PRD 驱动循环工作流封装为 Hermes 可调用技能 `ralph`，含 prd/convert/run 三个入口。

**Architecture:** 三入口结构（prd 生成、convert 转换、run 执行循环）。run 由 orchestrator subagent 驱动 leaf worker 执行单个 story，状态存于 `./ralph/prd.json` + `./ralph/progress.md`。

**Tech Stack:** Hermes skill system, delegate_task, orchestrator/leaf subagent pattern.

---

## Task 1: Create Ralph Skill Directory

**Objective:** 在 `skills/ralph/` 下建立技能基础目录结构。

**Files:**
- Create: `skills/ralph/SKILL.md`
- Create: `skills/ralph/templates/prd-template.md`
- Create: `skills/ralph/scripts/validate-prd.py`
- Create: `skills/ralph/templates/progress-template.md`

**Step 1: Create directory structure**

```bash
mkdir -p ~/.hermes/profiles/secretary/skills/ralph/templates
mkdir -p ~/.hermes/profiles/secretary/skills/ralph/scripts
```

**Step 2: Write progress template**

Create `skills/ralph/templates/progress-template.md`:

```markdown
# Ralph Progress Log

Started: {{date}}
Project: {{project_name}}
Branch: {{branch_name}}

---

## Codebase Patterns
<!-- Learned patterns consolidated across iterations go here -->
- (none yet)

---

## Iteration Log
<!-- Each completed story appends here -->
```

---

## Task 2: Write Main SKILL.md

**Objective:** 编写 `skills/ralph/SKILL.md`，包含三个入口的完整触发词和工作流描述。

**Files:**
- Create: `skills/ralph/SKILL.md`

**Step 1: Write skill definition**

创建 `skills/ralph/SKILL.md`（完整内容见下方「技能内容」，此处确认结构）。

**Step 2: Verify file created**

Run: `ls -la skills/ralph/`
Expected: SKILL.md, templates/, scripts/ 目录存在

**Step 3: Commit**

```bash
git add skills/ralph/
git commit -m "feat: add ralph skill skeleton with directory structure"
```

---

## Task 3: Write PRD Generator (`ralph:prd`)

**Objective:** 实现 `ralph:prd` 子入口，将用户的功能描述转化为结构化 PRD。

**Files:**
- Modify: `skills/ralph/SKILL.md`（在 PRD Generator section 补充完整内容）

**Step 1: Write PRD template**

Create `skills/ralph/templates/prd-template.md`:

```markdown
# PRD: {{feature_name}}

## Introduction

{{brief_description_of_feature_and_problem_it_solves}}

## Goals

- {{specific Measurable objective 1}}
- {{specific Measurable objective 2}}

## User Stories

### US-001: {{story_title}}
**Description:** As a [user], I want [feature] so that [benefit].

**Acceptance Criteria:**
- [ ] {{verifiable criterion 1}}
- [ ] {{verifiable criterion 2}}
- [ ] Typecheck passes
<!-- For UI stories add: -->
<!-- - [ ] Verify in browser using dev-browser skill -->

### US-002: ...

## Functional Requirements

- FR-1: {{specific functionality}}
- FR-2: {{specific functionality}}

## Non-Goals

- {{what this feature will NOT include}}

## Technical Considerations

- {{known constraints or integration points}}

## Open Questions

- {{remaining questions needing clarification}}
```

**Step 2: Write prd sub-component in SKILL.md**

在 `skills/ralph/SKILL.md` 中 PRD Generator 部分补充：
- 触发词列表
- 澄清问题格式（多选，3-5 个）
- PRD 保存路径规则（`./ralph/tasks/prd-[feature-name].md`）
- 输出格式规范

**Step 3: Commit**

```bash
git add skills/ralph/
git commit -m "feat(ralph): add prd generator sub-entry"
```

---

## Task 4: Write PRD→prd.json Converter (`ralph:convert`)

**Objective:** 实现 `ralph:convert` 子入口，将 Markdown PRD 转换为 `prd.json` 格式。

**Files:**
- Modify: `skills/ralph/SKILL.md`

**Step 1: Write conversion rules**

在 `skills/ralph/SKILL.md` 中 PRD Converter 部分补充：
- 触发词列表
- 转换规则（每个 story 大小限制、依赖排序、必含验收标准）
- 输出格式（`prd.json` 结构）
- 归档逻辑（branch 切换时）

**Step 2: Write validate-prd.py**

Create `skills/ralph/scripts/validate-prd.py`:

```python
#!/usr/bin/env python3
"""Validate prd.json format for Ralph Hermes skill."""

import json
import sys
from pathlib import Path

def validate_prd(prd_path: str) -> bool:
    with open(prd_path) as f:
        data = json.load(f)

    required = ["project", "branchName", "description", "userStories"]
    for field in required:
        if field not in data:
            print(f"ERROR: Missing required field: {field}")
            return False

    if not isinstance(data["userStories"], list):
        print("ERROR: userStories must be a list")
        return False

    for i, story in enumerate(data["userStories"]):
        for field in ["id", "title", "description", "acceptanceCriteria", "priority", "passes", "notes"]:
            if field not in story:
                print(f"ERROR: Story {i} missing field: {field}")
                return False
        if "Typecheck passes" not in story["acceptanceCriteria"]:
            print(f"WARNING: Story {story['id']} missing 'Typecheck passes' in acceptanceCriteria")
        if story["passes"] not in [True, False]:
            print(f"ERROR: Story {story['id']} passes must be boolean")
            return False

    print(f"✓ prd.json valid: {len(data['userStories'])} stories")
    return True

if __name__ == "__main__":
    result = validate_prd(sys.argv[1] if len(sys.argv) > 1 else "./ralph/prd.json")
    sys.exit(0 if result else 1)
```

**Step 3: Make executable**

```bash
chmod +x skills/ralph/scripts/validate-prd.py
```

**Step 4: Commit**

```bash
git add skills/ralph/
git commit -m "feat(ralph): add convert sub-entry and validator"
```

---

## Task 5: Write Ralph Executor (`ralph:run`)

**Objective:** 实现 `ralph:run` 子入口，orchestrator 驱动循环执行 story。

**Files:**
- Modify: `skills/ralph/SKILL.md`（补充 run 主循环逻辑）

**Step 1: Define orchestrator prompt template**

在 `skills/ralph/SKILL.md` 的 run 部分定义主 orchestrator 的行为：

```
主循环逻辑：
1. 读取 ./ralph/prd.json（如不存在则报错）
2. 初始化 ./ralph/progress.md（如不存在则用模板创建）
3. 检查归档条件（branchName 变更则归档旧 run）
4. 主循环（最多 20 次迭代）：
   a. 找 priority 最低且 passes=false 的 story
   b. 如无 story 完成 → 输出 COMPLETE
   c. 构建 leaf subagent goal：story 内容 + acceptance criteria + workdir
   d. spawn leaf subagent（toolsets: terminal, file, browser）
   e. 等待子 agent 返回
   f. 如成功：更新 prd.json 该 story passes=true
   g. 追加 progress.md（执行摘要 + patterns）
   h. 继续下一轮
5. 达到最大迭代 → 输出状态摘要
```

**Step 2: Define leaf subagent prompt template**

在 SKILL.md 中补充 leaf worker 的指令模板：

```
Leaf Worker 指令：
- 读取 story 的 acceptance criteria
- 分析改动范围，判断直接执行还是先 writing-plans
- 直接执行：文件编辑、终端命令、typecheck、UI 验证（如需要 browser）
- 完成后返回：story_id、files_changed、patterns_learned、status
- 如执行失败：返回 error 信息，status=failed
```

**Step 3: Define COMPLETE 输出格式**

```
✓ Ralph completed all tasks!
  Completed N stories in M iterations

  Summary:
  - [US-001] story title — passed
  - [US-002] story title — passed
```

**Step 4: Commit**

```bash
git add skills/ralph/
git commit -m "feat(ralph): add run executor with orchestrator loop"
```

---

## Task 6: End-to-End Test

**Objective:** 验证 ralph skill 可正常安装和调用。

**Files:**
- Create: `test_project/ralph/prd.json`（测试数据）
- Modify: `test_project/`（临时测试项目）

**Step 1: 安装 skill**

Hermes skill 通过 `skill_manage` 管理（此处为手动测试步骤，用户实际使用时 skill 已存在）。

**Step 2: Create test project**

```bash
mkdir -p test_project/ralph
cp prd.json.example test_project/ralph/prd.json
```

**Step 3: Test prd generation**

触发词：`create a prd for task priority system`
验证：./ralph/tasks/prd-task-priority-system.md 存在且格式正确

**Step 4: Test convert**

触发词：`convert this prd`
验证：./ralph/prd.json 存在且通过 validate-prd.py

**Step 5: Test run（dry-run）**

触发词：`run ralph --dry-run`
验证：主 orchestrator 正确读取 prd.json 并选择第一个 story（不实际 spawn）

**Step 6: Commit**

```bash
git add test_project/
git commit -m "test: add ralph skill e2e test project"
```

---

## Verification Checklist

After each task:
- [ ] `hermes skills list` shows `ralph` skill installed
- [ ] Skill loads without error
- [ ] Each sub-entry triggers correctly
- [ ] File paths created in expected locations
- [ ] validate-prd.py passes on generated prd.json

---

## Execution Approach

Plan complete. Ready to execute using subagent-driven-development — dispatch a fresh subagent per task with two-stage review (spec compliance then code quality). Shall I proceed?