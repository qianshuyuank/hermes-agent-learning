#!/usr/bin/env python3
"""
Hermes 学习资料整理 - 任务执行脚本
由外部Agent调用，执行具体的研究/写作任务
"""

import json
import os
import sys
from datetime import datetime

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_DIR = os.path.dirname(SCRIPT_DIR)
STATE_FILE = os.path.join(SCRIPT_DIR, "state.json")
OUTPUTS_DIR = os.path.join(SCRIPT_DIR, "outputs")
DOCS_DIR = os.path.join(PROJECT_DIR, "docs")


def load_state():
    with open(STATE_FILE, 'r', encoding='utf-8') as f:
        return json.load(f)


def save_state(state):
    with open(STATE_FILE, 'w', encoding='utf-8') as f:
        json.dump(state, f, indent=2, ensure_ascii=False)


def get_task(state, task_id):
    return state['tasks'][task_id - 1]


def update_task_phase(state, task_id, phase, iteration, status, outputs=None, notes=None):
    task = state['tasks'][task_id - 1]
    task['phase'] = phase
    task['iteration'] = iteration
    task['status'] = status
    if outputs is not None:
        task['outputs'] = outputs
    if notes is not None:
        task['notes'] = notes
    state['current_task'] = task_id
    state['current_phase'] = phase
    state['iteration'] = iteration
    state['last_run'] = datetime.utcnow().strftime('%Y-%m-%dT%H:%M:%SZ')
    return state


def advance_to_next_task(state):
    """进入下一个任务"""
    current = state['current_task']
    if current < len(state['tasks']):
        state['current_task'] = current + 1
        state['current_phase'] = 'plan'
        state['iteration'] = 0
        task = state['tasks'][current]  # current is 1-indexed
        task['status'] = 'completed'
    else:
        state['completed'] = True
    return state


def main():
    if len(sys.argv) < 2:
        print("用法: python3 execute_task.py <task_id>")
        print("  task_id: 1=官方文档, 2=网络资源, 3=Python脚本")
        sys.exit(1)
    
    task_id = int(sys.argv[1])
    state = load_state()
    task = get_task(state, task_id)
    
    print(f"任务: {task['name']}")
    print(f"描述: {task['description']}")
    print(f"阶段: {task['phase']}")
    print(f"迭代: {task['iteration']}")
    print()
    print("=" * 60)
    print("请完成上述任务，完成后将结果保存到:")
    print(f"  {OUTPUTS_DIR}/task{task_id}_exec.md")
    print("并调用 update_state.py 更新状态")
    print("=" * 60)


if __name__ == "__main__":
    main()