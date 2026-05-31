# AI 助手 EDA 电路板设计与协作指南

本指南专为 AI 编码助手（如 Antigravity）设计，旨在帮助其快速理解嘉立创 EDA (LCEDA Pro) MCP Server (`jlceda`) 的架构体系、自检方法以及如何精准调度所有 39 个自动化设计工具。

---

## 1. 核心架构与数据流

在与立创 EDA 交互时，AI 助手的数据流向如下：

```
[AI 助手/客户端] ──stdio──> [MCP Server] ──WebSocket──> [Gateway] ──> [jlc-bridge 插件] ──> [LCEDA Pro 内部]
```

* **MCP Server** (`~/mcp-servers/jlcmcp/dist/index.js`)：接收 stdio 的 MCP 协议请求并转化为底层命令。
* **Gateway** (`~/mcp-servers/jlcmcp/gateway/server.js`)：一个运行在 `18800` 端口的透明 WebSocket 转发网关，充当中转。
* **jlc-bridge 插件** (LCEDA 插件 `0.1.13`)：运行在 EDA 编辑器内，执行最终的 EDA API 调用并返回结果。

> [!IMPORTANT]
> 如果通信中断，AI 助手应依次检查 **网关进程** 和 **插件连接状态**。

---

## 2. 运行状态与自检方法

当 AI 助手遇到网络超时或工具调用失败时，应在终端依次执行以下诊断命令：

### 2.1 检查网关与服务状态
```bash
# 检查网关端口监听状态（应当输出 node LISTEN 18800）
lsof -i :18800

# 检查系统自启服务状态
systemctl status eda-mcp.service
```

### 2.2 运行一键自检脚本
工作区提供了完整的自检脚本，AI 助手可直接运行并解析其输出：
```bash
/home/bitq/github/hermes-agent-learning/EDA/check-eda-mcp.sh
```
* **正常输出**：显示 `[✓] 恢复条件满足`，表明 Gateway 和 Hermes 配置均已就绪。
* **异常输出**：若未运行，可执行 `/home/bitq/github/hermes-agent-learning/EDA/start-eda-mcp.sh` 重启。

---

## 3. 39 个 MCP 工具分类字典

以下工具集的参数单位统一为 **mil**（密耳，1 mil = 0.0254 mm）。

### 3.1 状态与分析模块 (9)

| 工具名称 | 核心输入参数 | AI 调用时机 / 判定规则 | 典型 Prompt 示例 |
|:---|:---|:---|:---|
| `pcb_get_state` | 无 | **写操作前的首选步骤**。需要获取当前 PCB 的完整元件坐标、网络关系和板框时调用。 | "读取当前 PCB 状态" |
| `pcb_screenshot` | 无 | 当用户需要直观视觉确认，或者 AI 需要验证器件对齐、丝印避让的实际画面时。 | "给我截个图看看布局" |
| `pcb_run_drc` | 无 | **设计完成或大修改后的必用工具**。用于验证是否有开路、短路或间距冲突。 | "运行 DRC 规则检查" |
| `pcb_get_tracks` | `net` (网络名), `layer` (层) | 当仅需要精细查询某条走线或某个层上的走线段，而非获取整板状态时。 | "查询 GND 网络的顶层走线" |
| `pcb_get_pads` | `designator` (位号) | 需要精确查询某个特定芯片或阻容元件的焊盘坐标、网络和尺寸时。 | "获取 U1 的所有焊盘" |
| `pcb_get_net_primitives` | `net` (网络名) | 需要追踪或分析某个特定的电气网络（如 +5V、GND）所连的所有图元。 | "查询 VCC 网络关联的所有图元" |
| `pcb_get_board_info` | 无 | 获取当前编辑工程的整体尺寸、路径及基础属性。 | "读取板卡基本工程信息" |
| `pcb_get_feature_support` | 无 | 查询底层 bridge 插件支持的功能白皮书。 | "查询支持的 EDA API 列表" |
| `pcb_ping` | 无 | 用于快速诊断 WebSocket 链路是否畅通。 | "诊断桥接连接是否正常" |

### 3.2 元件操作模块 (6)

