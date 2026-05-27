# 任务3：Python 脚本使用 Hermes

## API 用法、Demo、工具封装

> 整理 Python 脚本使用 Hermes Agent 的方法，2026-05-25

---

## 一、核心概念

### 1.1 Python 与 Hermes 的关系

Hermes Agent 本身由 Python 编写，提供：
- **CLI 工具** `hermes` 命令
- **Python SDK/模块** 供其他程序调用
- **工具注册系统** 供扩展功能

### 1.2 调用方式

| 方式 | 说明 |
|------|------|
| `subprocess` / `terminal()` | 通过命令行调用 |
| Python 模块导入 | 直接导入 Hermes 内部模块（不推荐） |
| MCP 协议 | 通过 Model Context Protocol 调用 |
| HTTP API | Gateway 提供 REST API |

---

## 二、命令行调用（最常用）

### 2.1 基本调用

```python
import subprocess

# 单次查询
result = subprocess.run(
    ["hermes", "chat", "-q", "What is 2+2?"],
    capture_output=True,
    text=True,
    timeout=60
)
print(result.stdout)
```

### 2.2 带配置调用

```python
import subprocess

# 指定模型和 Provider
result = subprocess.run(
    ["hermes", "chat", "-q", "Hello", 
     "--model", "anthropic/claude-sonnet-4",
     "--provider", "openrouter"],
    capture_output=True,
    text=True,
    timeout=60,
    cwd="/path/to/project"
)
print(result.stdout)
```

### 2.3 后台运行

```python
import subprocess
import time

# 启动后台任务
proc = subprocess.Popen(
    ["hermes", "chat", "-q", "Research this topic..."],
    stdout=subprocess.PIPE,
    stderr=subprocess.PIPE
)

# 等待完成
time.sleep(30)
stdout, stderr = proc.communicate(timeout=60)
print(stdout.decode())
```

### 2.4 使用 tmux 管理多会话

```python
import subprocess

def create_hermes_session(session_name, prompt):
    """创建命名的 tmux 会话并发送命令"""
    # 创建分离的会话
    subprocess.run(
        ["tmux", "new-session", "-d", "-s", session_name,
         "-x", "120", "-y", "40", f"hermes -w"],
        check=True
    )
    # 等待启动
    time.sleep(8)
    # 发送命令
    subprocess.run(
        ["tmux", "send-keys", "-t", session_name, prompt, "Enter"],
        check=True
    )

def get_session_output(session_name):
    """获取 tmux 会话输出"""
    result = subprocess.run(
        ["tmux", "capture-pane", "-t", session_name, "-p"],
        capture_output=True,
        text=True
    )
    return result.stdout

def kill_session(session_name):
    """关闭 tmux 会话"""
    subprocess.run(["tmux", "kill-session", "-t", session_name])
```

---

## 三、Tmux 多 Agent 协作

### 3.1 并行任务执行

```python
import subprocess
import time
from concurrent.futures import ThreadPoolExecutor, as_completed

def run_hermes_task(task_id, prompt, model=None):
    """运行单个 Hermes 任务"""
    session_name = f"hermes_{task_id}"
    
    # 创建会话
    subprocess.run(
        ["tmux", "new-session", "-d", "-s", session_name,
         "-x", "120", "-y", "40", "hermes"],
        check=True
    )
    time.sleep(8)
    
    # 发送任务
    cmd = ["tmux", "send-keys", "-t", session_name, prompt, "Enter"]
    if model:
        cmd = ["tmux", "send-keys", "-t", session_name, 
               f"/model {model} && {prompt}", "Enter"]
    subprocess.run(cmd, check=True)
    
    # 等待执行
    time.sleep(60)
    
    # 获取输出
    result = subprocess.run(
        ["tmux", "capture-pane", "-t", session_name, "-p"],
        capture_output=True,
        text=True
    )
    
    # 清理
    subprocess.run(["tmux", "kill-session", "-t", session_name])
    
    return result.stdout

def parallel_hermes_tasks(tasks):
    """并行执行多个 Hermes 任务"""
    results = {}
    with ThreadPoolExecutor(max_workers=3) as executor:
        futures = {
            executor.submit(run_hermes_task, t["id"], t["prompt"], t.get("model")): t["id"]
            for t in tasks
        }
        for future in as_completed(futures):
            task_id = futures[future]
            try:
                results[task_id] = future.result()
            except Exception as e:
                results[task_id] = f"Error: {e}"
    return results

# 使用示例
tasks = [
    {"id": 1, "prompt": "Research AI agents", "model": "claude-sonnet-4"},
    {"id": 2, "prompt": "Write docs for my project"},
    {"id": 3, "prompt": "Review this code: /path/to/code"},
]

results = parallel_hermes_tasks(tasks)
for task_id, output in results.items():
    print(f"Task {task_id}: {output[:200]}...")
```

