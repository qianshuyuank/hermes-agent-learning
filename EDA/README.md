# EasyEDA Pro (LCEDA Pro) MCP 配置指南

## 系统架构

三层架构：

```
┌─────────────────┐    stdio    ┌─────────────────┐   WebSocket   ┌─────────────────┐
│  Hermes Agent   │◄───────────►│   MCP Server    │◄────────────►│     Gateway      │
│ (hw-engineer)   │             │ (jlcmcp/dist)   │              │  (server.js)    │
└─────────────────┘             └─────────────────┘              └────────┬────────┘
                                                                         │
                                                                         ▼
                                                                ┌─────────────────┐
                                                                │   jlc-bridge     │
                                                                │  (EDA 扩展)      │
                                                                └─────────────────┘
```

## 组件说明

| 组件 | 路径 | 端口 | 说明 |
|------|------|------|------|
| Gateway | `~/mcp-servers/jlcmcp/gateway/server.js` | 18800 | WebSocket 中转层 |
| MCP Server | `~/mcp-servers/jlcmcp/dist/index.js` | - | 与 Hermes 通过 stdio 通信 |
| jlc-bridge | EDA 扩展目录 | - | 运行在 LCEDA Pro 内部 |

## 启动步骤

### 1. 启动 Gateway（中转层，常驻）

```bash
cd ~/github/hermes-agent-learning/EDA && ./start-eda-mcp.sh
```

或手动启动：

```bash
cd ~/mcp-servers/jlcmcp/gateway && node server.js
```

### 2. 配置 Hermes profile

注意：`jlcmcp/dist/index.js` 是 **stdio MCP Server**，应由 Hermes / AI IDE 在需要时按会话拉起，**不要**把它当成后台常驻守护进程直接 `node ... &` 启动。否则标准输入关闭后它会立即退出。

`~/.hermes/profiles/hw-engineer/config.yaml` 必须使用 **YAML 数组** 形式的 `args`：

`~/.hermes/profiles/hw-engineer/config.yaml`:

```yaml
mcp_servers:
  jlceda:
    command: node
    args:
      - /home/bitq/mcp-servers/jlcmcp/dist/index.js
    env:
      GATEWAY_WS_URL: ws://127.0.0.1:18800/ws/bridge
```

错误示例：

```yaml
args: "['/home/bitq/mcp-servers/jlcmcp/dist/index.js']"
```

上面这种写法会把 `args` 解析成字符串，导致 Hermes 无法正确启动 `jlceda`。

### 3. 重启 Hermes / 新开会话

完成 Gateway 启动和 profile 配置后，重启 Hermes 或新开一个启用 `hw-engineer` profile 的会话。此时 Hermes 会通过 stdio 按需启动 `jlceda`。

## LCEDA Pro 配置

### 切换为在线模式

如果"扩展管理器"不可见，需要修改配置：

```bash
sed -i 's/"type": "OFFLINE"/"type": "ONLINE"/' ~/文档/LCEDA-Pro/config.json
```

然后重启 LCEDA Pro，选择"全在线"或"半离线"模式启动。

### 开启扩展外部交互权限

1. 打开 LCEDA Pro
2. 顶部菜单 → **高级**（V3 UI）
3. **扩展管理器**
4. 找到 `jlc-bridge` 扩展
5. 启用 **"允许外部交互"** 权限

### 验证连接状态

在 LCEDA Pro 的扩展配置界面应显示：

```json
{
  "connected": true,
  "connectionState": "connected"
}
```

## 脚本说明

| 脚本 | 功能 |
|------|------|
| `start-eda-mcp.sh` | 启动 Gateway，并校验 Hermes 的 `jlceda` 配置 |
| `check-eda-mcp.sh` | 检查 Gateway、Hermes profile 和 LCEDA 模式 |
| `stop-eda-mcp.sh` | 停止手动启动的 MCP 进程（如存在） |

## 常见问题

### Q: LCEDA 显示 "未启用扩展和独立脚本的外部交互权限"

需要在扩展管理器里为 `jlc-bridge` 开启"外部交互"权限。

### Q: "connected: false"

检查顺序：
1. Gateway 是否运行 (`lsof -i :18800`)
2. Hermes profile 的 `jlceda.args` 是否为 YAML 数组
3. 是否已重启 Hermes / 新开会话，让 MCP Server 通过 stdio 按需启动
4. LCEDA 是否开启外部交互权限

### Q: MCP Server 启动报错 "Cannot find module"

需要先编译：
```bash
cd ~/mcp-servers/jlcmcp && npm install && npm run build
```
