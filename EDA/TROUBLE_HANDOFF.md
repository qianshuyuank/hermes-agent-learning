# MCP Bridge 连接问题交接文档

**报告日期**: 2026年5月31日 16:26  
**问题**: MCP bridge 显示未连接，报错：`Connect timeout after 8000ms (url ws://127.0.0.1:18800)`

---

## 问题诊断结果

### ✓ 已验证的组件状态

| 组件 | 状态 | 进程ID | 端口 |
|------|------|--------|------|
| Gateway (server.js) | ✓ 运行中 | 90369 | 18800 |
| TCP 连接 | ✓ 正常 | - | 18800 |
| HTTP 升级要求 | ✓ 正确 | - | 426 Upgrade Required |
| 端口监听 | ✓ 正常 | LISTEN | 18800 |

### ✗ 发现的问题

| 问题 | 状态 | 严重性 |
|------|------|--------|
| **MCP Server 未运行** | ✗ 未启动 | 🔴 **严重** |
| WebSocket 握手失败 | ✗ 400 Bad Request | 🟡 中等 |
| EDA 插件无法连接 | ✗ 超时 | 🟡 中等 |

---

## 根本原因分析

### 核心问题：MCP Server 进程未启动

```bash
# 检查结果
$ ps aux | grep index.js | grep -v grep
# 无输出 = 进程不存在
```

**三层架构中缺少中间层**：

```
Hermes Agent (hw-engineer)  ✓ 运行
        ↑
        │ (stdio)
        │
        v
MCP Server (index.js)  ✗ 未运行 ← 【问题所在】
        ↑
        │ (WebSocket)
        │
        v
Gateway (server.js)  ✓ 运行 (等待连接中)
        ↑
        │ (WebSocket)
        │
        v
EDA Bridge (LCEDA Pro)  ✗ 连接超时
```

**为什么会超时**：
1. Gateway 正在监听 `ws://127.0.0.1:18800/ws/bridge`
2. 但没有 MCP Server 作为客户端连接到 Gateway
3. EDA 插件尝试连接时，只看到 Gateway 的 WebSocket 服务端，无法建立通信链路
4. 8 秒后超时报错

---

## 解决方案

### 方案 A：启动 MCP Server（推荐）

```bash
# 方式1：直接运行
node /home/bitq/mcp-servers/jlcmcp/dist/index.js

# 方式2：使用启动脚本
cd /home/bitq/github/hermes-agent-learning/EDA
./start-eda-mcp.sh

# 方式3：用systemd服务
sudo systemctl start eda-mcp.service
sudo systemctl status eda-mcp.service
```

**验证 MCP Server 已启动**：
```bash
ps aux | grep "index.js" | grep -v grep
# 应该显示 node 进程

# 检查 WebSocket 连接
ps aux | grep node | grep -E "gateway|mcp"
```

### 方案 B：检查环境变量

确保 MCP Server 收到正确的 Gateway URL：

```bash
# 在启用 MCP Server 时设置
export GATEWAY_WS_URL=ws://127.0.0.1:18800/ws/bridge
node /home/bitq/mcp-servers/jlcmcp/dist/index.js
```

或在 Hermes 配置中指定：

```yaml
# ~/.hermes/profiles/hw-engineer/config.yaml
mcp_servers:
  jlceda:
    command: node
    args: ['/home/bitq/mcp-servers/jlcmcp/dist/index.js']
    env:
      GATEWAY_WS_URL: ws://127.0.0.1:18800/ws/bridge
```

---

## 实施步骤

### 快速修复（5分钟内恢复）

```bash
# 1. 停止现有服务
cd /home/bitq/github/hermes-agent-learning/EDA
./stop-eda-mcp.sh

# 2. 启动完整栈（Gateway + MCP Server）
./start-eda-mcp.sh

# 3. 验证连接
sleep 2
ps aux | grep node | grep -E "gateway|mcp"

# 4. 在 LCEDA Pro 中检查连接状态（应显示 connected: true）
```

### 长期修复（自动化管理）

```bash
# 1. 启用 systemd 服务
sudo systemctl enable eda-mcp.service
sudo systemctl restart eda-mcp.service

# 2. 查看服务日志
sudo journalctl -u eda-mcp.service -f

# 3. 设置重启策略
systemctl status eda-mcp.service
```

---

## 连接流程验证

启动后应看到以下连接建立过程：

```
时间轴：

[T0] Gateway 启动
     日志: ✅ Gateway started on ws://127.0.0.1:18800/ws/bridge

[T1] MCP Server 启动（连接 Gateway）
     日志: [+] New connection from 127.0.0.1

[T2] 用户在 LCEDA Pro 打开扩展
     日志: [+] New connection from 127.0.0.1

[T3] 通信正常
     LCEDA Pro 显示: "connected": true
     MCP Server 收发消息
```

---

## 文件位置参考

| 文件 | 路径 | 作用 |
|------|------|------|
| Gateway 脚本 | `~/mcp-servers/jlcmcp/gateway/server.js` | WebSocket 中转层 |
| MCP Server | `~/mcp-servers/jlcmcp/dist/index.js` | 主要通信端点 |
| 启动脚本 | `./start-eda-mcp.sh` | 一键启动 Gateway + Server |
| 停止脚本 | `./stop-eda-mcp.sh` | 优雅关闭服务 |
| Systemd 配置 | `./eda-mcp.service` | 自动管理服务 |

---

## 常见问题速查

### Q: 为什么重启后还是超时？
**A**: 检查 MCP Server 是否真的启动了
```bash
ps aux | grep "index.js"  # 必须能看到进程
lsof -i :18800           # 必须能看到 node 在 LISTEN
```

### Q: Gateway 显示 400 Bad Request 是什么原因？
**A**: WebSocket 握手格式不对。但这不是主要问题。主要问题是 MCP Server 没启动。

### Q: 可以不用 Gateway 吗？
**A**: 不行。Gateway 是必需的中间层，用来转接 stdio（Hermes→MCP Server）和 WebSocket（MCP Server↔EDA）。

### Q: 如何让服务开机自启？
**A**: 使用 systemd 服务
```bash
sudo systemctl enable eda-mcp.service
```

---

## 检查清单

启动服务前，检查以下项目：

- [ ] Gateway 文件存在：`~/mcp-servers/jlcmcp/gateway/server.js`
- [ ] MCP Server 文件存在：`~/mcp-servers/jlcmcp/dist/index.js`
- [ ] Node.js 已安装：`node --version`
- [ ] 依赖已安装：`cd ~/mcp-servers/jlcmcp/gateway && npm install`
- [ ] 18800 端口未被占用：`lsof -i :18800`
- [ ] Hermes 配置正确：`~/.hermes/profiles/hw-engineer/config.yaml`
- [ ] LCEDA Pro 已启用"外部交互"权限

---

## 后续行动

1. **立即执行**: 运行 `./start-eda-mcp.sh` 启动服务
2. **验证状态**: 检查 LCEDA Pro 扩展连接状态
3. **监控日志**: 观察是否有报错或异常连接
4. **配置自启**: 设置 systemd 自动管理
5. **文档更新**: 如有其他问题，补充到本文档

---

**创建者**: AI Assistant  
**最后更新**: 2026-05-31 16:26  
**状态**: 待实施