### 3.2 Agent 间通信

```python
import subprocess

def relay_context(source_session, target_session, context):
    """将一个 Agent 的输出传递给另一个"""
    # 捕获源会话输出
    output = subprocess.run(
        ["tmux", "capture-pane", "-t", source_session, "-p"],
        capture_output=True,
        text=True
    ).stdout
    
    # 发送到目标会话
    message = f"Context from {source_session}: {context}\n\nOutput:\n{output[-500:]}"
    subprocess.run(
        ["tmux", "send-keys", "-t", target_session, message, "Enter"],
        check=True
    )

# 使用示例：backend agent 将 API schema 传给 frontend agent
relay_context("backend", "frontend", "API schema from backend")
```

---

## 四、状态管理

### 4.1 读取状态文件

```python
import json
from pathlib import Path

def read_learning_state():
    """读取学习任务状态"""
    state_file = Path("/home/bitq/github/hermes-agent-learning/scripts/state.json")
    if state_file.exists():
        with open(state_file) as f:
            return json.load(f)
    return None

# 使用示例
state = read_learning_state()
if state:
    print(f"Current task: {state['current_task']}")
    print(f"Phase: {state['current_phase']}")
    print(f"Iteration: {state['iteration']}")
```

### 4.2 自动化状态更新

```python
import json
from datetime import datetime

def update_task_state(task_id, phase, iteration, status, outputs=None, notes=None):
    """更新任务状态"""
    state_file = "/home/bitq/github/hermes-agent-learning/scripts/state.json"
    
    with open(state_file, 'r') as f:
        state = json.load(f)
    
    task = state['tasks'][task_id - 1]
    task['phase'] = phase
    task['iteration'] = iteration
    task['status'] = status
    if outputs:
        task['outputs'] = outputs
    if notes:
        task['notes'] = notes
    
    state['current_task'] = task_id
    state['current_phase'] = phase
    state['iteration'] = iteration
    state['last_run'] = datetime.utcnow().strftime('%Y-%m-%dT%H:%M:%SZ')
    
    with open(state_file, 'w') as f:
        json.dump(state, f, indent=2, ensure_ascii=False)

# 使用示例
update_task_state(
    task_id=1,
    phase="execute",
    iteration=2,
    status="in_progress",
    outputs=["outputs/task1_exec.md"]
)
```

---

## 五、文件操作集成

### 5.1 写入执行结果

```python
from pathlib import Path

def write_exec_output(task_id, content):
    """写入任务执行结果"""
    output_dir = Path("/home/bitq/github/hermes-agent-learning/scripts/outputs")
    output_dir.mkdir(parents=True, exist_ok=True)
    
    output_file = output_dir / f"task{task_id}_exec.md"
    output_file.write_text(content, encoding='utf-8')
    return output_file

# 使用示例
content = """# Task Result

This is the output of the task.
"""
write_exec_output(1, content)
```

### 5.2 合并最终文档

