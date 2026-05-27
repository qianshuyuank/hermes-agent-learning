# Hermes Agent 学习记录

## 简介

本仓库用于记录 Hermes Agent 的学习心得、配置过程和使用技巧。

## 目录

- [快速开始](#快速开始)
- [配置指南](#配置指南)
- [使用技巧](#使用技巧)
- [常见问题](#常见问题)

## 快速开始

### 安装配置

1. 安装 Hermes Agent
2. 配置邮件系统
3. 连接 GitHub

### 基本命令

```bash
# 查看帮助
hermes --help

# 查看技能列表
hermes skills list
```

## 配置指南

### 邮件配置

使用 Himalaya CLI 管理邮件：

```bash
himalaya account configure <account>
himalaya envelope list
himalaya template send
```

### GitHub 连接

1. 生成 Personal Access Token
2. 配置 git credential helper
3. 验证连接

## 使用技巧

- 使用 skills 加载特定领域的知识
- 善用 delegate_task 进行并行任务处理
- 使用 cronjob 安排周期性任务

## 常见问题

待补充...

## 文档

- [Hermes Memory 系统指南](docs/hermes-memory-system-guide.md)
- [Hermes 人机协作指南 (Human-Agent Collaboration Guide)](docs/hermes-human-agent-collaboration-guide.md)

---

*学习日期：2026-05-24*