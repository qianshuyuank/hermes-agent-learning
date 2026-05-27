#!/usr/bin/env python3
"""
状态更新脚本 - 由外部Agent调用，更新任务状态
用法:
  python3 update_state.py <task_id> <phase> <iteration> <status> [outputs_json] [notes_json]
"""

import json
import os
import sys
from datetime import datetime

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
STATE_FILE = os.path.join(SCRIPT_DIR, "state.json")


def load_state():
    with open(STATE_FILE, 'r', encoding='utf-8') as f:
        return json.load(f)


def save_state(state):
    with open(STATE_FILE, 'w', encoding='utf-8') as f:
        json.dump(state, f, indent=2, ensure_ascii=False)


def main():
    if len(sys.argv) < 5:
        print("用法: python3 update_state.py <task_id> <phase> <iteration> <status> [outputs_json] [notes_json]")
        print("示例: python3 update_state.py 1 execute 2 in_progress '[\"file.md\"]' '[\"需要补充示例\"]'")
        sys.exit(1)
    
    task_id = int(sys.argv[1])
    phase = sys.argv[2]
    iteration = int(sys.argv[3])
    status = sys.argv[4]
    outputs = json.loads(sys.argv[5]) if len(sys.argv) > 5 and sys.argv[5] else []
    notes = json.loads(sys.argv[6]) if len(sys.argv) > 6 and sys.argv[6] else []
    
    state = load_state()
    task = state['tasks'][task_id - 1]
    
    task['phase'] = phase
    task['iteration'] = iteration
    task['status'] = status
    task['outputs'] = outputs
    task['notes'] = notes
    
    state['current_task'] = task_id
    state['current_phase'] = phase
    state['iteration'] = iteration
    state['last_run'] = datetime.utcnow().strftime('%Y-%m-%dT%H:%M:%SZ')
    
    save_state(state)
    print(f"状态已更新: 任务{task_id}, 阶段={phase}, 迭代={iteration}, 状态={status}")
    print(f"输出文件: {outputs}")
    print(f"备注: {notes}")


if __name__ == "__main__":
    main()