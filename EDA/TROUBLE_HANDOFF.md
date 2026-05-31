# MCP Bridge 连接问题交接文档 (已修复)

**首次报告日期**: 2026年5月31日 16:26  
**本轮补充与修复日期**: 2026年5月31日 20:30  
**当前状态**: **已完全修复并连通**。已解决“插件端 WebSocket URL 错误”、“网关静默丢包”、以及“新旧插件协议不匹配（0.0.17 vs 0.1.13）”的全部阻塞点。

---

## 本轮结论摘要

### 已确认正确的部分

| 组件 | 当前状态 | 证据 |
|------|----------|------|
| Gateway (`server.js`) | ✓ 正常运行且升级为透明代理 | `lsof -i :18800` 正常监听，且日志显示双向转发正常 |
| Gateway 路径与代理 | ✓ 正确 | 实际监听 `ws://127.0.0.1:18800/ws/bridge` |
| 默认 Hermes 配置 | ✓ 已补齐 `jlceda` | `~/.hermes/config.yaml` 已加入 `mcp_servers.jlceda` |
| `jlceda` 启动方式 | ✓ 已澄清 | `dist/index.js` 是 **stdio MCP Server**，必须由 Hermes 按需拉起 |
| `jlceda` 进程 | ✓ 已观测到 | `pgrep -af 'node .*jlcmcp/dist/index.js'` 能看到运行中的 `node ... dist/index.js` |
| LCEDA Pro 模式 | ✓ ONLINE | `~/文档/LCEDA-Pro/config.json` 显示 `"type": "ONLINE"` |
| LCEDA 插件版本 | ✓ 已更新为 `0.1.13` | 已成功导入本地打包的 `jlc-bridge_v0.1.13.eext` |
| MCP Bridge 状态 | ✓ 已连通 (`connected: true`) | LCEDA 界面显示 `Bridge enabled (WebSocket)` 且网关日志正常捕获握手 |


---

## 最新根因分析

### 根因 1：之前的“后台启动 MCP Server”思路是错的

已验证：

```bash
export GATEWAY_WS_URL=ws://127.0.0.1:18800/ws/bridge
node /home/bitq/mcp-servers/jlcmcp/dist/index.js </dev/null
# 立即正常退出，退出码 0
```

原因：

- `jlcmcp/dist/index.js` 使用的是 `StdioServerTransport`
- 它不是常驻 daemon，而是应由 Hermes / AI IDE 通过 `stdio` 按需拉起
- 所以旧文档里“直接 `node dist/index.js` 后台常驻”的方案不成立

### 根因 2：之前排查只改了 `hw-engineer`，但实际使用的是默认 `hermes`

本轮已确认用户实际使用默认 Hermes 配置，而不是 `hw-engineer`。

因此本轮已经把 `jlceda` 配置补到了：

```yaml
# ~/.hermes/config.yaml
mcp_servers:
  jlceda:
    command: node
    args:
      - /home/bitq/mcp-servers/jlcmcp/dist/index.js
    env:
      GATEWAY_WS_URL: ws://127.0.0.1:18800/ws/bridge
```

修复后已观测到：

```bash
pgrep -af 'node .*jlcmcp/dist/index.js'
# 能看到 node /home/bitq/mcp-servers/jlcmcp/dist/index.js
```

说明：

- Hermes → `jlceda` → Gateway 这一侧链路已打通
- 当前已不再需要切到 `hw-engineer` 才能走 EDA 链路

### 根因 3：LCEDA 插件本地存储里写死了错误 URL

这是当前最关键、也是最后剩下的阻塞点。

用户截图显示：

```json
{
  "connected": false,
  "connectionState": "connecting",
  "transport": "sys_WebSocket",
  "serverUrl": "ws://127.0.0.1:18800",
  "configuredServerUrl": "ws://127.0.0.1:18800"
}
```

但 Gateway 和当前仓库源码都表明正确地址应为：

```text
ws://127.0.0.1:18800/ws/bridge
```

进一步从 LCEDA 本地数据中抽取到的证据：

文件：