```python
from pathlib import Path

def merge_final_docs():
    """将所有任务结果合并到最终文档"""
    output_dir = Path("/home/bitq/github/hermes-agent-learning/scripts/outputs")
    docs_dir = Path("/home/bitq/github/hermes-agent-learning/docs")
    docs_dir.mkdir(parents=True, exist_ok=True)
    
    final_file = docs_dir / "学习资料汇总.md"
    
    # 获取所有 exec 文件
    exec_files = sorted(output_dir.glob("task*_exec.md"))
    
    with open(final_file, 'w', encoding='utf-8') as out:
        out.write("# Hermes Agent 学习资料汇总\n\n")
        out.write("> 自动整理，持续更新\n\n")
        out.write("---\n\n")
        out.write("## 目录\n\n")
        for i, f in enumerate(exec_files, 1):
            out.write(f"{i}. [{f.stem}](./{f.name})\n")
        out.write("\n---\n\n")
        
        for f in exec_files:
            out.write(f"\n\n---\n\n")
            out.write(f.read_text(encoding='utf-8'))
    
    return final_file
```

---

## 六、Cron 调度集成

### 6.1 创建定时任务

```python
import subprocess
import json

def create_cron_job(schedule, prompt, skill=None, deliver=None):
    """创建 Hermes Cron 定时任务"""
    cmd = ["hermes", "cron", "create", schedule, "--prompt", prompt]
    
    if skill:
        cmd.extend(["--skill", skill])
    if deliver:
        cmd.extend(["--deliver", deliver])
    
    result = subprocess.run(cmd, capture_output=True, text=True)
    return result.stdout

# 使用示例
create_cron_job(
    schedule="0 9 * * *",  # 每天9点
    prompt="总结行业新闻",
    skill="news-summarizer",
    deliver="telegram:-1001234567890"
)
```

### 6.2 列出和管理任务

```python
import subprocess
import json

def list_cron_jobs():
    """列出所有 Cron 任务"""
    result = subprocess.run(
        ["hermes", "cron", "list", "--all"],
        capture_output=True,
        text=True
    )
    return result.stdout

def pause_cron_job(job_id):
    """暂停 Cron 任务"""
    subprocess.run(["hermes", "cron", "pause", job_id])

def resume_cron_job(job_id):
    """恢复 Cron 任务"""
    subprocess.run(["hermes", "cron", "resume", job_id])

def remove_cron_job(job_id):
    """删除 Cron 任务"""
    subprocess.run(["hermes", "cron", "remove", job_id])
```

---

## 七、MCP 服务器调用

### 7.1 启动 MCP 服务器

```python
import subprocess

def start_mcp_server():
    """启动 Hermes MCP 服务器"""
    proc = subprocess.Popen(
        ["hermes", "mcp", "serve"],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE
    )
    return proc

def add_mcp_server(name, url=None, command=None):
    """添加 MCP 服务器"""
    cmd = ["hermes", "mcp", "add", name]
    if url:
        cmd.extend(["--url", url])
    elif command:
        cmd.extend(["--command", command])
    
    subprocess.run(cmd)
```

---

## 八、完整示例：自动化学习资料整理