| 工具名称 | 核心输入参数 | AI 调用时机 / 判定规则 | 典型 Prompt 示例 |
|:---|:---|:---|:---|
| `pcb_move_component` | `designator`, `x`, `y`, `rotation` | 知道目标坐标，直接进行单个元件定位移动时。 | "把 C1 移动到 (1000, 500) 坐标" |
| `pcb_relocate_component`| `designator`, `x`, `y` | 移动元件时**自动安全拆解已有的连线**（断开走线），防止拉扯飞线变形。 | "安全搬迁 U2 到 (1500, 2000)" |
| `pcb_batch_move` | `moves` (坐标及位号数组) | 需要同时对齐或移动一排阻容、排针时，比单步移动效率高。 | "将 R1, R2, R3 分别向右移动 200 mil" |
| `pcb_select_component` | `designator` | 使 EDA 编辑器闪烁并高亮选中某个器件，方便人类用户视觉聚焦。 | "在编辑器中帮我选中 MCU 芯片" |
| `pcb_delete_selected` | 无 | 清理不需要的多余器件或被选中删除的图元。 | "删除我当前选中的垃圾图元" |
| `pcb_create_component` | `libId`, `x`, `y` | 从立创商城库或个人库中放置新的封装到画布中。 | "在原点放置一个 NE555 芯片" |

### 3.3 走线与过孔模块 (4)

| 工具名称 | 核心输入参数 | AI 调用时机 / 判定规则 | 典型 Prompt 示例 |
|:---|:---|:---|:---|
| `pcb_route_track` | `net`, `points` (坐标数组), `layer`, `width` | 在两点或多点之间布线。支持指定线宽。 | "在顶层画一条 10 mil 宽的 VCC 走线" |
| `pcb_create_via` | `net`, `x`, `y`, `drill`, `diameter` | 在多层板设计中，需要换层打过孔时调用。 | "在 (500, 500) 打一个 12/24 的 GND 过孔" |
| `pcb_delete_tracks` | `primitiveIds` (走线 ID 数组) | 重新布线前清理旧的错误走线。 | "把连接错误的那几段走线删掉" |
| `pcb_delete_via` | `primitiveIds` | 清理废弃的过孔。 | "删除指定的过孔" |

### 3.4 铺铜与禁布区 (4)

| 工具名称 | 核心输入参数 | AI 调用时机 / 判定规则 | 典型 Prompt 示例 |
|:---|:---|:---|:---|
| `pcb_create_copper_pour`| `net`, `layer`, `x1`, `y1`, `x2`, `y2` | 大面积接地或电源铺铜，用于散热和抗干扰。 | "在底层为 GND 网络建一个全板铺铜" |
| `pcb_delete_pour` | `primitiveId` | 重新规划电源层或信号层时清除原有铜皮。 | "删除这个覆铜区" |
| `pcb_create_keepout` | `layer`, `x1`, `y1`, `x2`, `y2` | 在特定物理边界（如板边、结构孔周围）禁止画线或铺铜。 | "在定位孔周围画一个 100mil 禁布区" |
| `pcb_delete_keepout` | `primitiveId` | 规则放宽后，清理多余的禁布边界。 | "移除该禁布区" |

### 3.5 丝印管理模块 (3)

| 工具名称 | 核心输入参数 | AI 调用时机 / 判定规则 | 典型 Prompt 示例 |
|:---|:---|:---|:---|
| `pcb_get_silkscreens` | 无 | 排查丝印是否盖在焊盘上，或排查丝印遮挡。 | "读取整板丝印文本和坐标" |
| `pcb_move_silkscreen` | `primitiveId`, `x`, `y`, `rotation` | 精细调整特定元器件标号（如 R1、C1 的位置和角度）。 | "把 U1 的丝印标号移开 50 mil" |
| `pcb_auto_silkscreen` | 无 | **出图前的标准美化动作**。自动排列所有丝印文字，避免重叠或盖住焊盘。 | "自动美化排版整板的丝印文字" |

### 3.6 约束与差分模块 (6)

| 工具名称 | 核心输入参数 | AI 调用时机 / 判定规则 | 典型 Prompt 示例 |
|:---|:---|:---|:---|
| `pcb_create_diff_pair` | `name`, `posNet`, `negNet` | 针对 USB、以太网、HDMI 等高速差分信号，建立差分网络组。 | "创建一对 USB_D 的差分网络组" |
| `pcb_list_diff_pairs` | 无 | 列出当前板卡所有的差分对约束。 | "列出当前板卡所有差分约束" |
| `pcb_delete_diff_pair` | `name` | 解除不需要的高速差分对限制。 | "删除名为 USB 的差分对" |
| `pcb_create_equal_length`| `name`, `nets` | 针对 DDR、数据总线等需要等长控制的平行信号线，编入等长约束组。 | "创建名为 ADDR_BUS 的等长约束组" |
| `pcb_list_equal_lengths`| 无 | 获取等长设置清单。 | "列出所有等长信号组" |
| `pcb_delete_equal_length`| `name` | 解除等长约束关系。 | "删除 ADDR 信号等长组" |

