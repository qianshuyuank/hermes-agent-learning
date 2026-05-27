# Hermes Agent 记忆系统配置教程

## 一、两种记忆系统概述

Hermes 有两套并行的记忆机制：

| | 内置记忆 | 外部 Provider |
|---|---|---|
| 存储位置 | `~/.hermes/memories/` | 各 Provider 自定义 |
| 数据格式 | MEMORY.md / USER.md | 多为 API 云端 / 本地数据库 |
| 容量 | 有限（2,200 + 1,375 字符） | 可扩展至无限 |
| 依赖 | 无 | 部分需要 API Key |
| 工具 | 内置 `memory` 工具 | 各 Provider 自带工具 |
| 开启方式 | 默认始终启用 | 需手动配置 |

**两条核心规则：**
- 内置记忆（MEMORY.md / USER.md）**永远激活**，不可关闭
- 外部 Provider **同一时刻只能有一个**处于活跃状态

---

## 二、8 个 Provider 特性对比

| Provider | API Key | 本地模式 | 核心能力 | 适合场景 |
|---|---|---|---|---|
| **Honcho** | 需要（云）/ 不需要（自托管） | ✓ | 双层上下文注入 + 方言辩证推理 | 多 Agent 系统、用户对齐 |
| **Hindsight** | 需要（云）/ 不需要（本地） | ✓ | 知识图谱 + 实体消歧 + `reflect` 工具 | 知识图谱检索、跨记忆综合 |
| **Holographic** | ❌ | ✓ | SQLite + FTS5 + HRR 代数查询 + 信任评分 | 本地优先、高级检索、无依赖 |
| **Mem0** | 需要 | ❌ | 服务端 LLM 自动抽取 + 向量搜索 + 去重 | 免管理记忆、自动化抽取 |
| **OpenViking** | 需要（云）/ 不需要（自托管） | ✓ | 文件系统式知识树 + 分层检索 (L0/L1/L2) + 6 类自动抽取 | 自托管知识管理、结构化浏览 |
| **RetainDB** | 需要 | ❌ | 混合搜索（向量 + BM25 + Rerank）+ 7 种记忆类型 + 增量压缩 | 已使用 RetainDB 基础设施的团队 |
| **ByteRover** | 需要（云）/ 不需要（本地） | ✓ | 分层知识树 + `brv` CLI 工具 + 自动压缩前抽取 | 开发者、可移植本地记忆、CLI 偏好 |
| **Supermemory** | 需要 | ❌ | 用户画像 + 向量搜索 + 对话图 + 自动上下文隔离 | 语义检索 + 用户画像 + 图结构 |

---

## 三、安装步骤

### 通用流程（3 步）

```bash
# 第 1 步：进入交互式配置向导，选一个 Provider
hermes memory setup

# 第 2 步：检查状态
hermes memory status

# 第 3 步：新开 session 生效（不要 mid-session 改配置）
hermes                    # 重启会话
```

### 各 Provider 额外依赖

```bash
# Honcho
pip install honcho-ai

# Mem0
pip install mem0ai

# OpenViking
pip install openviking
# 还需要自托管服务器：openviking-server（启动在 localhost:1933）

# Hindsight
pip install hindsight-client          # 云模式
pip install hindsight-all             # 本地模式（含嵌入向量）

# Holographic
# 无需额外依赖，SQLite 内置。NumPy 可选（HRR 代数功能）

# ByteRover
npm install -g byterover-cli
# 或：curl -fsSL https://byterover.dev/install.sh | sh

# Supermemory
pip install supermemory

# RetainDB
# 需要 RetainDB 账户，API Key 方式接入
```

### 手动配置（不用向导）

```bash
# 在 config.yaml 中指定 provider
hermes config set memory.provider <name>
# 例如：hermes config set memory.provider holographic

# API Key 写入 .env
echo "HONCHO_API_KEY=your-key" >> ~/.hermes/.env
echo "MEM0_API_KEY=your-key" >> ~/.hermes/.env
echo "HINDSIGHT_API_KEY=your-key" >> ~/.hermes/.env
# ...以此类推
```

---

## 四、工作原理

### 内置记忆（始终活跃）

```
~/.hermes/memories/
├── MEMORY.md    # Agent 个人笔记（2,200 字符上限）
└── USER.md      # 用户画像（1,375 字符上限）
```

启动时注入 system prompt：

```
══════════════════════════════════════════════
MEMORY (your personal notes) [14% — 314/2,200 chars]
══════════════════════════════════════════════
[记忆条目内容，条目间用 § 分隔]
```

Agent 通过 `memory` 工具自己管理（add / replace / remove）。

### 外部 Provider 工作流程

```
每轮对话：
  1. build_system_prompt()  → Provider 的 system_prompt_block()
  2. prefetch_all(query)    → 后台召回相关记忆（非阻塞）
  3. LLM 生成回复
  4. sync_all(user, asst)  → 将对话轮次写入 Provider（异步）
  5. queue_prefetch_all()  → 预热下一轮召回

会话结束：
  on_session_end(messages) → 提取总结/最终持久化
```

Provider 带来的额外工具通过 `get_tool_schemas()` 注册进 Agent。

---

## 五、如何检查是否生效

```bash
# 查看当前激活状态（最直接）
hermes memory status
```

输出示例：