```python
#!/usr/bin/env python3
"""
Hermes 学习资料自动整理脚本
"""

import json
import subprocess
import time
from pathlib import Path
from datetime import datetime

PROJECT_DIR = Path("/home/bitq/github/hermes-agent-learning")
STATE_FILE = PROJECT_DIR / "scripts/state.json"
OUTPUTS_DIR = PROJECT_DIR / "scripts/outputs"

TASKS = [
    {
        "id": 1,
        "name": "官方文档整理",
        "prompt": "整理 Hermes Agent 的高频用法、核心概念，输出到 task1_exec.md",
    },
    {
        "id": 2,
        "name": "网络资源筛选",
        "prompt": "筛选优质学习资源，输出到 task2_exec.md",
    },
    {
        "id": 3,
        "name": "Python 脚本",
        "prompt": "整理 Python 使用 Hermes 的方法，输出到 task3_exec.md",
    },
]

def read_state():
    with open(STATE_FILE) as f:
        return json.load(f)

def write_state(state):
    with open(STATE_FILE, 'w') as f:
        json.dump(state, f, indent=2, ensure_ascii=False)

def run_hermes_task(task_id, prompt):
    """使用 tmux 运行 Hermes 任务"""
    session_name = f"learning_{task_id}"
    
    # 创建 tmux 会话
    subprocess.run([
        "tmux", "new-session", "-d", "-s", session_name,
        "-x", "120", "-y", "40", "hermes"
    ])
    time.sleep(8)
    
    # 发送任务
    subprocess.run([
        "tmux", "send-keys", "-t", session_name,
        prompt, "Enter"
    ])
    
    # 等待执行（根据任务复杂度调整）
    time.sleep(120)
    
    # 获取输出
    result = subprocess.run(
        ["tmux", "capture-pane", "-t", session_name, "-p"],
        capture_output=True,
        text=True
    )
    
    # 清理
    subprocess.run(["tmux", "kill-session", "-t", session_name])
    
    return result.stdout

def main():
    state = read_state()
    current_task = state['current_task']
    
    if current_task > len(TASKS):
        print("All tasks completed!")
        return
    
    task = TASKS[current_task - 1]
    print(f"Running task {task['id']}: {task['name']}")
    
    # 更新状态
    state['current_phase'] = 'execute'
    state['iteration'] = state.get('iteration', 0) + 1
    write_state(state)
    
    # 执行任务（这里只是示例，实际需要更复杂的 prompt）
    # output = run_hermes_task(task['id'], task['prompt'])
    
    # 假设任务完成，手动写入执行结果
    exec_file = OUTPUTS_DIR / f"task{task['id']}_exec.md"
    if exec_file.exists():
        state['current_phase'] = 'review'
        write_state(state)
        
        # 审核通过后进入下一任务
        if current_task < len(TASKS):
            state['current_task'] = current_task + 1
            state['current_phase'] = 'plan'
            state['iteration'] = 0
        else:
            state['completed'] = True
        write_state(state)
    
    print(f"Task {task['id']} completed. State updated.")

if __name__ == "__main__":
    main()
```

---

## 九、注意事项

### 9.1 最佳实践

- ✅ 使用 `subprocess.run()` 而非 `os.system()`
- ✅ 设置合理的 `timeout` 防止无限等待
- ✅ 使用 `text=True` 获取字符串输出
- ✅ 错误处理：`try/except` 包裹关键调用

### 9.2 常见问题

```python
# 问题：命令超时
# 解决：设置合理的 timeout
subprocess.run(["hermes", "chat", "-q", "..."], timeout=120)

# 问题：tmux 会话残留
# 解决：使用 try/finally 确保清理
try:
    subprocess.run(["tmux", "new-session", "-d", "-s", name, "hermes"])
    # ... 执行任务
finally:
    subprocess.run(["tmux", "kill-session", "-t", name])

# 问题：输出编码
# 解决：明确指定编码
with open(file, 'w', encoding='utf-8') as f:
    f.write(content)
```

---

## 十、相关资源

| 资源 | 链接 |
|------|------|
| [Hermes CLI 参考](https://hermes-agent.nousresearch.com/docs/reference/cli-commands) | https://hermes-agent.nousresearch.com/docs/reference/cli-commands |
| [Cron 文档](https://hermes-agent.nousresearch.com/docs/user-guide/features/cron) | https://hermes-agent.nousresearch.com/docs/user-guide/features/cron |
| [MCP 文档](https://hermes-agent.nousresearch.com/docs/user-guide/features/mcp) | https://hermes-agent.nousresearch.com/docs/user-guide/features/mcp |
| [tmux 手册](https://man.openbsd.org/tmux.1) | man tmux |
| [subprocess 文档](https://docs.python.org/3/library/subprocess.html) | Python 标准库 |