```text
/home/bitq/.config/LCEDA-Pro/cache.x64.3/IndexedDB/https_pro.lceda.cn_0.indexeddb.leveldb/000137.log
```

提取结果包含以下关键片段：

```text
"lceda_mcp_bridge_config_v1 ... serverUrl ... ws://127.0.0.1:18800"
"configuredServerUrl ... ws://127.0.0.1:18800"
"lastError ... Connect timeout after 8000ms (url ws://127.0.0.1:18800)"
```

结论：

- LCEDA 插件当前运行版本不是本仓库里现在这份源码逻辑
- 它在自己的 IndexedDB / Local Storage 中保存了错误值
- 即便后端都正常，只要插件仍连 `ws://127.0.0.1:18800`，就会持续超时

---

## 当前架构状态

```
默认 Hermes 配置 (~/.hermes/config.yaml)  ✓ 已补齐 jlceda
        ↑
        │ (stdio)
        │
        v
MCP Server (dist/index.js)  ✓ 已可由 Hermes 按需拉起
        ↑
        │ (WebSocket)
        │
        v
Gateway (server.js)  ✓ 正常监听 ws://127.0.0.1:18800/ws/bridge
        ↑
        │ (WebSocket)
        │
        v
EDA Bridge (LCEDA Pro)  ✗ 仍连到错误地址 ws://127.0.0.1:18800
```

---

## 本轮已做的修改

### 1. 修复默认 Hermes 配置

文件：

```text
/home/bitq/.hermes/config.yaml
```

新增 `mcp_servers.jlceda`，使默认 `hermes` 也能拉起 `jlceda`，不再依赖 `hw-engineer`

### 2. 修复 EDA 辅助脚本

已修改：

- `./start-eda-mcp.sh`
- `./check-eda-mcp.sh`
- `./eda-mcp-wrapper.sh`
- `./eda-mcp.service`
- `./README.md`

调整方向：

- 不再把 `dist/index.js` 当后台守护进程启动
- 改为只管理 Gateway，并校验 Hermes 配置
- 默认优先读取 `~/.hermes/config.yaml`

### 3. 修正文档/设计说明

已把以下错误前提纠正：

- “`dist/index.js` 应当后台常驻运行”
- “只需要修 `hw-engineer` profile”

---

## 关键验证记录

### 验证 1：默认 Hermes 配置已包含 `jlceda`

```bash
python3 - <<'PY'
import yaml
from pathlib import Path
p = Path('/home/bitq/.hermes/config.yaml')
data = yaml.safe_load(p.read_text())
server = data['mcp_servers']['jlceda']
print(server['command'])
print(server['args'])
print(server['env']['GATEWAY_WS_URL'])
PY
```

结果：

```text
node
['/home/bitq/mcp-servers/jlcmcp/dist/index.js']
ws://127.0.0.1:18800/ws/bridge
```

### 验证 2：Gateway 与默认 Hermes 链路正常

```bash
./EDA/start-eda-mcp.sh
./EDA/check-eda-mcp.sh
```

结果要点：

- Gateway 运行中
- Hermes profile 已就绪：`/home/bitq/.hermes/config.yaml`
- 能看到 `jlceda` 进程
- `check-eda-mcp.sh` 显示“恢复条件满足”

### 验证 3：LCEDA 插件仍保存错误 URL

```bash
strings -a /home/bitq/.config/LCEDA-Pro/cache.x64.3/IndexedDB/https_pro.lceda.cn_0.indexeddb.leveldb/* \
  2>/dev/null | grep -E 'jlceda_mcp_bridge_config_v1|configuredServerUrl|127\.0\.0\.1:18800|Connect timeout'
```

结果可见：

- `serverUrl = ws://127.0.0.1:18800`
- `configuredServerUrl = ws://127.0.0.1:18800`
- `lastError = Connect timeout after 8000ms (url ws://127.0.0.1:18800)`

---

## 下一步建议（给接手模型）

### 优先级最高：修正 LCEDA 插件中的 URL

用户已确认 LCEDA 的 MCP Bridge 界面允许手动设置 WebSocket URL。

