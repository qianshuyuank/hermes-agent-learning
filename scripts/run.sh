#!/bin/bash
# Hermes 学习资料整理 - 主控脚本
# 用法: ./run.sh [task_id] [phase]
# task_id: 1=官方文档, 2=网络资源, 3=Python脚本
# phase: plan|execute|review

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
STATE_FILE="$SCRIPT_DIR/state.json"
LOG_FILE="$SCRIPT_DIR/run.log"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

load_state() {
    if [[ ! -f "$STATE_FILE" ]]; then
        log "${RED}错误: 状态文件不存在${NC}"
        exit 1
    fi
    cat "$STATE_FILE"
}

save_state() {
    echo "$1" > "$STATE_FILE"
}

get_task() {
    local task_id=$1
    python3 -c "import json; t=json.load(open('$STATE_FILE')); print(json.dumps(t['tasks'][task_id-1]))"
}

update_task() {
    local task_id=$1
    local phase=$2
    local iteration=$3
    local status=$4
    local outputs=$5
    local notes=$6
    
    python3 << EOF
import json

with open('$STATE_FILE', 'r') as f:
    state = json.load(f)

task = state['tasks'][task_id-1]
task['phase'] = '$phase'
task['iteration'] = $iteration
task['status'] = '$status'
if '$outputs' != '':
    task['outputs'] = json.loads('''$outputs''')
if '$notes' != '':
    task['notes'] = json.loads('''$notes''')

state['current_task'] = $task_id
state['current_phase'] = '$phase'
state['iteration'] = $iteration
state['last_run'] = '$(date -u +%Y-%m-%dT%H:%M:%SZ)'

with open('$STATE_FILE', 'w') as f:
    json.dump(state, f, indent=2, ensure_ascii=False)

print("状态已更新")
EOF
}

advance_phase() {
    local task_id=$1
    local current_phase=$2
    local iteration=$3
    
    case $current_phase in
        plan)
            next_phase="execute"
            ;;
        execute)
            next_phase="review"
            ;;
        review)
            next_phase="execute"  # 审核通过后会重置为execute继续迭代
            ;;
    esac
    
    echo "$next_phase"
}

# ============================================
# 主流程
# ============================================

log "${GREEN}========== Hermes 学习资料整理开始 ==========${NC}"

# 读取当前状态
STATE=$(cat "$STATE_FILE")
CURRENT_TASK=$(echo "$STATE" | python3 -c "import sys,json; print(json.load(sys.stdin)['current_task'])")
CURRENT_PHASE=$(echo "$STATE" | python3 -c "import sys,json; print(json.load(sys.stdin)['current_phase'])")
ITERATION=$(echo "$STATE" | python3 -c "import sys,json; print(json.load(sys.stdin)['iteration'])")
COMPLETED=$(echo "$STATE" | python3 -c "import sys,json; print(json.load(sys.stdin)['completed'])")

if [[ "$COMPLETED" == "true" ]]; then
    log "${GREEN}所有任务已完成，无需继续运行${NC}"
    exit 0
fi

log "当前状态: 任务=$CURRENT_TASK, 阶段=$CURRENT_PHASE, 迭代=$ITERATION"

# 显示当前任务的详细信息
TASK_INFO=$(get_task $CURRENT_TASK)
TASK_NAME=$(echo "$TASK_INFO" | python3 -c "import sys,json; print(json.load(sys.stdin)['name'])")
TASK_DESC=$(echo "$TASK_INFO" | python3 -c "import sys,json; print(json.load(sys.stdin)['description'])")

log "${YELLOW}正在处理任务: [$CURRENT_TASK] $TASK_NAME${NC}"
log "任务描述: $TASK_DESC"

# ============================================
# 根据阶段执行对应动作
# ============================================

case $CURRENT_PHASE in
    plan)
        log "阶段: 规划 (Plan)"
        log "生成详细执行计划..."
        
        # 规划内容
        PLAN_CONTENT="# $TASK_NAME - 执行计划

## 任务目标
$TASK_DESC

## 搜索/整理范围

## 高质量标准
- 官方文档优先
- 有实际代码示例
- 最近2年内有更新

## 输出结构

## 执行步骤

## 验收标准
"
        
        # 保存计划到文件
        echo "$PLAN_CONTENT" > "$SCRIPT_DIR/outputs/task${CURRENT_TASK}_plan.md"
        
        # 更新状态 -> execute
        update_task $CURRENT_TASK "execute" 0 "in_progress" "[\"outputs/task${CURRENT_TASK}_plan.md\"]" "[]"
        log "${GREEN}规划完成，已进入实施阶段${NC}"
        ;;
        
    execute)
        log "阶段: 实施 (Execute)"
        
        # 增加迭代计数
        NEW_ITER=$((ITERATION + 1))
        log "迭代次数: $NEW_ITER / 3"
        
        # 更新状态为执行中
        update_task $CURRENT_TASK "execute" $NEW_ITER "in_progress" "" "[]"
        
        log "${YELLOW}请执行以下任务:${NC}"
        log "任务描述: $TASK_DESC"
        log "输出文件: outputs/task${CURRENT_TASK}_*.md"
        log "迭代完成后，将执行结果写入 outputs/task${CURRENT_TASK}_exec.md"
        
        # 注意：实际执行由外部Agent完成，这里只更新状态
        # 下次运行时会进入review阶段
        ;;
        
    review)
        log "阶段: 审核 (Review)"
        
        # 检查执行结果是否存在
        EXEC_FILE="$SCRIPT_DIR/outputs/task${CURRENT_TASK}_exec.md"
        if [[ ! -f "$EXEC_FILE" ]]; then
            log "${RED}错误: 执行结果文件不存在: $EXEC_FILE${NC}"
            log "请先完成实施阶段"
            exit 1
        fi
        
        log "审核文件: $EXEC_FILE"
        log "${YELLOW}审核内容质量:${NC}"
        log "1. 内容是否完整？"
        log "2. 是否有事实错误？"
        log "3. 代码示例是否可用？"
        log "4. 是否符合高质量标准？"
        
        log "${YELLOW}审核完成后:${NC}"
        log "- 如通过: 将输出合并到 docs/ 并进入下一任务"
        log "- 如不通过: 更新notes，返回execute重新迭代"
        log "结果写入: outputs/task${CURRENT_TASK}_review.md"
        ;;
        
    *)
        log "${RED}未知阶段: $CURRENT_PHASE${NC}"
        exit 1
        ;;
esac

log "${GREEN}========== 本次运行结束 ==========${NC}"