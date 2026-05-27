#!/usr/bin/env python3
"""
审核脚本 - 评估任务执行结果的质量
用法: python3 review_task.py <task_id>
"""

import json
import os
import sys
import re

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
STATE_FILE = os.path.join(SCRIPT_DIR, "state.json")
OUTPUTS_DIR = os.path.join(SCRIPT_DIR, "outputs")


def load_state():
    with open(STATE_FILE, 'r', encoding='utf-8') as f:
        return json.load(f)


def check_file_exists(path):
    return os.path.isfile(path)


def count_words(text):
    """统计中英文混合字数"""
    chinese = len(re.findall(r'[\u4e00-\u9fff]', text))
    english = len(re.findall(r'[a-zA-Z]', text))
    return chinese + english


def check_code_blocks(text):
    """检查代码块数量"""
    return len(re.findall(r'```[\w]*', text))


def check_links(text):
    """检查链接数量"""
    return len(re.findall(r'\[.+\]\(.+\)', text))


def review_task1(content):
    """审核任务1: 官方文档整理"""
    issues = []
    passed = True
    
    # 检查基本要素
    if '快速入门' not in content and '入门' not in content:
        issues.append("缺少入门指南")
        passed = False
    
    if '高频' not in content.lower() and '常用' not in content and '核心' not in content:
        issues.append("未突出高频/核心内容")
    
    # 检查字数（应有足够内容）
    words = count_words(content)
    if words < 500:
        issues.append(f"内容过少 ({words} 字)，可能不完整")
        passed = False
    
    # 检查代码示例
    code_blocks = check_code_blocks(content)
    if code_blocks < 3:
        issues.append(f"代码示例不足 ({code_blocks} 个代码块)")
        passed = False
    
    # 检查外部链接
    links = check_links(content)
    if links < 2:
        issues.append("外部参考链接不足")
    
    return passed, issues


def review_task2(content):
    """审核任务2: 网络资源筛选"""
    issues = []
    passed = True
    
    # 检查分类
    if '分类' not in content and '类别' not in content and '类型' not in content:
        issues.append("缺少资源分类")
        passed = False
    
    # 检查质量标注
    if 'star' not in content.lower() and 'github' not in content.lower():
        issues.append("缺少质量标注（如 GitHub stars）")
    
    # 检查字数
    words = count_words(content)
    if words < 300:
        issues.append(f"内容过少 ({words} 字)")
        passed = False
    
    # 检查链接
    links = check_links(content)
    if links < 5:
        issues.append(f"链接不足 ({links} 个)，资源数量可能不够")
        passed = False
    
    return passed, issues


def review_task3(content):
    """审核任务3: Python脚本"""
    issues = []
    passed = True
    
    # 检查代码示例
    code_blocks = check_code_blocks(content)
    if code_blocks < 2:
        issues.append(f"代码示例不足 ({code_blocks} 个代码块)")
        passed = False
    
    # 检查API说明
    if 'api' not in content.lower() and 'sdk' not in content.lower() and 'import' not in content:
        issues.append("缺少API/SDK相关说明")
        passed = False
    
    # 检查实际代码存在
    if 'import' not in content and 'from ' not in content:
        issues.append("未找到Python import语句")
        passed = False
    
    return passed, issues


def main():
    if len(sys.argv) < 2:
        print("用法: python3 review_task.py <task_id>")
        sys.exit(1)
    
    task_id = int(sys.argv[1])
    state = load_state()
    task = state['tasks'][task_id - 1]
    
    exec_file = os.path.join(OUTPUTS_DIR, f"task{task_id}_exec.md")
    
    if not check_file_exists(exec_file):
        print(f"错误: 执行结果文件不存在: {exec_file}")
        sys.exit(1)
    
    with open(exec_file, 'r', encoding='utf-8') as f:
        content = f.read()
    
    print(f"审核任务: {task['name']}")
    print(f"文件: {exec_file}")
    print("=" * 50)
    
    # 根据任务类型选择审核函数
    if task_id == 1:
        passed, issues = review_task1(content)
    elif task_id == 2:
        passed, issues = review_task2(content)
    elif task_id == 3:
        passed, issues = review_task3(content)
    else:
        print(f"未知任务ID: {task_id}")
        sys.exit(1)
    
    # 输出审核结果
    if passed:
        print("✓ 审核通过")
    else:
        print("✗ 审核不通过")
    
    if issues:
        print("\n发现的问题:")
        for i, issue in enumerate(issues, 1):
            print(f"  {i}. {issue}")
    
    # 保存审核结果
    review_file = os.path.join(OUTPUTS_DIR, f"task{task_id}_review.md")
    with open(review_file, 'w', encoding='utf-8') as f:
        f.write(f"# 任务{task_id}审核结果\n\n")
        f.write(f"任务: {task['name']}\n")
        f.write(f"结果: {'✓ 通过' if passed else '✗ 不通过'}\n")
        f.write(f"时间: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n\n")
        if issues:
            f.write("## 发现的问题\n\n")
            for i, issue in enumerate(issues, 1):
                f.write(f"{i}. {issue}\n")
    
    print(f"\n审核结果已保存: {review_file}")
    
    # 返回退出码
    sys.exit(0 if passed else 1)


if __name__ == "__main__":
    from datetime import datetime
    main()