### 3.7 原理图与文档控制 (4)

| 工具名称 | 核心输入参数 | AI 调用时机 / 判定规则 | 典型 Prompt 示例 |
|:---|:---|:---|:---|
| `sch_get_state` | 无 | 在进行原理图设计时，获取当前原理图全部元件及连接关系。 | "读取原理图器件连接状态" |
| `sch_get_netlist` | 无 | 从原理图导出网表，用于同步导入 PCB 交互。 | "生成当前原理图的网表" |
| `sch_run_drc` | 无 | 检查原理图逻辑错误（如悬空引脚、单端网络等）。 | "运行原理图电气规范 DRC" |
| `pcb_open_document` | `uuid` | 在多页原理图或 PCB 视图之间进行焦点切换。 | "切换到主控板 PCB 视图" |

### 3.8 计算工具 (2)

| 工具名称 | 核心输入参数 | AI 调用时机 / 判定规则 | 典型 Prompt 示例 |
|:---|:---|:---|:---|
| `calc_impedance` | `type`, `h` (介质厚度), `w` (线宽) 等 | 差分走线或高速阻抗匹配走线前，AI 必须计算阻抗以决定线宽。 | "计算 50 欧姆共面波导线宽参数" |
| `calc_trace_width` | `current` (电流), `tempRise` (温升) 等 | 大电流走线（如电源、马达驱动线）前，AI 应估算安全线宽。 | "计算 3A 电流需要的电源线宽" |

### 3.9 PCB 智能 Agent (1)

| 工具名称 | 核心输入参数 | AI 调用时机 / 判定规则 | 典型 Prompt 示例 |
|:---|:---|:---|:---|
| `pcb_agent` | `task` (高层抽象任务描述) | 当用户给出的任务非常复杂（例如“完成这块 USB HUB 的全局布局”），AI 助手可以委托 `pcb_agent` 进行多步自主推演和执行。 | "通过自主 Agent 对目前电路板的布局结构进行优化" |

---

## 4. AI 助手开发最佳实践 (Best Practices)

1. **写前必读 (Read-Before-Write)**
   在任何修改（移动器件、布线）之前，AI 助手**必须**先调用 `pcb_get_state` 获取最新坐标。不能依赖记忆中的历史坐标，防止干涉冲突。
   
2. **渐进式 DRC 校验 (Incremental DRC)**
   每完成一组关键信号线的布线（如差分对或电源主干线），或者摆放完密集封装芯片后，AI 助手应主动执行 `pcb_run_drc`。在发生冲突的第一时间修正，而不是累积到最后一次性修改。

3. **安全断线移动 (Safe Move)**
   当移动带有复杂连线的元器件时，优先调用 `pcb_relocate_component`（安全搬迁，自动切断走线），它会清理凌乱的折角线条并恢复成清晰的“飞线”状态，比直接硬拽 `pcb_move_component` 更不容易造成过孔或走线撕裂。

4. **物理单位严格校验**
   LCEDA Pro 使用的单位均为 `mil`。AI 在接收到人类口述的 `mm`（毫米）指令时，**必须**使用以下换算比率并四舍五入后下发：
   $$\text{mil} = \text{mm} \times 39.37$$
   例如: $0.5\text{ mm} \approx 20\text{ mil}$。

---

## 5. 连接问题快速诊断树

```
[调用出错！]
   │
   ├──> 检查是否因为没有打开任何 PCB 文档？
   │       ├──> 是：提示用户打开或新建一个 PCB 编辑器。
   │       └──> 否：检查 Gateway 进程状态。
   │
   └──> 运行 `lsof -i :18800`
           ├──> 没监听：运行 `sudo systemctl restart eda-mcp.service` 重启网关。
           └──> 有监听：在 LCEDA Pro 扩展管理器里查看 JLC Bridge 状态是否为已连接。
                   ├──> 未连接：提示用户检查是否开启了 “允许外部交互” 权限。
                   └──> 已连接：检查 stdio 通信日志，或重启 AI IDE 会话。
```