需要设置为：

```text
ws://127.0.0.1:18800/ws/bridge
```

不是：

```text
ws://127.0.0.1:18800
```

### 接手后的建议操作顺序

1. 在 LCEDA MCP Bridge 设置界面把 URL 改成 `ws://127.0.0.1:18800/ws/bridge`
2. 点击“确认”
3. 重新打开 MCP Bridge 状态窗口
4. 观察 `serverUrl` / `configuredServerUrl` 是否都变成带 `/ws/bridge` 的版本
5. 若仍被自动改回 `ws://127.0.0.1:18800`：
   - 继续定位插件这版 UI 的存储/归一化逻辑
   - 必要时在 LCEDA 关闭状态下直接修补其 IndexedDB / Local Storage
6. 若地址已改对仍不通，再抓 Gateway 连接日志，确认 EDA 是否真正连到了 `/ws/bridge`

### 不要再走的错误方向

- 不要再把 `node /home/bitq/mcp-servers/jlcmcp/dist/index.js` 当后台常驻服务启动
- 不要再只改 `hw-engineer` profile 而忽略默认 `~/.hermes/config.yaml`
- 不要再把 `ws://127.0.0.1:18800` 当成正确地址

---

## 最终修复方案与验证记录

### 1. 网关升级为透明代理
修改了 `gateway/server.js`，将原本基于特定消息属性的繁琐路由分发修改为**透明的双向广播转发**。这防止了网关因为不认识新插件/旧插件的特定属性（如 `hello`, `command`, `result` 等）而静默丢包。

### 2. 插件版本更新
- 确认 LCEDA Pro 原先加载的线上的 `jlceda-mcp-bridge` 插件（版本 `0.0.17`）与当前工作区的 `jlcmcp` 服务端使用的是完全不同的协议（前者使用 JSON-RPC `type: "request"`, 后者使用 `type: "command"`），因而即使连接了也永远无法握手成功。
- 在工作区 `jlc-bridge` 目录执行 `npm run build`，编译打包了最新的、支持 PCB 的 `jlc-bridge` 插件（版本 `0.1.13`）。
- 引导用户在 **扩展管理器** 中卸载了旧插件，并**手动导入**了最新编译生成的 `/home/bitq/mcp-servers/jlcmcp/jlc-bridge/build/jlc-bridge_v0.1.13.eext`。
- 将连接地址修改为正确的 `ws://127.0.0.1:18800/ws/bridge`，且在 **PCB 编辑器** 视图顶部菜单启用，握手确认成功。

---

## 相关文件位置

| 文件 | 路径 | 说明 |
|------|------|------|
| Gateway 脚本 | `~/mcp-servers/jlcmcp/gateway/server.js` | 实际监听 `/ws/bridge` |
| MCP Server | `~/mcp-servers/jlcmcp/dist/index.js` | stdio MCP Server，由 Hermes 按需拉起 |
| 默认 Hermes 配置 | `~/.hermes/config.yaml` | 当前实际使用的配置，已补 `jlceda` |
| EDA 启动脚本 | `./start-eda-mcp.sh` | 启动 Gateway 并检查 Hermes 配置 |
| EDA 检查脚本 | `./check-eda-mcp.sh` | 检查 Gateway / Hermes / LCEDA 模式 |
| LCEDA 主配置 | `~/文档/LCEDA-Pro/config.json` | 仅显示 ONLINE/OFFLINE，不含 bridge URL |
| LCEDA 本地存储 | `~/.config/LCEDA-Pro/cache.x64.3/IndexedDB/https_pro.lceda.cn_0.indexeddb.leveldb/` | 当前发现错误 URL 的位置 |

---

## 当前状态

- 后端链路：**已完全修通**
- 默认 Hermes 配置：**已修通**
- LCEDA 插件本地 URL：**已修复并正确连接**
- 网关路由转发：**已修复（升级为透明双向代理）**
- 整体状态：**已完全解决**

---

**创建者**: AI Assistant  
**最后更新**: 2026-05-31 20:30  
**状态**: 已解决 (Resolved)

