# PullerBox

一个用于训练记录、蓝牙测力设备连接、训练流程执行和历史分析的 iOS 应用。

## 当前阶段

当前目标是搭建核心架构，包括训练计划、训练执行、蓝牙设备连接、校准流程、数据持久化和基础历史记录。

## 目录说明

- `docs/`: 产品、架构、数据模型和开发约定
- `agent/skills`: 给 Codex / Claude Code 等 agent 使用的任务技能仓库

## 协作开发流程

```bash
# 1. 同步主分支
git checkout main
git pull origin main

# 2. 创建功能分支
git checkout -b feature/new-feat-a

# 3. 开发并提交
git add .
git commit -m "Add report export API"

# 4. 推送分支
git push origin feature/new-feat-a

# 5. 创建 Pull Request

# 6. 根据 review 修改代码
git add .
git commit -m "Handle empty export result"
git push origin feature/new-feat-a

# 7. PR 通过后合并到 main
```