```
Memory status
────────────────────────────────────────
  Built-in:  always active
  Provider:  (none — built-in only)

  Installed plugins:
    • byterover  (requires API key)
    • hindsight  (API key / local)
    • holographic  (local)
    • honcho  (API key / local)
    • mem0  (API key / local)
    • openviking  (API key / local)
    • retaindb  (API key / local)
    • supermemory  (requires API key)
```

**验证方法：**

```bash
# 1. 检查 config.yaml 中的 provider 设置
grep -A2 "^memory:" ~/.hermes/config.yaml

# 2. 检查 Provider 进程 / 连接是否正常（以 OpenViking 为例）
curl http://localhost:1933/health 2>/dev/null && echo "OpenViking OK"

# 3. 检查 API Key 存在（Holographic 不需要 Key）
grep "HONCHO_API_KEY\|MEM0_API_KEY\|HINDSIGHT_API_KEY" ~/.hermes/.env

# 4. 新会话中 Agent 是否能调用 Provider 工具
# 开启某个 provider 后重启 hermes，Agent 工具列表中会出现对应的工具
```

---

## 六、Provider 选择决策树

```
是否需要本地优先（数据不出机器）？
├── ✓ Holographic  — 最简单，零配置，SQLite 内置
├── ✓ OpenViking   — 需要服务器，但自托管免费，文件系统式结构
└ ✗ 继续下一步

是否需要 API Key / 是否有预算？
├── 有 API Key：
│   ├── 需要知识图谱 + 跨记忆综合推理 → Hindsight
│   ├── 多 Agent 用户画像 + 方言推理 → Honcho
│   ├── 向量搜索 + 自动抽取 → Mem0
│   ├── 团队已在用 RetainDB → RetainDB
│   └── 需要知识树 + CLI → ByteRover
└ 无 API Key：
    └── Supermemory 需要 Key，无法使用
```

**简单推荐：**

| 场景 | 推荐 |
|---|---|
| 完全免费、本地、无依赖 | **Holographic** |
| 想自托管知识库，有服务器 | **OpenViking** |
| 需要最少配置工作 | **Holographic** |
| 需要用户画像和深度记忆 | **Honcho** |
| 需要知识图谱 | **Hindsight** |
| 免管理、自动抽取 | **Mem0** |

---

## 七、配置参数参考

### 通用 config.yaml

```yaml
memory:
  provider: holographic   # 切换这里
  memory_enabled: true
  user_profile_enabled: true
```

### 各 Provider 关键配置

**Holographic**（本地 SQLite，无需 Key）：
```yaml
# config.yaml 中的 plugins 段
plugins:
  hermes-memory-store:
    db_path: "$HERMES_HOME/memory_store.db"
    auto_extract: false
    default_trust: 0.5
```

**Honcho**（云/自托管）：
```json
// ~/.hermes/honcho.json 或 $HERMES_HOME/honcho.json
{
  "apiKey": "key-from-app.honcho.dev",
  "hosts": {
    "hermes": {
      "enabled": true,
      "aiPeer": "hermes",
      "peerName": "your-name",
      "workspace": "hermes",
      "dialecticCadence": 2,
      "dialecticDepth": 1,
      "recallMode": "hybrid",
      "writeFrequency": "async"
    }
  }
}
```

**Mem0**：
```json
// $HERMES_HOME/mem0.json
{
  "user_id": "hermes-user",
  "agent_id": "hermes"
}
```

**Supermemory**：
```json
// $HERMES_HOME/supermemory.json
{
  "container_tag": "hermes",
  "auto_recall": true,
  "auto_capture": true,
  "max_recall_results": 10,
  "profile_frequency": 50
}
```

**Hindsight**：
```json
// $HERMES_HOME/hindsight/config.json
{
  "mode": "cloud",
  "bank_id": "hermes",
  "recall_budget": "mid",
  "memory_mode": "hybrid",
  "auto_retain": true,
  "auto_recall": true
}
```

---

## 八、关闭 / 切换 Provider

```bash
# 关闭外部 Provider
hermes memory off

# 或手动清空 config.yaml 中的 provider
hermes config set memory.provider ""

# 切换 Provider
hermes memory setup   # 重新走向导
# 或
hermes config set memory.provider <new-provider>
# 然后新会话生效
```

---

## 九、Provider 工具一览

| Provider    | 工具数 | 核心工具                                                                                              |
| ----------- | --- | ------------------------------------------------------------------------------------------------- |
| Honcho      | 5   | `honcho_profile`, `honcho_search`, `honcho_context`, `honcho_reasoning`, `honcho_conclude`        |
| Hindsight   | 3   | `hindsight_retain`, `hindsight_recall`, `hindsight_reflect`                                       |
| Holographic | 2   | `fact_store` (9 种操作), `fact_feedback`                                                             |
| Mem0        | 3   | `mem0_profile`, `mem0_search`, `mem0_conclude`                                                    |
| OpenViking  | 6   | `viking_search`, `viking_read`, `viking_browse`, `viking_remember`, `viking_add_resource`         |
| RetainDB    | 5   | `retaindb_profile`, `retaindb_search`, `retaindb_context`, `retaindb_remember`, `retaindb_forget` |
| ByteRover   | 3   | `brv_query`, `brv_curate`, `brv_status`                                                           |
| Supermemory | 4   | `supermemory_store`, `supermemory_search`, `supermemory_forget`, `supermemory_profile`            |